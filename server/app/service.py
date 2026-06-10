from __future__ import annotations

import asyncio
import logging

import httpx

from .adapters import IrodoriTtsClient, OllamaClient
from .models import AppSettings, ConversationTurn
from .storage import ConversationHistory, SettingsStore


logger = logging.getLogger("gic.conversation")


class ConversationBusyError(RuntimeError):
    pass


class TurnFailedError(RuntimeError):
    """会話ターンの失敗。code は失敗段階と原因の識別子。

    例: llm_timeout / llm_unavailable / llm_empty / tts_timeout / tts_unavailable
    """

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


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
            assistant_text = await self._chat(settings, user_text)
            audio_path = await self._synthesize(assistant_text, settings)
            turn = ConversationTurn(
                user_text=user_text,
                assistant_text=assistant_text,
                audio_url=f"/media/audio/{audio_path.name}",
            )
            self.history.add(turn)
            return turn

    async def _chat(self, settings: AppSettings, user_text: str) -> str:
        try:
            return await self.ollama.chat(settings, self.history.recent(10), user_text)
        # TimeoutException は HTTPError のサブクラスなので先に捕捉する。
        except httpx.TimeoutException as exc:
            logger.warning("LLM(Ollama) request timed out: %s", exc)
            raise TurnFailedError("llm_timeout") from exc
        except httpx.HTTPError as exc:
            logger.warning("LLM(Ollama) request failed: %s", exc)
            raise TurnFailedError("llm_unavailable") from exc
        except RuntimeError as exc:
            # OllamaClient は空応答時に RuntimeError を送出する。
            logger.warning("LLM(Ollama) returned no usable text: %s", exc)
            raise TurnFailedError("llm_empty") from exc

    async def _synthesize(self, assistant_text: str, settings: AppSettings):
        try:
            return await self.tts.synthesize(assistant_text, settings)
        except httpx.TimeoutException as exc:
            logger.warning("TTS(irodori) request timed out: %s", exc)
            raise TurnFailedError("tts_timeout") from exc
        except httpx.HTTPError as exc:
            logger.warning("TTS(irodori) request failed: %s", exc)
            raise TurnFailedError("tts_unavailable") from exc

    def save_settings(self, settings: AppSettings) -> AppSettings:
        self.settings_store.save(settings)
        self.history.clear()
        return settings
