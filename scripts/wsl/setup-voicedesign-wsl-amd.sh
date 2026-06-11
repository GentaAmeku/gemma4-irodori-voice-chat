#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IRODORI_TTS_DIR="${IRODORI_TTS_DIR:-"$ROOT_DIR/../Irodori-TTS"}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing command: $1" >&2
    exit 1
  fi
}

require_command git
require_command uv

if [ ! -d "$IRODORI_TTS_DIR/.git" ]; then
  git clone https://github.com/Aratako/Irodori-TTS.git "$IRODORI_TTS_DIR"
fi

cd "$IRODORI_TTS_DIR"
uv sync --extra rocm

cat <<EOF
Irodori-TTS (VoiceDesign) is set up for WSL AMD ROCm:
  $IRODORI_TTS_DIR

Generate reference voice candidates with:
  scripts/generate-voicedesign-sample.sh

Details: docs/voicedesign-sample-setup.md
EOF
