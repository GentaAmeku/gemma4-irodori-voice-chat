#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${GIC_LOG_DIR:-"$ROOT_DIR/.logs"}"
IRODORI_TTS_SERVER_DIR="${IRODORI_TTS_SERVER_DIR:-"$ROOT_DIR/../Irodori-TTS-Server"}"
IRODORI_HOST="${IRODORI_HOST:-0.0.0.0}"
IRODORI_PORT="${IRODORI_PORT:-8088}"
IRODORI_UV_EXTRA="${IRODORI_UV_EXTRA:-rocm}"
GIC_APP_HOST="${GIC_APP_HOST:-0.0.0.0}"
GIC_APP_PORT="${GIC_APP_PORT:-8000}"
GIC_OLLAMA_MODEL="${GIC_OLLAMA_MODEL:-gemma4:12b}"
GIC_TTS_BASE_URL="${GIC_TTS_BASE_URL:-http://127.0.0.1:$IRODORI_PORT}"
WINDOWS_PORTPROXY_TASK="${GIC_WINDOWS_PORTPROXY_TASK:-Gemma4 Irodori Chat Refresh PortProxy}"
SERVER_PID=""
SERVER_ALREADY_RUNNING=0

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

resolve_ollama_host() {
  if [ -n "${OLLAMA_HOST:-}" ]; then
    echo "$OLLAMA_HOST"
    return
  fi

  if curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "127.0.0.1:11434"
    return
  fi

  local windows_host
  windows_host="$(ip route show default | awk '{print $3; exit}')"
  if [ -z "$windows_host" ]; then
    echo "Could not resolve Windows host IP. Set OLLAMA_HOST manually." >&2
    exit 1
  fi
  echo "${windows_host}:11434"
}

resolve_windows_lan_ip() {
  if [ -n "${GIC_DESKTOP_LAN_IP:-}" ]; then
    echo "$GIC_DESKTOP_LAN_IP"
    return
  fi

  if ! command -v powershell.exe >/dev/null 2>&1; then
    return 0
  fi

  powershell.exe -NoProfile -Command '
    $ip = Get-NetIPConfiguration |
      Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" } |
      ForEach-Object { $_.IPv4Address } |
      Where-Object { $_.IPAddress -and $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
      Select-Object -First 1 -ExpandProperty IPAddress
    if ($ip) { $ip }
  ' 2>/dev/null | tr -d '\r' | awk 'NF { print; exit }'
}

run_powershell() {
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$1" | tr -d '\r'
}

task_exists() {
  command -v powershell.exe >/dev/null 2>&1 &&
    powershell.exe -NoProfile -Command "if (Get-ScheduledTask -TaskName '$WINDOWS_PORTPROXY_TASK' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >/dev/null 2>&1
}

wait_task_finished() {
  local state
  for _ in $(seq 1 30); do
    state="$(run_powershell "(Get-ScheduledTask -TaskName '$WINDOWS_PORTPROXY_TASK').State" 2>/dev/null | awk 'NF { print; exit }')"
    if [ "$state" != "Running" ]; then
      return 0
    fi
    sleep 1
  done
  echo "Windows scheduled task did not finish within 30 seconds: $WINDOWS_PORTPROXY_TASK" >&2
  return 1
}

refresh_windows_portproxy() {
  local lan_ip="$1"

  if ! command -v powershell.exe >/dev/null 2>&1; then
    echo "powershell.exe is unavailable; skipping Windows portproxy refresh."
    return 0
  fi

  if task_exists; then
    echo "Refreshing Windows portproxy via scheduled task..."
    run_powershell "Start-ScheduledTask -TaskName '$WINDOWS_PORTPROXY_TASK'" >/dev/null
    wait_task_finished
    return 0
  fi

  local refresh_script
  refresh_script="$(wslpath -w "$ROOT_DIR/scripts/windows/refresh-wsl-portproxy.ps1")"
  local command="& '$refresh_script' -Port $GIC_APP_PORT -SkipHealthCheck"
  if [ -n "$lan_ip" ]; then
    command="$command -LanIp '$lan_ip'"
  fi

  echo "Refreshing Windows portproxy directly..."
  if run_powershell "$command"; then
    return 0
  fi

  cat >&2 <<EOF

Windows portproxy refresh did not run.
Install the elevated scheduled task once from an administrator PowerShell:

  .\\scripts\\windows\\install-portproxy-refresh-task.ps1${lan_ip:+ -LanIp $lan_ip}

Then rerun:

  ./scripts/wsl/start-desktop-stack.sh

EOF
  return 1
}

start_irodori() {
  require_command uv
  if [ ! -d "$IRODORI_TTS_SERVER_DIR" ]; then
    cat >&2 <<EOF
Irodori-TTS-Server directory was not found:
  $IRODORI_TTS_SERVER_DIR

Set it up first:
  ./scripts/wsl/setup-irodori-wsl-amd.sh
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
    nohup uv run --extra "$IRODORI_UV_EXTRA" python -m irodori_openai_tts --host "$IRODORI_HOST" --port "$IRODORI_PORT" >"$LOG_DIR/irodori-wsl.log" 2>&1 &
    echo $! >"$LOG_DIR/irodori-wsl.pid"
  )
  wait_http "http://127.0.0.1:$IRODORI_PORT/health" "Irodori-TTS-Server" 120
}

check_windows_lan_health() {
  local lan_ip="$1"
  if [ -z "$lan_ip" ] || ! command -v powershell.exe >/dev/null 2>&1; then
    return 0
  fi

  local url="http://$lan_ip:$GIC_APP_PORT/api/health"
  if run_powershell "Invoke-WebRequest -Uri '$url' -UseBasicParsing -TimeoutSec 5 | Out-Null" >/dev/null 2>&1; then
    echo "Windows LAN health OK: $url"
    return 0
  fi

  cat >&2 <<EOF

Windows LAN health failed:
  $url

Run diagnostics from PowerShell:
  .\\scripts\\windows\\check-lan-portproxy.ps1${lan_ip:+ -LanIp $lan_ip}

EOF
  return 1
}

start_conversation_server() {
  local ollama_host="$1"

  if curl -fsS "http://127.0.0.1:$GIC_APP_PORT/api/health" >/dev/null 2>&1; then
    echo "Conversation server already running: http://127.0.0.1:$GIC_APP_PORT"
    SERVER_ALREADY_RUNNING=1
    return 0
  fi

  local log_file="$LOG_DIR/conversation-wsl.log"
  echo "Starting conversation server..."
  (
    cd "$ROOT_DIR/server"
    GIC_OLLAMA_BASE_URL="http://$ollama_host" \
      GIC_OLLAMA_MODEL="$GIC_OLLAMA_MODEL" \
      GIC_TTS_BASE_URL="$GIC_TTS_BASE_URL" \
      uv run uvicorn app.main:app --host "$GIC_APP_HOST" --port "$GIC_APP_PORT"
  ) >"$log_file" 2>&1 &

  SERVER_PID=$!
  echo "$SERVER_PID" >"$LOG_DIR/conversation-wsl.pid"

  if ! wait_http "http://127.0.0.1:$GIC_APP_PORT/api/health" "Conversation server" 60; then
    echo "Conversation server failed to start. Recent log:" >&2
    tail -80 "$log_file" >&2 || true
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    exit 1
  fi
}

require_command curl
require_command awk

OLLAMA_HOST_VALUE="$(resolve_ollama_host)"
if ! curl -fsS "http://$OLLAMA_HOST_VALUE/api/tags" >/dev/null 2>&1; then
  cat >&2 <<EOF
Windows Ollama is not reachable from WSL:
  http://$OLLAMA_HOST_VALUE/api/tags

Start Windows Ollama and confirm:
  ollama list
EOF
  exit 1
fi

WSL_IP="$(hostname -I | awk '{print $1}')"
LAN_IP="$(resolve_windows_lan_ip || true)"

echo "Desktop WSL stack"
echo "  WSL IP:         ${WSL_IP:-unknown}"
echo "  Windows LAN IP: ${LAN_IP:-unknown}"
echo "  Ollama:         http://$OLLAMA_HOST_VALUE"
echo "  Irodori:        $GIC_TTS_BASE_URL"
echo ""

start_irodori
refresh_windows_portproxy "$LAN_IP" || true
start_conversation_server "$OLLAMA_HOST_VALUE"
check_windows_lan_health "$LAN_IP" || true

cat <<EOF

Desktop stack is ready.

Local:
  http://127.0.0.1:$GIC_APP_PORT/api/health
LAN:
  ${LAN_IP:+http://$LAN_IP:$GIC_APP_PORT/api/health}

Logs:
  $LOG_DIR/irodori-wsl.log
  $LOG_DIR/conversation-wsl.log
EOF

if [ "$SERVER_ALREADY_RUNNING" -eq 1 ]; then
  echo "Conversation server was already running; leaving it untouched."
  exit 0
fi

echo "Press Ctrl-C to stop the conversation server. Irodori remains running in the background."
echo ""

tail -n +1 -f "$LOG_DIR/conversation-wsl.log" &
TAIL_PID=$!

cleanup() {
  kill "$TAIL_PID" >/dev/null 2>&1 || true
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    echo "Stopping conversation server..."
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup INT TERM EXIT

wait "$SERVER_PID"
