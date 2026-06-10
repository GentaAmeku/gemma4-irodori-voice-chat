#!/usr/bin/env bash
set -euo pipefail

OLLAMA_BASE_URL="${GIC_OLLAMA_BASE_URL:-http://127.0.0.1:11434}"
TTS_BASE_URL="${GIC_TTS_BASE_URL:-http://127.0.0.1:8088}"
STT_BASE_URL="${GIC_STT_BASE_URL:-http://127.0.0.1:8099}"
APP_BASE_URL="${GIC_APP_BASE_URL:-http://127.0.0.1:8000}"

echo "Checking Ollama..."
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
  -d '{"text":"MacBookローカル実接続の確認です。短く返事してください。"}'
echo
