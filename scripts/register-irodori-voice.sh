#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/register-irodori-voice.sh <voice-id> <audio-file> [--replace]

Environment:
  TTS_BASE_URL      Irodori-TTS-Server base URL. Default: http://127.0.0.1:8088
  IRODORI_API_KEY  Optional API key. Sent as Bearer token when set.

Examples:
  scripts/register-irodori-voice.sh rinon ./rinon.wav
  scripts/register-irodori-voice.sh rinon ./rinon.wav --replace
USAGE
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 2
fi

voice_id="$1"
audio_file="$2"
mode="${3:-}"
tts_base_url="${TTS_BASE_URL:-http://127.0.0.1:8088}"
tts_base_url="${tts_base_url%/}"

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

auth_args=()
if [[ -n "${IRODORI_API_KEY:-}" ]]; then
  auth_args=(-H "Authorization: Bearer ${IRODORI_API_KEY}")
fi

if [[ "$mode" == "--replace" ]]; then
  curl -fsS \
    -X PUT \
    "${auth_args[@]}" \
    -F "file=@${audio_file}" \
    "${tts_base_url}/v1/audio/voices/${voice_id}"
else
  curl -fsS \
    "${auth_args[@]}" \
    -F "voice_id=${voice_id}" \
    -F "file=@${audio_file}" \
    "${tts_base_url}/v1/audio/voices"
fi

echo
echo "Registered voices:"
curl -fsS "${auth_args[@]}" "${tts_base_url}/v1/audio/voices"
echo
