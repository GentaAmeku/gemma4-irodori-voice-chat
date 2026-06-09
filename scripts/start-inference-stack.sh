#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${GIC_LOG_DIR:-"$ROOT_DIR/.logs"}"
IRODORI_TTS_SERVER_DIR="${IRODORI_TTS_SERVER_DIR:-"$ROOT_DIR/../Irodori-TTS-Server"}"
IRODORI_HOST="${IRODORI_HOST:-0.0.0.0}"
IRODORI_PORT="${IRODORI_PORT:-8088}"
IRODORI_UV_EXTRA="${IRODORI_UV_EXTRA:-rocm}"
OLLAMA_HOST_VALUE="${OLLAMA_HOST:-127.0.0.1:11434}"

mkdir -p "$LOG_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing command: $1" >&2
    exit 1
  fi
}

wait_http() {
  local url="$1"
  local name="$2"
  local attempts="${3:-60}"
  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$name ready: $url"
      return 0
    fi
    sleep 1
  done
  echo "$name did not become ready: $url" >&2
  return 1
}

start_ollama() {
  require_command ollama
  if curl -fsS "http://$OLLAMA_HOST_VALUE/api/tags" >/dev/null 2>&1; then
    echo "Ollama already running: http://$OLLAMA_HOST_VALUE"
    return 0
  fi

  echo "Starting Ollama..."
  OLLAMA_HOST="$OLLAMA_HOST_VALUE" nohup ollama serve >"$LOG_DIR/ollama.log" 2>&1 &
  echo $! >"$LOG_DIR/ollama.pid"
  wait_http "http://$OLLAMA_HOST_VALUE/api/tags" "Ollama"
}

start_irodori() {
  require_command uv
  if [ ! -d "$IRODORI_TTS_SERVER_DIR" ]; then
    cat >&2 <<EOF
Irodori-TTS-Server directory was not found:
  $IRODORI_TTS_SERVER_DIR

Clone and set it up first:
  git clone https://github.com/Aratako/Irodori-TTS-Server.git "$IRODORI_TTS_SERVER_DIR"
  cd "$IRODORI_TTS_SERVER_DIR"
  uv sync --extra rocm
  cp .env.example .env

Or set IRODORI_TTS_SERVER_DIR to an existing checkout.
EOF
    exit 1
  fi

  if curl -fsS "http://127.0.0.1:$IRODORI_PORT/health" >/dev/null 2>&1; then
    echo "Irodori-TTS-Server already running: http://127.0.0.1:$IRODORI_PORT"
    return 0
  fi

  echo "Starting Irodori-TTS-Server..."
  (
    cd "$IRODORI_TTS_SERVER_DIR"
    nohup uv run --extra "$IRODORI_UV_EXTRA" python -m irodori_openai_tts --host "$IRODORI_HOST" --port "$IRODORI_PORT" >"$LOG_DIR/irodori.log" 2>&1 &
    echo $! >"$LOG_DIR/irodori.pid"
  )
  wait_http "http://127.0.0.1:$IRODORI_PORT/health" "Irodori-TTS-Server" 120
}

start_ollama
start_irodori

cat <<EOF

Inference stack is ready.

Logs:
  $LOG_DIR/ollama.log
  $LOG_DIR/irodori.log

Irodori backend:
  uv extra: $IRODORI_UV_EXTRA

Next, start this app's conversation server:
  cd "$ROOT_DIR/server"
  GIC_OLLAMA_BASE_URL=http://$OLLAMA_HOST_VALUE \\
  GIC_TTS_BASE_URL=http://127.0.0.1:$IRODORI_PORT \\
  uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
EOF
