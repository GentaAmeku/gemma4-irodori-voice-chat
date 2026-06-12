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
APP_BASE_URL="${GIC_APP_BASE_URL:-http://127.0.0.1:8000}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${GIC_LOG_DIR:-"$ROOT_DIR/.logs"}"

print_log_tail() {
  local label="$1"
  local path="$2"
  if [ -f "$path" ]; then
    echo
    echo "---- ${label}: ${path} (tail -80) ----"
    tail -80 "$path" || true
  fi
}

post_json_check() {
  local label="$1"
  local url="$2"
  local payload="$3"
  local output_mode="${4:-text}"
  local output_file
  local status
  output_file="$(mktemp)"

  echo "$label"
  if ! status="$(
    curl -sS \
      --max-time 360 \
      -o "$output_file" \
      -w "%{http_code}" \
      -X POST "$url" \
      -H "Content-Type: application/json" \
      -d "$payload"
  )"; then
    echo "ERROR: curl failed while calling $url" >&2
    echo "Response body:" >&2
    cat "$output_file" >&2 || true
    echo >&2
    rm -f "$output_file"
    return 1
  fi

  if [[ "$status" =~ ^2 ]]; then
    echo "OK: HTTP $status"
    if [ "$output_mode" = "bytes" ]; then
      wc -c "$output_file"
    else
      cat "$output_file"
      echo
    fi
    rm -f "$output_file"
    return 0
  fi

  echo "ERROR: HTTP $status" >&2
  echo "Response body:" >&2
  cat "$output_file" >&2 || true
  echo >&2
  rm -f "$output_file"
  return 1
}

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

echo "Checking conversation server health..."
curl -fsS "$APP_BASE_URL/api/health"
echo

# 設定中の話者が未登録だと、会話サーバーはno-ref音声へフォールバックして
# 別人の声で読み上げてしまうため、疎通確認の段階で検出する。
echo "Checking configured speaker is registered..."
speaker_id="$(curl -fsS "$APP_BASE_URL/api/settings" \
  | python3 -c "import json, sys; print(json.load(sys.stdin)['speaker_id'])")"
if ! curl -fsS "$TTS_BASE_URL/v1/audio/voices" \
  | SPEAKER_ID="$speaker_id" python3 -c '
import json, os, sys

speaker_id = os.environ["SPEAKER_ID"]
voices = sorted(item["id"] for item in json.load(sys.stdin)["data"])
if speaker_id in voices:
    print(f"OK: speaker {speaker_id!r} is registered")
else:
    print(
        f"ERROR: speaker {speaker_id!r} is not registered (available: {voices}). "
        "Conversation turns will fall back to the no-ref voice. "
        "Run scripts/wsl/setup-irodori-wsl-amd.sh or "
        f"scripts/register-conversation-voice.sh {speaker_id} <audio-file>.",
        file=sys.stderr,
    )
    sys.exit(1)
'; then
  exit 1
fi
echo

echo "Checking direct Irodori-TTS speech synthesis..."
if ! post_json_check \
  "POST $TTS_BASE_URL/v1/audio/speech" \
  "$TTS_BASE_URL/v1/audio/speech" \
  '{"model":"irodori-tts","input":"TTS直接疎通の確認です。","voice":{"id":"none"},"response_format":"wav","speed":1.0,"irodori":{"seed":1234567}}' \
  "bytes"; then
  print_log_tail "Irodori-TTS log" "$LOG_DIR/irodori-wsl.log"
  exit 1
fi
echo

echo "Checking text turn..."
if ! post_json_check \
  "POST $APP_BASE_URL/api/turns/text" \
  "$APP_BASE_URL/api/turns/text" \
  '{"text":"WSL実接続の確認です。短く返事してください。"}'; then
  print_log_tail "Conversation server log" "$LOG_DIR/conversation-wsl.log"
  print_log_tail "Irodori-TTS log" "$LOG_DIR/irodori-wsl.log"
  exit 1
fi
echo
