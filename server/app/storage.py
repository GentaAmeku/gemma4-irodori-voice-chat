from __future__ import annotations

from pathlib import Path
import json
import shutil

from .models import AppSettings, ConversationTurn


class SettingsStore:
    def __init__(self, data_dir: Path) -> None:
        self.data_dir = data_dir
        self.settings_path = data_dir / "settings.json"
        self.character_image_path = data_dir / "character-image"

    def ensure_dirs(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)

    def load(self) -> AppSettings:
        self.ensure_dirs()
        if not self.settings_path.exists():
            settings = AppSettings()
            self.save(settings)
            return settings
        data = json.loads(self.settings_path.read_text(encoding="utf-8"))
        return AppSettings.model_validate(data)

    def save(self, settings: AppSettings) -> None:
        self.ensure_dirs()
        self.settings_path.write_text(
            settings.model_dump_json(indent=2),
            encoding="utf-8",
        )

    def save_character_image(self, source: Path, suffix: str) -> Path:
        self.ensure_dirs()
        target = self.data_dir / f"character-image{suffix}"
        for old in self.data_dir.glob("character-image.*"):
            old.unlink(missing_ok=True)
        shutil.copyfile(source, target)
        return target

    def find_character_image(self) -> Path | None:
        self.ensure_dirs()
        for image in self.data_dir.glob("character-image.*"):
            if image.is_file():
                return image
        return None


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
