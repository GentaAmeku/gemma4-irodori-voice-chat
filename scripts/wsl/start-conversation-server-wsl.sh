#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GIC_OLLAMA_MODEL="${GIC_OLLAMA_MODEL:-gemma4:12b}"
GIC_TTS_BASE_URL="${GIC_TTS_BASE_URL:-http://127.0.0.1:8088}"
GIC_STT_BASE_URL="${GIC_STT_BASE_URL:-http://127.0.0.1:8099}"

resolve_ollama_host() {
  if [ -n "${OLLAMA_HOST:-}" ]; then
    echo "$OLLAMA_HOST"
    return
  fi

  if curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "127.0.0.1:11434"
    return
  fi

  local windows_host
  windows_host="$(ip route show default | awk '{print $3; exit}')"
  if [ -z "$windows_host" ]; then
    echo "Could not resolve Windows host IP. Set OLLAMA_HOST manually, for example OLLAMA_HOST=127.0.0.1:11434." >&2
    exit 1
  fi
  echo "${windows_host}:11434"
}

OLLAMA_HOST_VALUE="$(resolve_ollama_host)"

cd "$ROOT_DIR/server"

echo "Using Ollama: http://$OLLAMA_HOST_VALUE"
echo "Using STT: $GIC_STT_BASE_URL"

GIC_OLLAMA_BASE_URL="http://$OLLAMA_HOST_VALUE" \
GIC_OLLAMA_MODEL="$GIC_OLLAMA_MODEL" \
GIC_TTS_BASE_URL="$GIC_TTS_BASE_URL" \
GIC_STT_BASE_URL="$GIC_STT_BASE_URL" \
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
