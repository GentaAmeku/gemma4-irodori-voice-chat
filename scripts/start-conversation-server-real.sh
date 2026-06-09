#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLLAMA_HOST_VALUE="${OLLAMA_HOST:-127.0.0.1:11434}"
GIC_OLLAMA_MODEL="${GIC_OLLAMA_MODEL:-gemma4:12b}"
GIC_TTS_BASE_URL="${GIC_TTS_BASE_URL:-http://127.0.0.1:8088}"

cd "$ROOT_DIR/server"

GIC_OLLAMA_BASE_URL="http://$OLLAMA_HOST_VALUE" \
GIC_OLLAMA_MODEL="$GIC_OLLAMA_MODEL" \
GIC_TTS_BASE_URL="$GIC_TTS_BASE_URL" \
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
