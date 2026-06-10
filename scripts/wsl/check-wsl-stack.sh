#!/usr/bin/env bash
set -euo pipefail

resolve_ollama_base_url() {
  if [ -n "${GIC_OLLAMA_BASE_URL:-}" ]; then
    echo "$GIC_OLLAMA_BASE_URL"
    return
  fi

  if curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "http://127.0.0.1:11434"
    return
  fi

  local windows_host
  windows_host="$(ip route show default | awk '{print $3; exit}')"
  if [ -z "$windows_host" ]; then
    echo "Could not resolve Windows host IP. Set GIC_OLLAMA_BASE_URL manually." >&2
    exit 1
  fi
  echo "http://${windows_host}:11434"
}

OLLAMA_BASE_URL="$(resolve_ollama_base_url)"
TTS_BASE_URL="${GIC_TTS_BASE_URL:-http://127.0.0.1:8088}"
STT_BASE_URL="${GIC_STT_BASE_URL:-http://127.0.0.1:8099}"
APP_BASE_URL="${GIC_APP_BASE_URL:-http://127.0.0.1:8000}"

echo "Checking Ollama..."
echo "$OLLAMA_BASE_URL"
curl -fsS "$OLLAMA_BASE_URL/api/tags"
echo

echo "Checking Irodori-TTS-Server health..."
curl -fsS "$TTS_BASE_URL/health"
echo

echo "Checking Irodori-TTS-Server voices..."
curl -fsS "$TTS_BASE_URL/v1/audio/voices"
echo

echo "Checking STT server health (音声入力は任意)..."
curl -fsS "$STT_BASE_URL/health" || echo "STT server not reachable (voice input disabled)"
echo

echo "Checking conversation server health..."
curl -fsS "$APP_BASE_URL/api/health"
echo

echo "Checking text turn..."
curl -fsS \
  -X POST "$APP_BASE_URL/api/turns/text" \
  -H "Content-Type: application/json" \
  -d '{"text":"WSL実接続の確認です。短く返事してください。"}'
echo
