from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import os


ROOT_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT_DIR / "data"
AUDIO_DIR = DATA_DIR / "audio"


# no_ref(参照音声なし)読み上げの話者は、生成時の初期ノイズ=シードで決まる。
# シード未指定だとIrodori-TTS側がチャンクごと・ターンごとに乱数シードを引き、
# 同じ返答内でも声が別人に変わる。固定シードを渡すと声が一貫する。
DEFAULT_TTS_SEED = 1234567


@dataclass(frozen=True)
class AppConfig:
    ollama_base_url: str = "http://127.0.0.1:11434"
    ollama_model: str = "gemma4:12b"
    tts_base_url: str = "http://127.0.0.1:8088"
    tts_model: str = "irodori-tts"
    tts_response_format: str = "wav"
    # no_ref音声の声質を固定するシード。None で都度ランダム(従来の挙動)。
    tts_seed: int | None = DEFAULT_TTS_SEED
    request_timeout_seconds: float = 90.0
    mock_services: bool = False
    data_dir: Path = DATA_DIR
    audio_dir: Path = AUDIO_DIR


def _parse_optional_int(raw: str | None, *, default: int | None) -> int | None:
    if raw is None:
        return default
    value = raw.strip()
    if value == "" or value.lower() in {"none", "random"}:
        return None
    try:
        return int(value)
    except ValueError:
        return default


def load_config() -> AppConfig:
    data_dir = Path(os.getenv("GIC_DATA_DIR", str(DATA_DIR))).expanduser()
    audio_dir = Path(os.getenv("GIC_AUDIO_DIR", str(data_dir / "audio"))).expanduser()
    return AppConfig(
        ollama_base_url=os.getenv(
            "GIC_OLLAMA_BASE_URL", "http://127.0.0.1:11434"
        ).rstrip("/"),
        ollama_model=os.getenv("GIC_OLLAMA_MODEL", "gemma4:12b"),
        tts_base_url=os.getenv("GIC_TTS_BASE_URL", "http://127.0.0.1:8088").rstrip("/"),
        tts_model=os.getenv("GIC_TTS_MODEL", "irodori-tts"),
        tts_response_format=os.getenv("GIC_TTS_RESPONSE_FORMAT", "wav"),
        tts_seed=_parse_optional_int(
            os.getenv("GIC_TTS_SEED"), default=DEFAULT_TTS_SEED
        ),
        request_timeout_seconds=float(os.getenv("GIC_REQUEST_TIMEOUT_SECONDS", "90")),
        mock_services=os.getenv("GIC_MOCK_SERVICES", "0")
        in {"1", "true", "TRUE", "yes", "YES"},
        data_dir=data_dir,
        audio_dir=audio_dir,
    )
