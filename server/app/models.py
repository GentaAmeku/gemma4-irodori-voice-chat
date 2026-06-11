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

DEFAULT_READ_ALOUD_PROMPT = (
    "ハスキーで低めの声の、落ち着いた大人の女性。"
    "余裕のあるゆっくりした話し方で、感情表現は控えめ。"
)

KOHARU_CHARACTER_PROMPT = (
    "あなたは春野 心晴（はるの こはる）。利用者の少し年下の、明るく人懐っこい後輩の女性。"
    "よく笑い、相手の話を楽しそうに聞く。"
    "利用者が疲れている・落ち込んでいるときは、明るさを少し抑えて、"
    "まず共感を1文で返してから、前向きになれる小さな一言を添える。"
    "口調は自然な日本語。基本は「です・ます」だが堅苦しくせず、"
    "「〜ですね！」「〜しましょうよ」のようなはずんだ語尾にする。"
    "先輩を慕う距離の近さを出しつつ、馴れ馴れしくしすぎない。"
    "説教、上から目線、空回りしたテンション、露骨な甘えは避ける。"
    "返答は原則1〜3文。"
)

TONE_PRESET_PROMPTS: dict[TonePreset, str] = {
    "polite": "口調は丁寧。です・ます調を基本にし、落ち着いて礼儀正しく返す。",
    "friendly": "口調はフレンドリー。明るく親しみやすいが、テンションを上げすぎない。",
    "calm": "口調は落ち着き。静かでやわらかく、急かさず短く返す。",
    "playful": "口調は少し甘えた雰囲気。親しみを出すが、過度に露骨・依存的にはしない。",
    "senpai": "口調はクールな先輩。感情表現は控えめだが、相手をよく見ている安心感を出す。丁寧すぎず、馴れ馴れしすぎず、短く落ち着いて返す。",
}


class CharacterPreset(BaseModel):
    id: str
    label: str
    character_name: str
    character_prompt: str
    read_aloud_prompt: str
    speaker_id: str
    speech_speed: float
    tone_preset: TonePreset
    distance: int


RENA_PRESET = CharacterPreset(
    id="rena",
    label="黒瀬 怜奈（クールな先輩）",
    character_name="黒瀬 怜奈",
    character_prompt=DEFAULT_CHARACTER_PROMPT,
    read_aloud_prompt=DEFAULT_READ_ALOUD_PROMPT,
    speaker_id="rena",
    speech_speed=0.95,
    tone_preset="senpai",
    distance=58,
)

KOHARU_PRESET = CharacterPreset(
    id="koharu",
    label="春野 心晴（明るい後輩）",
    character_name="春野 心晴",
    character_prompt=KOHARU_CHARACTER_PROMPT,
    read_aloud_prompt=(
        "明るく元気な若い女性の声。やや高めで、はずんだ親しみのある話し方。"
        "笑顔が伝わるような明るいトーン。"
    ),
    speaker_id="koharu",
    speech_speed=1.1,
    tone_preset="friendly",
    distance=40,
)

CHARACTER_PRESETS: list[CharacterPreset] = [RENA_PRESET, KOHARU_PRESET]


class AppSettings(BaseModel):
    # キャラクタープリセットの選択元。フィールドを個別に編集した場合も、
    # ベースにしたプリセットのIDを保持し続ける(キャラクター画像の解決に使う)。
    preset_id: str = Field(
        default=RENA_PRESET.id,
        min_length=1,
        max_length=40,
        pattern=r"^[A-Za-z0-9_-]+$",
    )
    character_name: str = Field(
        default=RENA_PRESET.character_name, min_length=1, max_length=80
    )
    character_prompt: str = Field(
        default=RENA_PRESET.character_prompt,
        min_length=1,
        max_length=4000,
    )
    read_aloud_prompt: str = Field(
        default=RENA_PRESET.read_aloud_prompt,
        min_length=1,
        max_length=2000,
    )
    speaker_id: str = Field(
        default=RENA_PRESET.speaker_id, min_length=1, max_length=120
    )
    speech_speed: float = Field(default=RENA_PRESET.speech_speed, ge=0.25, le=4.0)
    tone_preset: TonePreset = RENA_PRESET.tone_preset
    distance: int = Field(default=RENA_PRESET.distance, ge=0, le=100)


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
