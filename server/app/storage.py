from __future__ import annotations

from pathlib import Path
import json

from .models import (
    AppSettings,
    ConversationTurn,
    DEFAULT_CHARACTER_PROMPT,
    LEGACY_CHARACTER_PROMPT,
    RENA_PRESET,
    RINON_CHARACTER_PROMPT,
)


CHARACTER_IMAGE_ASSETS_DIR = Path(__file__).parent / "assets"
OLD_READ_ALOUD_PROMPTS = {
    "Native Japanese young adult woman, warm conversational voice.",
    "Native Japanese young adult woman, warm conversational voice, clear pronunciation, gentle emotional nuance.",
    "Native Japanese mature young woman, cool composed voice, low-to-mid pitch, "
    "calm and slightly slow pacing, clear pronunciation, subtle warmth, "
    "elegant senpai tone, restrained emotion.",
}
OLD_DEFAULT_CHARACTER_NAMES = {"リノン"}
OLD_DEFAULT_CHARACTER_PROMPTS = {LEGACY_CHARACTER_PROMPT, RINON_CHARACTER_PROMPT}


class SettingsStore:
    def __init__(self, data_dir: Path) -> None:
        self.data_dir = data_dir
        self.settings_path = data_dir / "settings.json"

    def ensure_dirs(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)

    def load(self) -> AppSettings:
        self.ensure_dirs()
        if not self.settings_path.exists():
            settings = AppSettings()
            self.save(settings)
            return settings
        data = json.loads(self.settings_path.read_text(encoding="utf-8"))
        settings = AppSettings.model_validate(data)
        if self._migrate_default_character(settings):
            self.save(settings)
        return settings

    def save(self, settings: AppSettings) -> None:
        self.ensure_dirs()
        self.settings_path.write_text(
            settings.model_dump_json(indent=2),
            encoding="utf-8",
        )

    def find_character_image(self, preset_id: str) -> Path | None:
        # preset_id は AppSettings 側でパターン検証済みだが、パス結合の前に念のため弾く。
        if not preset_id.replace("-", "").replace("_", "").isalnum():
            return None
        image = CHARACTER_IMAGE_ASSETS_DIR / f"character-image-{preset_id}.png"
        if image.is_file():
            return image
        return None

    def _migrate_default_character(self, settings: AppSettings) -> bool:
        changed = False
        if settings.character_prompt in OLD_DEFAULT_CHARACTER_PROMPTS:
            settings.character_prompt = DEFAULT_CHARACTER_PROMPT
            changed = True
        if settings.character_name in OLD_DEFAULT_CHARACTER_NAMES:
            settings.character_name = AppSettings.model_fields["character_name"].default
            changed = True
        if settings.read_aloud_prompt in OLD_READ_ALOUD_PROMPTS:
            settings.read_aloud_prompt = AppSettings.model_fields[
                "read_aloud_prompt"
            ].default
            changed = True
        if (
            settings.tone_preset == "calm"
            and settings.distance == 40
            and settings.speech_speed == 1.0
        ):
            settings.tone_preset = AppSettings.model_fields["tone_preset"].default
            settings.distance = AppSettings.model_fields["distance"].default
            settings.speech_speed = AppSettings.model_fields["speech_speed"].default
            changed = True
        # 旧デフォルトの no-ref 話者のまま他がすべて怜奈プリセットと一致する場合は、
        # 参照音声 rena が登録された現行デフォルトへ引き上げる。
        if settings.speaker_id == "none" and (
            settings.character_name == RENA_PRESET.character_name
            and settings.character_prompt == RENA_PRESET.character_prompt
            and settings.read_aloud_prompt == RENA_PRESET.read_aloud_prompt
            and settings.tone_preset == RENA_PRESET.tone_preset
            and settings.distance == RENA_PRESET.distance
            and settings.speech_speed == RENA_PRESET.speech_speed
        ):
            settings.speaker_id = RENA_PRESET.speaker_id
            changed = True
        return changed


class ConversationHistory:
    def __init__(self) -> None:
        self._turns: list[ConversationTurn] = []

    def add(self, turn: ConversationTurn) -> None:
        self._turns.append(turn)

    def clear(self) -> None:
        self._turns.clear()

    def all(self) -> list[ConversationTurn]:
        return list(self._turns)

    def recent(self, limit: int) -> list[ConversationTurn]:
        return self._turns[-limit:]
