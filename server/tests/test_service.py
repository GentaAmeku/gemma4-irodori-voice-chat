from __future__ import annotations

import json
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.adapters import IrodoriTtsClient, OllamaClient
from app.config import AppConfig
from app.main import create_app
from app.models import (
    AppSettings,
    CHARACTER_PRESETS,
    ConversationTurn,
    DEFAULT_CHARACTER_PROMPT,
    KOHARU_PRESET,
    LEGACY_CHARACTER_PROMPT,
    RENA_PRESET,
    RINON_CHARACTER_PROMPT,
)
from app.service import ConversationBusyError, ConversationService, TurnFailedError
from app.storage import ConversationHistory, SettingsStore


def test_settings_save_load_and_history_clear(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)
    history = ConversationHistory()

    settings = AppSettings(
        character_name="テスト",
        character_prompt="短く返す",
        read_aloud_prompt="clear",
        speaker_id="none",
    )
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


def test_default_settings_use_reina_senpai_character() -> None:
    settings = AppSettings()

    assert settings.preset_id == "rena"
    assert settings.character_name == "黒瀬 怜奈"
    assert settings.character_prompt == DEFAULT_CHARACTER_PROMPT
    assert settings.read_aloud_prompt.startswith("ハスキーで低めの声の")
    assert settings.speaker_id == "rena"
    assert settings.speech_speed == 0.95
    assert settings.tone_preset == "senpai"
    assert settings.distance == 58


def test_character_presets_expose_rena_and_koharu() -> None:
    assert [preset.id for preset in CHARACTER_PRESETS] == ["rena", "koharu"]
    # プリセットIDは話者ID・画像ファイル名と揃える
    assert RENA_PRESET.speaker_id == "rena"
    assert KOHARU_PRESET.speaker_id == "koharu"
    assert KOHARU_PRESET.character_name == "春野 心晴"
    assert KOHARU_PRESET.tone_preset == "friendly"


def test_legacy_default_character_prompt_is_migrated(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)
    store.save(AppSettings(character_prompt=LEGACY_CHARACTER_PROMPT))

    settings = store.load()

    assert settings.character_prompt == DEFAULT_CHARACTER_PROMPT


def test_rinon_default_character_is_migrated(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)
    store.save(
        AppSettings(
            character_name="リノン",
            character_prompt=RINON_CHARACTER_PROMPT,
            read_aloud_prompt="Native Japanese young adult woman, warm conversational voice, clear pronunciation, gentle emotional nuance.",
            speech_speed=1.0,
            tone_preset="calm",
            distance=40,
        )
    )

    settings = store.load()

    assert settings.character_name == "黒瀬 怜奈"
    assert settings.character_prompt == DEFAULT_CHARACTER_PROMPT
    assert settings.read_aloud_prompt.startswith("ハスキーで低めの声の")
    assert settings.speech_speed == 0.95
    assert settings.tone_preset == "senpai"
    assert settings.distance == 58


def test_legacy_none_speaker_with_rena_defaults_is_migrated(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)
    store.save(AppSettings(speaker_id="none"))

    assert store.load().speaker_id == "rena"


def test_none_speaker_with_custom_settings_is_kept(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)
    store.save(AppSettings(speaker_id="none", character_name="カスタム"))

    assert store.load().speaker_id == "none"


def test_previous_english_read_aloud_default_is_migrated(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)
    store.save(
        AppSettings(
            read_aloud_prompt=(
                "Native Japanese mature young woman, cool composed voice, low-to-mid pitch, "
                "calm and slightly slow pacing, clear pronunciation, subtle warmth, "
                "elegant senpai tone, restrained emotion."
            ),
        )
    )

    settings = store.load()

    assert settings.read_aloud_prompt.startswith("ハスキーで低めの声の")


def test_character_image_resolves_per_preset(tmp_path: Path) -> None:
    store = SettingsStore(tmp_path)

    rena_image = store.find_character_image("rena")
    koharu_image = store.find_character_image("koharu")

    assert rena_image is not None and rena_image.name == "character-image-rena.png"
    assert (
        koharu_image is not None and koharu_image.name == "character-image-koharu.png"
    )
    assert store.find_character_image("unknown-preset") is None
    # パス区切りを含むIDではファイル探索しない
    assert store.find_character_image("../rena") is None


def test_presets_endpoint_returns_character_presets(tmp_path: Path) -> None:
    app = create_app(
        AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    )

    with TestClient(app) as client:
        response = client.get("/api/presets")

    assert response.status_code == 200
    presets = response.json()
    assert [preset["id"] for preset in presets] == ["rena", "koharu"]
    koharu = presets[1]
    assert koharu["character_name"] == "春野 心晴"
    assert koharu["speaker_id"] == "koharu"


def test_character_image_endpoint_follows_saved_preset(tmp_path: Path) -> None:
    app = create_app(
        AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    )

    with TestClient(app) as client:
        default_image = client.get("/api/character-image")
        saved = client.put(
            "/api/settings",
            json=KOHARU_PRESET.model_dump(exclude={"id", "label"})
            | {"preset_id": "koharu"},
        )
        koharu_image = client.get("/api/character-image")

    assert default_image.status_code == 200
    assert saved.status_code == 200
    assert saved.json()["preset_id"] == "koharu"
    assert koharu_image.status_code == 200
    assert koharu_image.content != default_image.content


def test_put_settings_rejects_path_like_preset_id(tmp_path: Path) -> None:
    app = create_app(
        AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    )

    with TestClient(app) as client:
        response = client.put(
            "/api/settings",
            json=AppSettings().model_dump() | {"preset_id": "../etc"},
        )

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_tts_request_includes_selected_speaker_and_speed(tmp_path: Path) -> None:
    captured_json: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal captured_json
        captured_json = json.loads(request.content.decode("utf-8"))
        return httpx.Response(200, content=b"RIFF")

    config = AppConfig(
        mock_services=False, data_dir=tmp_path, audio_dir=tmp_path / "audio"
    )
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
    # 固定シードでチャンク・ターンをまたいで声質を一貫させる。
    # 読み上げ設定はVoiceDesign向けのcaptionとして送る。
    assert captured_json["irodori"] == {"seed": 1234567, "caption": "clear"}


@pytest.mark.asyncio
async def test_tts_request_omits_seed_when_disabled(tmp_path: Path) -> None:
    captured_json: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal captured_json
        captured_json = json.loads(request.content.decode("utf-8"))
        return httpx.Response(200, content=b"RIFF")

    config = AppConfig(
        mock_services=False,
        data_dir=tmp_path,
        audio_dir=tmp_path / "audio",
        tts_seed=None,
    )
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as http_client:
        client = IrodoriTtsClient(config, http_client)
        settings = AppSettings(speaker_id="none")
        await client.synthesize("こんにちは。", settings)

    assert "seed" not in captured_json["irodori"]
    assert captured_json["irodori"]["caption"] == AppSettings().read_aloud_prompt


@pytest.mark.asyncio
async def test_tts_request_omits_irodori_when_seed_disabled_and_caption_blank(
    tmp_path: Path,
) -> None:
    captured_json: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal captured_json
        captured_json = json.loads(request.content.decode("utf-8"))
        return httpx.Response(200, content=b"RIFF")

    config = AppConfig(
        mock_services=False,
        data_dir=tmp_path,
        audio_dir=tmp_path / "audio",
        tts_seed=None,
    )
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as http_client:
        client = IrodoriTtsClient(config, http_client)
        settings = AppSettings(speaker_id="none", read_aloud_prompt=" ")
        await client.synthesize("こんにちは。", settings)

    assert "irodori" not in captured_json


@pytest.mark.asyncio
async def test_tts_unknown_voice_falls_back_to_none(tmp_path: Path) -> None:
    captured_voices: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content.decode("utf-8"))
        voice_id = payload["voice"]["id"]
        captured_voices.append(voice_id)
        if voice_id == "rena":
            return httpx.Response(
                400,
                json={
                    "error": {"message": "\"Unknown voice='rena'. Use voice='none'.\""}
                },
            )
        return httpx.Response(200, content=b"RIFF")

    config = AppConfig(
        mock_services=False, data_dir=tmp_path, audio_dir=tmp_path / "audio"
    )
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as http_client:
        client = IrodoriTtsClient(config, http_client)
        output = await client.synthesize("こんにちは。", AppSettings(speaker_id="rena"))

    assert output.read_bytes() == b"RIFF"
    assert captured_voices == ["rena", "none"]


@pytest.mark.asyncio
async def test_ollama_request_includes_tone_and_distance_prompt(tmp_path: Path) -> None:
    captured_json: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal captured_json
        captured_json = json.loads(request.content.decode("utf-8"))
        return httpx.Response(200, json={"message": {"content": "返答です。"}})

    config = AppConfig(
        mock_services=False, data_dir=tmp_path, audio_dir=tmp_path / "audio"
    )
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as http_client:
        response = await OllamaClient(config, http_client).chat(
            AppSettings(
                character_name="テスト",
                character_prompt="短く返す。",
                read_aloud_prompt="clear",
                speaker_id="none",
                tone_preset="friendly",
                distance=80,
            ),
            [],
            "こんにちは",
        )

    assert response == "返答です。"
    messages = captured_json["messages"]
    assert isinstance(messages, list)
    system_prompt = messages[0]["content"]
    assert "短く返す。" in system_prompt
    assert "追加の口調設定" in system_prompt
    assert "フレンドリー" in system_prompt
    assert "親しい寄り" in system_prompt


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

    config = AppConfig(
        mock_services=False, data_dir=tmp_path, audio_dir=tmp_path / "audio"
    )
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

    config = AppConfig(
        mock_services=False, data_dir=tmp_path, audio_dir=tmp_path / "audio"
    )
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
    app = create_app(
        AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    )

    with TestClient(app) as client:
        response = client.post(
            "/api/speakers/rinon",
            files={"file": ("rinon.wav", b"RIFF", "audio/wav")},
        )

    assert response.status_code == 200
    assert response.json() == [
        {"id": "none", "label": "none"},
        {"id": "rinon", "label": "rinon"},
    ]


def test_register_speaker_endpoint_rejects_invalid_input(tmp_path: Path) -> None:
    app = create_app(
        AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    )

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
    config = AppConfig(
        mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio"
    )
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
async def test_turn_maps_llm_timeout(tmp_path: Path) -> None:
    class TimeoutOllama:
        async def chat(self, settings, history, user_text):  # noqa: ANN001
            raise httpx.ReadTimeout("llm timed out")

    class UnusedTts:
        async def synthesize(self, text, settings):  # noqa: ANN001
            raise AssertionError("TTS should not be called after an LLM failure")

    service = ConversationService(
        SettingsStore(tmp_path),
        ConversationHistory(),
        TimeoutOllama(),  # type: ignore[arg-type]
        UnusedTts(),  # type: ignore[arg-type]
    )

    with pytest.raises(TurnFailedError) as exc_info:
        await service.text_turn("こんにちは")
    assert exc_info.value.code == "llm_timeout"


@pytest.mark.asyncio
async def test_turn_maps_tts_unavailable(tmp_path: Path) -> None:
    class OkOllama:
        async def chat(self, settings, history, user_text):  # noqa: ANN001
            return "返答です。"

    class UnreachableTts:
        async def synthesize(self, text, settings):  # noqa: ANN001
            raise httpx.ConnectError("connection refused")

    service = ConversationService(
        SettingsStore(tmp_path),
        ConversationHistory(),
        OkOllama(),  # type: ignore[arg-type]
        UnreachableTts(),  # type: ignore[arg-type]
    )

    with pytest.raises(TurnFailedError) as exc_info:
        await service.text_turn("こんにちは")
    assert exc_info.value.code == "tts_unavailable"
    # 失敗したターンは履歴に残さない
    assert service.history.all() == []


def test_text_turn_endpoint_maps_turn_failure(tmp_path: Path) -> None:
    app = create_app(
        AppConfig(mock_services=True, data_dir=tmp_path, audio_dir=tmp_path / "audio")
    )

    class FailingService:
        async def text_turn(self, text: str):
            raise TurnFailedError("tts_timeout")

    with TestClient(app) as client:
        app.state.conversation_service = FailingService()
        response = client.post("/api/turns/text", json={"text": "こんにちは"})

    assert response.status_code == 504
    assert response.json()["detail"] == "tts_timeout"


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

    # ollama の Runtime(空応答相当)は TurnFailedError("llm_empty") にラップされる
    with pytest.raises(TurnFailedError) as exc_info:
        await service.text_turn("first")
    assert exc_info.value.code == "llm_empty"

    turn = await service.text_turn("second")

    assert turn.assistant_text == "復旧後の返答です。"
