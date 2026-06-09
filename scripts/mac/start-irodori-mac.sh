#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IRODORI_TTS_SERVER_DIR="${IRODORI_TTS_SERVER_DIR:-"$ROOT_DIR/../Irodori-TTS-Server"}"
IRODORI_HOST="${IRODORI_HOST:-127.0.0.1}"
IRODORI_PORT="${IRODORI_PORT:-8088}"
IRODORI_UV_EXTRA="${IRODORI_UV_EXTRA:-cpu}"

if [ ! -d "$IRODORI_TTS_SERVER_DIR" ]; then
  cat >&2 <<EOF
Irodori-TTS-Server directory was not found:
  $IRODORI_TTS_SERVER_DIR

Set it up first:
  ./scripts/mac/setup-irodori-mac.sh

Or set IRODORI_TTS_SERVER_DIR to an existing checkout.
EOF
  exit 1
fi

cd "$IRODORI_TTS_SERVER_DIR"
uv run --extra "$IRODORI_UV_EXTRA" python -m irodori_openai_tts --host "$IRODORI_HOST" --port "$IRODORI_PORT"
