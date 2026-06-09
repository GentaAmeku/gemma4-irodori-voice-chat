from __future__ import annotations

from pathlib import Path

import httpx
import pytest

from app.adapters import IrodoriTtsClient, OllamaClient
from app.config import AppConfig
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
