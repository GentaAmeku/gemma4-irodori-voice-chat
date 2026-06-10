from __future__ import annotations

from pathlib import Path
from uuid import uuid4
import math
import wave

import httpx

from .config import AppConfig
from .models import AppSettings, ConversationTurn, DependencyStatus, SpeakerOption


class OllamaClient:
    def __init__(self, config: AppConfig, http_client: httpx.AsyncClient) -> None:
        self.config = config
        self.http = http_client

    async def health(self) -> DependencyStatus:
        if self.config.mock_services:
            return DependencyStatus(ok=True, detail="mock")
        try:
            response = await self.http.get(f"{self.config.ollama_base_url}/api/tags")
            response.raise_for_status()
        except Exception as exc:  # noqa: BLE001 - surfaced as dependency detail.
            return DependencyStatus(ok=False, detail=str(exc))
        return DependencyStatus(ok=True)

    async def chat(
        self,
        settings: AppSettings,
        history: list[ConversationTurn],
        user_text: str,
    ) -> str:
        if self.config.mock_services:
            return f"{settings.character_name}です。『{user_text}』について、まずは短く返すね。"

        messages = [{"role": "system", "content": settings.character_prompt}]
        for turn in history:
            messages.append({"role": "user", "content": turn.user_text})
            messages.append({"role": "assistant", "content": turn.assistant_text})
        messages.append({"role": "user", "content": user_text})

        response = await self.http.post(
            f"{self.config.ollama_base_url}/api/chat",
            json={
                "model": self.config.ollama_model,
                "messages": messages,
                "stream": False,
                "think": False,
            },
        )
        response.raise_for_status()
        data = response.json()
        content = data.get("message", {}).get("content", "")
        if not content.strip():
            raise RuntimeError("Ollama returned an empty assistant message")
        return content.strip()


class IrodoriTtsClient:
    def __init__(self, config: AppConfig, http_client: httpx.AsyncClient) -> None:
        self.config = config
        self.http = http_client
        self.config.audio_dir.mkdir(parents=True, exist_ok=True)

    async def health(self) -> DependencyStatus:
        if self.config.mock_services:
            return DependencyStatus(ok=True, detail="mock")
        try:
            response = await self.http.get(f"{self.config.tts_base_url}/health")
            response.raise_for_status()
        except Exception as exc:  # noqa: BLE001 - surfaced as dependency detail.
            return DependencyStatus(ok=False, detail=str(exc))
        return DependencyStatus(ok=True)

    async def speakers(self) -> list[SpeakerOption]:
        if self.config.mock_services:
            return [SpeakerOption(id="none", label="none"), SpeakerOption(id="rinon", label="rinon")]
        response = await self.http.get(f"{self.config.tts_base_url}/v1/audio/voices")
        response.raise_for_status()
        data = response.json()
        if isinstance(data, list):
            raw_items = data
        else:
            raw_items = data.get("voices") or data.get("data") or []
        options: list[SpeakerOption] = []
        for item in raw_items:
            if isinstance(item, str):
                options.append(SpeakerOption(id=item, label=item))
            elif isinstance(item, dict):
                voice_id = str(item.get("id") or item.get("voice_id") or item.get("name") or "")
                if voice_id:
                    options.append(SpeakerOption(id=voice_id, label=str(item.get("label") or voice_id)))
        return options or [SpeakerOption(id="none", label="none")]

    async def synthesize(self, text: str, settings: AppSettings) -> Path:
        suffix = f".{self.config.tts_response_format}"
        output = self.config.audio_dir / f"{uuid4().hex}{suffix}"
        if self.config.mock_services:
            self._write_mock_wav(output)
            return output

        response = await self.http.post(
            f"{self.config.tts_base_url}/v1/audio/speech",
            json={
                "model": self.config.tts_model,
                "input": text,
                "voice": {"id": settings.speaker_id},
                "response_format": self.config.tts_response_format,
                "speed": settings.speech_speed,
            },
        )
        response.raise_for_status()
        output.write_bytes(response.content)
        return output

    def _write_mock_wav(self, output: Path) -> None:
        sample_rate = 16_000
        duration_seconds = 0.45
        frame_count = int(sample_rate * duration_seconds)
        with wave.open(str(output), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(sample_rate)
            frames = bytearray()
            for index in range(frame_count):
                sample = int(4000 * math.sin(2 * math.pi * 440 * index / sample_rate))
                frames.extend(sample.to_bytes(2, "little", signed=True))
            wav.writeframes(bytes(frames))
