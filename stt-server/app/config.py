from __future__ import annotations

from dataclasses import dataclass
import os


@dataclass(frozen=True)
class SttConfig:
    # 既定は日本語特化の kotoba-whisper(faster-whisper / CTranslate2 形式)。
    # 代替: "large-v3"(汎用・高精度だがCPUでは遅い) / "small"(軽量) など。
    model: str = "kotoba-tech/kotoba-whisper-v2.0-faster"
    # "auto" | "cpu" | "cuda"。Mac/AMD CPU環境では "cpu"。
    device: str = "auto"
    # "default" | "int8" | "int8_float16" | "float16" など。CPUは "int8" が無難。
    compute_type: str = "default"
    language: str = "ja"
    beam_size: int = 5
    # モデルを読み込まずに固定文字列を返す。依存(faster-whisper)なしで起動・テストできる。
    mock: bool = False


def _as_bool(raw: str | None) -> bool:
    return (raw or "").strip().lower() in {"1", "true", "yes", "on"}


def load_config() -> SttConfig:
    return SttConfig(
        model=os.getenv("GIC_STT_WHISPER_MODEL", "kotoba-tech/kotoba-whisper-v2.0-faster"),
        device=os.getenv("GIC_STT_DEVICE", "auto"),
        compute_type=os.getenv("GIC_STT_COMPUTE_TYPE", "default"),
        language=os.getenv("GIC_STT_LANGUAGE", "ja"),
        beam_size=int(os.getenv("GIC_STT_BEAM_SIZE", "5")),
        mock=_as_bool(os.getenv("GIC_STT_MOCK")),
    )
