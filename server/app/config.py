from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import os


ROOT_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT_DIR / "data"
AUDIO_DIR = DATA_DIR / "audio"


@dataclass(frozen=True)
class AppConfig:
    ollama_base_url: str = "http://127.0.0.1:11434"
    ollama_model: str = "gemma4:e4b-mlx"
    tts_base_url: str = "http://127.0.0.1:8088"
    tts_model: str = "irodori-tts"
    tts_response_format: str = "wav"
    request_timeout_seconds: float = 90.0
    mock_services: bool = False
    data_dir: Path = DATA_DIR
    audio_dir: Path = AUDIO_DIR


def load_config() -> AppConfig:
    data_dir = Path(os.getenv("GIC_DATA_DIR", str(DATA_DIR))).expanduser()
    audio_dir = Path(os.getenv("GIC_AUDIO_DIR", str(data_dir / "audio"))).expanduser()
    return AppConfig(
        ollama_base_url=os.getenv("GIC_OLLAMA_BASE_URL", "http://127.0.0.1:11434").rstrip("/"),
        ollama_model=os.getenv("GIC_OLLAMA_MODEL", "gemma4:e4b-mlx"),
        tts_base_url=os.getenv("GIC_TTS_BASE_URL", "http://127.0.0.1:8088").rstrip("/"),
        tts_model=os.getenv("GIC_TTS_MODEL", "irodori-tts"),
        tts_response_format=os.getenv("GIC_TTS_RESPONSE_FORMAT", "wav"),
        request_timeout_seconds=float(os.getenv("GIC_REQUEST_TIMEOUT_SECONDS", "90")),
        mock_services=os.getenv("GIC_MOCK_SERVICES", "0") in {"1", "true", "TRUE", "yes", "YES"},
        data_dir=data_dir,
        audio_dir=audio_dir,
    )
