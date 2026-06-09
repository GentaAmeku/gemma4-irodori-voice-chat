from __future__ import annotations

import asyncio

from .adapters import IrodoriTtsClient, OllamaClient
from .models import AppSettings, ConversationTurn
from .storage import ConversationHistory, SettingsStore


class ConversationBusyError(RuntimeError):
    pass


class ConversationService:
    def __init__(
        self,
        settings_store: SettingsStore,
        history: ConversationHistory,
        ollama: OllamaClient,
        tts: IrodoriTtsClient,
    ) -> None:
        self.settings_store = settings_store
        self.history = history
        self.ollama = ollama
        self.tts = tts
        self._lock = asyncio.Lock()

    async def text_turn(self, user_text: str) -> ConversationTurn:
        if self._lock.locked():
            raise ConversationBusyError("conversation_busy")

        async with self._lock:
            settings = self.settings_store.load()
            assistant_text = await self.ollama.chat(settings, self.history.recent(10), user_text)
            audio_path = await self.tts.synthesize(assistant_text, settings)
            turn = ConversationTurn(
                user_text=user_text,
                assistant_text=assistant_text,
                audio_url=f"/media/audio/{audio_path.name}",
            )
            self.history.add(turn)
            return turn

    def save_settings(self, settings: AppSettings) -> AppSettings:
        self.settings_store.save(settings)
        self.history.clear()
        return settings
