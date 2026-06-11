#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IRODORI_TTS_SERVER_DIR="${IRODORI_TTS_SERVER_DIR:-"$ROOT_DIR/../Irodori-TTS-Server"}"
# 既定はcaption対応(読み上げ設定→声質指示)を含むGentaAmekuフォーク。本家を使う場合は上書きする。
IRODORI_TTS_SERVER_REPO="${IRODORI_TTS_SERVER_REPO:-https://github.com/GentaAmeku/Irodori-TTS-Server.git}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing command: $1" >&2
    exit 1
  fi
}

require_command git
require_command uv

if [ ! -d "$IRODORI_TTS_SERVER_DIR/.git" ]; then
  git clone "$IRODORI_TTS_SERVER_REPO" "$IRODORI_TTS_SERVER_DIR"
fi

cd "$IRODORI_TTS_SERVER_DIR"
uv sync --extra rocm

if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
fi

cat <<EOF
Irodori-TTS-Server is set up for WSL AMD ROCm:
  $IRODORI_TTS_SERVER_DIR

Start it with:
  cd "$IRODORI_TTS_SERVER_DIR"
  uv run --extra rocm python -m irodori_openai_tts --host 0.0.0.0 --port 8088
EOF
