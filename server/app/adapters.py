from __future__ import annotations

from pathlib import Path
from uuid import uuid4
import math
import wave

import httpx

from .config import AppConfig
from .models import (
    AppSettings,
    ConversationTurn,
    DependencyStatus,
    SpeakerOption,
    build_character_system_prompt,
)


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

        messages = [
            {"role": "system", "content": build_character_system_prompt(settings)}
        ]
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
            return [
                SpeakerOption(id="none", label="none"),
                SpeakerOption(id="rinon", label="rinon"),
            ]
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
                voice_id = str(
                    item.get("id") or item.get("voice_id") or item.get("name") or ""
                )
                if voice_id:
                    options.append(
                        SpeakerOption(
                            id=voice_id, label=str(item.get("label") or voice_id)
                        )
                    )
        return options or [SpeakerOption(id="none", label="none")]

    async def register_voice(
        self,
        voice_id: str,
        filename: str,
        content: bytes,
        content_type: str,
        replace: bool,
    ) -> list[SpeakerOption]:
        if self.config.mock_services:
            return [
                SpeakerOption(id="none", label="none"),
                SpeakerOption(id=voice_id, label=voice_id),
            ]

        files = {"file": (filename, content, content_type)}
        if replace:
            response = await self.http.put(
                f"{self.config.tts_base_url}/v1/audio/voices/{voice_id}", files=files
            )
        else:
            response = await self.http.post(
                f"{self.config.tts_base_url}/v1/audio/voices",
                data={"voice_id": voice_id},
                files=files,
            )
        response.raise_for_status()
        return await self.speakers()

    async def synthesize(self, text: str, settings: AppSettings) -> Path:
        suffix = f".{self.config.tts_response_format}"
        output = self.config.audio_dir / f"{uuid4().hex}{suffix}"
        if self.config.mock_services:
            self._write_mock_wav(output)
            return output

        payload = self._speech_payload(text, settings, voice_id=settings.speaker_id)
        response = await self._post_speech(payload)
        if (
            response.status_code == 400
            and settings.speaker_id != "none"
            and "Unknown voice" in response.text
        ):
            payload = self._speech_payload(text, settings, voice_id="none")
            response = await self._post_speech(payload)

        self._raise_for_status_with_body(response)
        output.write_bytes(response.content)
        return output

    def _speech_payload(
        self, text: str, settings: AppSettings, *, voice_id: str
    ) -> dict[str, object]:
        payload: dict[str, object] = {
            "model": self.config.tts_model,
            "input": text,
            "voice": {"id": voice_id},
            "response_format": self.config.tts_response_format,
            "speed": settings.speech_speed,
        }
        irodori_options: dict[str, object] = {}
        # 固定シードを渡すと、no_ref読み上げが長文でチャンク分割されても、
        # またターンをまたいでも、同じ声質で生成される。
        if self.config.tts_seed is not None:
            irodori_options["seed"] = self.config.tts_seed
        # VoiceDesign対応チェックポイントでは読み上げ設定が声質指示(caption)として効く。
        # caption非対応のチェックポイント(500M-v3など)では無視される。
        caption = settings.read_aloud_prompt.strip()
        if caption:
            irodori_options["caption"] = caption
        if irodori_options:
            payload["irodori"] = irodori_options
        return payload

    async def _post_speech(self, payload: dict[str, object]) -> httpx.Response:
        return await self.http.post(
            f"{self.config.tts_base_url}/v1/audio/speech", json=payload
        )

    @staticmethod
    def _raise_for_status_with_body(response: httpx.Response) -> None:
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            body = response.text[:2000]
            raise httpx.HTTPStatusError(
                f"{exc}; response body: {body!r}",
                request=exc.request,
                response=exc.response,
            ) from exc

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
