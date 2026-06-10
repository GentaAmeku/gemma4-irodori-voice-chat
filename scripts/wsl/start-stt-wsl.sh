#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STT_HOST="${GIC_STT_HOST:-127.0.0.1}"
STT_PORT="${GIC_STT_PORT:-8099}"
# CTranslate2 は ROCm 非対応のため AMD/WSL でも CPU 実行。compute は int8 が無難。
GIC_STT_DEVICE="${GIC_STT_DEVICE:-cpu}"
GIC_STT_COMPUTE_TYPE="${GIC_STT_COMPUTE_TYPE:-int8}"
GIC_STT_WHISPER_MODEL="${GIC_STT_WHISPER_MODEL:-kotoba-tech/kotoba-whisper-v2.0-faster}"

cd "$ROOT_DIR/stt-server"

echo "Starting STT server on http://$STT_HOST:$STT_PORT"
echo "Model: $GIC_STT_WHISPER_MODEL (device=$GIC_STT_DEVICE, compute=$GIC_STT_COMPUTE_TYPE)"

GIC_STT_DEVICE="$GIC_STT_DEVICE" \
GIC_STT_COMPUTE_TYPE="$GIC_STT_COMPUTE_TYPE" \
GIC_STT_WHISPER_MODEL="$GIC_STT_WHISPER_MODEL" \
uv run --extra whisper uvicorn app.main:app --host "$STT_HOST" --port "$STT_PORT"
