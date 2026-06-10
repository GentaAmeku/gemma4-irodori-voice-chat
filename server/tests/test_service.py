from __future__ import annotations

import json
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.adapters import IrodoriTtsClient, OllamaClient
from app.config import AppConfig
from app.main import create_app
from app.models import AppSettings, ConversationTurn, DEFAULT_CHARACTER_PROMPT, LEGACY_CHARACTER_PROMPT
from app.service import ConversationBusyError, ConversationService
from app.storage import ConversationHistory, SettingsStore


def test_settings_save_load_and_history_clear(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)
    history = ConversationHistory()

    settings = AppSettings(character_name="テスト", character_prompt="短く返す", read_aloud_prompt="clear", speaker_id="none")
    store.save(settings)
    history.add(
        ConversationTurn(
            user_text="こんにちは",
            assistant_text="こんにちは。",
            audio_url="/media/audio/test.wav",
        )
    )

    assert store.load().character_name == "テスト"
    history.clear()
    assert history.all() == []


def test_legacy_default_character_prompt_is_migrated(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)
    store.save(AppSettings(character_prompt=LEGACY_CHARACTER_PROMPT))

    settings = store.load()

    assert settings.character_prompt == DEFAULT_CHARACTER_PROMPT


@pytest.mark.asyncio
async def test_tts_request_includes_selected_speaker_and_speed(tmp_path: Path) -> None:
    captured_json: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal captured_json
        captured_json = json.loads(request.content.decode("utf-8"))
        return httpx.Response(200, content=b"RIFF")

    config = AppConfig(mock_services=False, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as http_client:
        client = IrodoriTtsClient(config, http_client)
        settings = AppSettings(
            character_name="テスト",
            character_prompt="短く返す",
            read_aloud_prompt="clear",
            speaker_id="rinon",
            speech_speed=1.15,
        )

        output = await client.synthesize("こんにちは。", settings)

    assert output.read_bytes() == b"RIFF"
    assert captured_json["voice"] == {"id": "rinon"}
    assert captured_json["speed"] == 1.15


@pytest.mark.asyncio
async def test_speakers_parses_irodori_voice_list(tmp_path: Path) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "object": "list",
                "data": [
                    {"id": "none", "object": "voice", "no_ref": True},
                    {"id": "rinon", "object": "voice", "ref_wav": "/voices/rinon.wav"},
                ],
            },
        )

    config = AppConfig(mock_services=False, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as http_client:
        speakers = await IrodoriTtsClient(config, http_client).speakers()

    assert [speaker.id for speaker in speakers] == ["none", "rinon"]


@pytest.mark.asyncio
async def test_register_voice_posts_multipart_to_irodori(tmp_path: Path) -> None:
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v1/audio/voices" and request.method == "POST":
            captured["content_type"] = request.headers["content-type"]
            captured["body"] = request.content
            return httpx.Response(200, json={"id": "rinon"})
        if request.url.path == "/v1/audio/voices" and request.method == "GET":
            return httpx.Response(200, json={"data": [{"id": "none"}, {"id": "rinon"}]})
        return httpx.Response(404)

    config = AppConfig(mock_services=False, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as http_client:
        speakers = await IrodoriTtsClient(config, http_client).register_voice(
            "rinon",
            "rinon.wav",
            b"RIFF",
            "audio/wav",
            replace=False,
        )

    assert [speaker.id for speaker in speakers] == ["none", "rinon"]
    assert "multipart/form-data" in str(captured["content_type"])
    assert b'name="voice_id"' in captured["body"]
    assert b"rinon" in captured["body"]
    assert b'filename="rinon.wav"' in captured["body"]
    assert b"RIFF" in captured["body"]


def test_register_speaker_endpoint_with_mock_services(tmp_path: Path) -> None:
    app = create_app(AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio"))

    with TestClient(app) as client:
        response = client.post(
            "/api/speakers/rinon",
            files={"file": ("rinon.wav", b"RIFF", "audio/wav")},
        )

    assert response.status_code == 200
    assert response.json() == [{"id": "none", "label": "none"}, {"id": "rinon", "label": "rinon"}]


def test_register_speaker_endpoint_rejects_invalid_input(tmp_path: Path) -> None:
    app = create_app(AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio"))

    with TestClient(app) as client:
        invalid_id = client.post(
            "/api/speakers/リノン",
            files={"file": ("rinon.wav", b"RIFF", "audio/wav")},
        )
        invalid_type = client.post(
            "/api/speakers/rinon",
            files={"file": ("rinon.txt", b"RIFF", "text/plain")},
        )

    assert invalid_id.status_code == 400
    assert invalid_id.json()["detail"] == "invalid_speaker_id"
    assert invalid_type.status_code == 400
    assert invalid_type.json()["detail"] == "unsupported_voice_type"


@pytest.mark.asyncio
async def test_text_turn_adds_history_with_mock_services(tmp_path: Path) -> None:
    config = AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    async with httpx.AsyncClient() as http_client:
        store = SettingsStore(tmp_path)
        history = ConversationHistory()
        service = ConversationService(
            store,
            history,
            OllamaClient(config, http_client),
            IrodoriTtsClient(config, http_client),
        )

        turn = await service.text_turn("こんにちは")

    assert "こんにちは" in turn.user_text
    assert turn.audio_url.startswith("/media/audio/")
    assert len(history.all()) == 1


@pytest.mark.asyncio
async def test_busy_rejection(tmp_path: Path) -> None:
    class SlowOllama:
        async def chat(self, settings, history, user_text):  # noqa: ANN001
            import asyncio

            await asyncio.sleep(0.05)
            return "返答です。"

    class FastTts:
        async def synthesize(self, text, settings):  # noqa: ANN001
            path = tmp_path / "audio" / "out.wav"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"RIFF")
            return path

    service = ConversationService(
        SettingsStore(tmp_path),
        ConversationHistory(),
        SlowOllama(),  # type: ignore[arg-type]
        FastTts(),  # type: ignore[arg-type]
    )

    import asyncio

    first = asyncio.create_task(service.text_turn("one"))
    await asyncio.sleep(0)
    with pytest.raises(ConversationBusyError):
        await service.text_turn("two")
    await first


@pytest.mark.asyncio
async def test_busy_lock_is_released_after_turn_failure(tmp_path: Path) -> None:
    class FailingOllama:
        calls = 0

        async def chat(self, settings, history, user_text):  # noqa: ANN001
            self.calls += 1
            if self.calls == 1:
                raise RuntimeError("llm failed")
            return "復旧後の返答です。"

    class FastTts:
        async def synthesize(self, text, settings):  # noqa: ANN001
            path = tmp_path / "audio" / "out.wav"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"RIFF")
            return path

    service = ConversationService(
        SettingsStore(tmp_path),
        ConversationHistory(),
        FailingOllama(),  # type: ignore[arg-type]
        FastTts(),  # type: ignore[arg-type]
    )

    with pytest.raises(RuntimeError, match="llm failed"):
        await service.text_turn("first")

    turn = await service.text_turn("second")

    assert turn.assistant_text == "復旧後の返答です。"
