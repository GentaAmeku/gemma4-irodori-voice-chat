#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/register-conversation-voice.sh <voice-id> <audio-file> [--replace]

Environment:
  SERVER_BASE_URL  Conversation server base URL. Default: http://127.0.0.1:8000

Examples:
  SERVER_BASE_URL=http://192.168.3.2:8000 scripts/register-conversation-voice.sh rinon ./rinon.wav
  SERVER_BASE_URL=http://192.168.3.2:8000 scripts/register-conversation-voice.sh rinon ./rinon.wav --replace
USAGE
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 2
fi

voice_id="$1"
audio_file="$2"
mode="${3:-}"
server_base_url="${SERVER_BASE_URL:-http://127.0.0.1:8000}"
server_base_url="${server_base_url%/}"

if [[ "$mode" != "" && "$mode" != "--replace" ]]; then
  usage >&2
  exit 2
fi

if [[ ! "$voice_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "voice-id must contain only ASCII letters, numbers, underscores, or hyphens." >&2
  exit 2
fi

if [[ ! -f "$audio_file" ]]; then
  echo "audio-file not found: $audio_file" >&2
  exit 2
fi

replace_query="false"
if [[ "$mode" == "--replace" ]]; then
  replace_query="true"
fi

curl -fsS \
  -X POST \
  -F "file=@${audio_file}" \
  "${server_base_url}/api/speakers/${voice_id}?replace=${replace_query}"
echo
