#!/usr/bin/env bash
set -euo pipefail

OLLAMA_BASE_URL="${GIC_OLLAMA_BASE_URL:-http://127.0.0.1:11434}"
TTS_BASE_URL="${GIC_TTS_BASE_URL:-http://127.0.0.1:8088}"
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
        "Run scripts/mac/setup-irodori-mac.sh or "
        f"scripts/register-conversation-voice.sh {speaker_id} <audio-file>.",
        file=sys.stderr,
    )
    sys.exit(1)
'; then
  exit 1
fi
echo

echo "Checking text turn..."
curl -fsS \
  -X POST "$APP_BASE_URL/api/turns/text" \
  -H "Content-Type: application/json" \
  -d '{"text":"MacBookローカル実接続の確認です。短く返事してください。"}'
echo
