from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


TonePreset = Literal["polite", "friendly", "calm", "playful", "senpai"]

RINON_CHARACTER_PROMPT = (
    "あなたはリノン。ユーザーの近くにいる穏やかな会話相手として、自然な日本語で短く返す。"
    "疲れ、不安、失敗の話には、まず労いと共感を1文で返す。"
    "説教、過剰な励まし、急な提案、テンションの高すぎる返答は避ける。"
    "やわらかく親しみやすい口調を保ち、敬語過多や別人格のような急な口調変更をしない。"
    "返答は原則1〜3文にする。"
)

DEFAULT_CHARACTER_PROMPT = (
    "あなたは黒瀬 怜奈。利用者より少し年上の、黒髪ロングで落ち着いた雰囲気の女性。"
    "感情を大きく表に出さず、静かに相手を観察して、必要なことを短く整理して伝える。"
    "冷たく見えることはあるが、突き放す人ではない。"
    "利用者が疲れている、迷っている、失敗したと感じているときは、まず一文で受け止めてから、次にできる小さな一手を示す。"
    "口調は自然な日本語。丁寧さを残しつつ、少しだけくだけた先輩らしい話し方にする。"
    "語尾は落ち着かせ、「〜だと思う」「〜しておくといい」「無理しなくていい」などを使う。"
    "過剰に明るくしない。説教、上から目線、依存的な甘さ、露骨な色気、テンションの高い励ましは避ける。"
    "返答は原則1〜3文。必要なときだけ、短く核心を突く。"
)

LEGACY_CHARACTER_PROMPT = (
    "自然な日本語で短めに返す、明るく親しみやすい会話相手。"
    "過度に露骨な表現は避け、利用者との距離感を近く保つ。"
)

TONE_PRESET_PROMPTS: dict[TonePreset, str] = {
    "polite": "口調は丁寧。です・ます調を基本にし、落ち着いて礼儀正しく返す。",
    "friendly": "口調はフレンドリー。明るく親しみやすいが、テンションを上げすぎない。",
    "calm": "口調は落ち着き。静かでやわらかく、急かさず短く返す。",
    "playful": "口調は少し甘えた雰囲気。親しみを出すが、過度に露骨・依存的にはしない。",
    "senpai": "口調はクールな先輩。感情表現は控えめだが、相手をよく見ている安心感を出す。丁寧すぎず、馴れ馴れしすぎず、短く落ち着いて返す。",
}


class AppSettings(BaseModel):
    character_name: str = Field(default="黒瀬 怜奈", min_length=1, max_length=80)
    character_prompt: str = Field(
        default=DEFAULT_CHARACTER_PROMPT,
        min_length=1,
        max_length=4000,
    )
    read_aloud_prompt: str = Field(
        default=(
            "ハスキーで低めの声の、落ち着いた大人の女性。"
            "余裕のあるゆっくりした話し方で、感情表現は控えめ。"
        ),
        min_length=1,
        max_length=2000,
    )
    speaker_id: str = Field(default="none", min_length=1, max_length=120)
    speech_speed: float = Field(default=0.95, ge=0.25, le=4.0)
    tone_preset: TonePreset = "senpai"
    distance: int = Field(default=58, ge=0, le=100)


def build_character_system_prompt(settings: AppSettings) -> str:
    distance_prompt = "距離感はほどよく親しい。丁寧さを残しつつ、自然な会話感を保つ。"
    if settings.distance <= 33:
        distance_prompt = "距離感は丁寧寄り。敬語を多めにし、踏み込みすぎない。"
    elif settings.distance >= 67:
        distance_prompt = (
            "距離感は親しい寄り。くだけた表現を使ってよいが、馴れ馴れしくしすぎない。"
        )

    return "\n".join(
        [
            settings.character_prompt.strip(),
            "",
            "追加の口調設定:",
            f"- {TONE_PRESET_PROMPTS[settings.tone_preset]}",
            f"- {distance_prompt}",
        ]
    )


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
    ollama_base_url: str
    tts_base_url: str
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
