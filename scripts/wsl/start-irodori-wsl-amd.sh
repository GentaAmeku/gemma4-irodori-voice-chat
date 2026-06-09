#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IRODORI_TTS_SERVER_DIR="${IRODORI_TTS_SERVER_DIR:-"$ROOT_DIR/../Irodori-TTS-Server"}"
IRODORI_HOST="${IRODORI_HOST:-0.0.0.0}"
IRODORI_PORT="${IRODORI_PORT:-8088}"

cd "$IRODORI_TTS_SERVER_DIR"
uv run --extra rocm python -m irodori_openai_tts --host "$IRODORI_HOST" --port "$IRODORI_PORT"
