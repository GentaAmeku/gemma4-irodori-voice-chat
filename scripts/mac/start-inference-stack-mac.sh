#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${GIC_LOG_DIR:-"$ROOT_DIR/.logs"}"
IRODORI_TTS_SERVER_DIR="${IRODORI_TTS_SERVER_DIR:-"$ROOT_DIR/../Irodori-TTS-Server"}"
IRODORI_HOST="${IRODORI_HOST:-127.0.0.1}"
IRODORI_PORT="${IRODORI_PORT:-8088}"
IRODORI_UV_EXTRA="${IRODORI_UV_EXTRA:-cpu}"
OLLAMA_HOST_VALUE="${OLLAMA_HOST:-127.0.0.1:11434}"
GIC_OLLAMA_MODEL="${GIC_OLLAMA_MODEL:-gemma4:e4b-mlx}"

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
  else
    echo "Starting Ollama..."
    OLLAMA_HOST="$OLLAMA_HOST_VALUE" nohup ollama serve >"$LOG_DIR/ollama-mac.log" 2>&1 &
    echo $! >"$LOG_DIR/ollama-mac.pid"
    wait_http "http://$OLLAMA_HOST_VALUE/api/tags" "Ollama"
  fi

  if ! ollama list | awk '{print $1}' | grep -Fx "$GIC_OLLAMA_MODEL" >/dev/null 2>&1; then
    cat >&2 <<EOF
Ollama is running, but model '$GIC_OLLAMA_MODEL' was not found.

Install it before starting the conversation server:
  ollama pull $GIC_OLLAMA_MODEL
EOF
    exit 1
  fi
}

start_irodori() {
  require_command uv
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

  if curl -fsS "http://127.0.0.1:$IRODORI_PORT/health" >/dev/null 2>&1; then
    echo "Irodori-TTS-Server already running: http://127.0.0.1:$IRODORI_PORT"
    return 0
  fi

  echo "Starting Irodori-TTS-Server..."
  (
    cd "$IRODORI_TTS_SERVER_DIR"
    nohup uv run --extra "$IRODORI_UV_EXTRA" python -m irodori_openai_tts --host "$IRODORI_HOST" --port "$IRODORI_PORT" >"$LOG_DIR/irodori-mac.log" 2>&1 &
    echo $! >"$LOG_DIR/irodori-mac.pid"
  )
  wait_http "http://127.0.0.1:$IRODORI_PORT/health" "Irodori-TTS-Server" 120
}

start_ollama
start_irodori

cat <<EOF

MacBook local inference stack is ready.

Model:
  $GIC_OLLAMA_MODEL

Logs:
  $LOG_DIR/ollama-mac.log
  $LOG_DIR/irodori-mac.log

Next:
  ./scripts/mac/start-conversation-server-mac.sh
EOF
