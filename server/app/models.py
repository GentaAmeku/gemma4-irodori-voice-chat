from __future__ import annotations

from pydantic import BaseModel, Field


class AppSettings(BaseModel):
    character_name: str = Field(default="リノン", min_length=1, max_length=80)
    character_prompt: str = Field(
        default=(
            "自然な日本語で短めに返す、明るく親しみやすい会話相手。"
            "過度に露骨な表現は避け、利用者との距離感を近く保つ。"
        ),
        min_length=1,
        max_length=4000,
    )
    read_aloud_prompt: str = Field(
        default=(
            "Native Japanese young adult woman, warm conversational voice, "
            "clear pronunciation, gentle emotional nuance."
        ),
        min_length=1,
        max_length=2000,
    )
    speaker_id: str = Field(default="none", min_length=1, max_length=120)


class SpeakerOption(BaseModel):
    id: str
    label: str


class DependencyStatus(BaseModel):
    ok: bool
    detail: str | None = None


class HealthResponse(BaseModel):
    server_ok: bool
    ready: bool
    model: str
    mock_services: bool
    ollama: DependencyStatus
    tts: DependencyStatus


class TextTurnRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)


class ConversationTurn(BaseModel):
    user_text: str
    assistant_text: str
    audio_url: str


class BusyResponse(BaseModel):
    detail: str = "conversation_busy"


class HistoryResponse(BaseModel):
    turns: list[ConversationTurn]
