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
IRODORI_STATUS="未実行"
PORTPROXY_STATUS="未実行"
CONVERSATION_STATUS="未実行"
LAN_HEALTH_STATUS="未確認"

mkdir -p "$LOG_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "エラー: 必要なコマンドが見つかりません: $1" >&2
    exit 1
  fi
}

wait_http() {
  local url="$1"
  local name="$2"
  local attempts="${3:-60}"
  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "OK: $name の起動を確認しました: $url"
      return 0
    fi
    sleep 1
  done
  echo "エラー: $name の起動を確認できませんでした: $url" >&2
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
    echo "エラー: WSL から見た Windows ホスト IP を解決できませんでした。OLLAMA_HOST を手動指定してください。" >&2
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

powershell_is_elevated() {
  command -v powershell.exe >/dev/null 2>&1 &&
    powershell.exe -NoProfile -Command "\$identity = [Security.Principal.WindowsIdentity]::GetCurrent(); \$principal = [Security.Principal.WindowsPrincipal]::new(\$identity); if (\$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }" >/dev/null 2>&1
}

sync_windows_portproxy_scripts() {
  local windows_dir
  windows_dir="$(run_powershell "[System.IO.Path]::Combine(\$env:LOCALAPPDATA, 'Gemma4IrodoriChat', 'scripts')" | awk 'NF { print; exit }')"
  if [ -z "$windows_dir" ]; then
    echo "警告: Windows 側のスクリプト配置先を解決できませんでした。" >&2
    return 1
  fi

  local wsl_dir
  wsl_dir="$(wslpath -u "$windows_dir")"
  mkdir -p "$wsl_dir"
  cp "$ROOT_DIR/scripts/windows/install-portproxy-refresh-task.ps1" "$wsl_dir/install-portproxy-refresh-task.ps1"
  cp "$ROOT_DIR/scripts/windows/refresh-wsl-portproxy.ps1" "$wsl_dir/refresh-wsl-portproxy.ps1"

  echo "$windows_dir"
}

write_portproxy_install_wrapper() {
  local windows_dir="$1"
  local lan_ip="$2"
  local wsl_dir
  wsl_dir="$(wslpath -u "$windows_dir")"

  local wrapper_path="$wsl_dir/install-portproxy-task-wrapper.ps1"
  {
    printf '$ErrorActionPreference = "Stop"\n'
    printf '$ExitCode = 0\n'
    printf '$LogDir = Join-Path $env:LOCALAPPDATA "Gemma4IrodoriChat\\logs"\n'
    printf 'New-Item -ItemType Directory -Force -Path $LogDir | Out-Null\n'
    printf '$LogPath = Join-Path $LogDir "install-portproxy-task.log"\n'
    printf 'Start-Transcript -Path $LogPath -Force | Out-Null\n'
    printf 'try {\n'
    printf '  Write-Host "Installing Gemma4 Irodori Chat portproxy task..."\n'
    printf '  & "%s\\install-portproxy-refresh-task.ps1" -Port %s -TaskName "%s"' "$windows_dir" "$GIC_APP_PORT" "$WINDOWS_PORTPROXY_TASK"
    if [ -n "$lan_ip" ]; then
      printf ' -LanIp "%s"' "$lan_ip"
    fi
    printf '\n'
    printf '  Write-Host ""\n'
    printf '  Write-Host "OK: portproxy task installation finished."\n'
    printf '}\n'
    printf 'catch {\n'
    printf '  $ExitCode = 1\n'
    printf '  Write-Host ""\n'
    printf '  Write-Host "ERROR: portproxy task installation failed."\n'
    printf '  Write-Host $_.Exception.Message\n'
    printf '}\n'
    printf 'finally {\n'
    printf '  Write-Host ""\n'
    printf '  Write-Host "Log: $LogPath"\n'
    printf '  try { Stop-Transcript | Out-Null } catch { }\n'
    printf '  Write-Host ""\n'
    printf '  Read-Host "Press Enter to close this window"\n'
    printf '}\n'
    printf 'exit $ExitCode\n'
  } >"$wrapper_path"

  echo "$windows_dir\\install-portproxy-task-wrapper.ps1"
}

install_portproxy_task_elevated() {
  local lan_ip="$1"

  echo "情報: Windows portproxy 更新タスクが未登録です。"
  echo "情報: 昇格 PowerShell から確実に読めるよう、Windows 側へ portproxy スクリプトを同期します。"

  local windows_script_dir
  if ! windows_script_dir="$(sync_windows_portproxy_scripts)"; then
    echo "警告: Windows 側への portproxy スクリプト同期に失敗しました。" >&2
    return 1
  fi

  local wrapper_script
  wrapper_script="$(write_portproxy_install_wrapper "$windows_script_dir" "$lan_ip")"

  echo "情報: 初回登録のため、Windows の UAC 昇格ダイアログを開きます。"
  echo "情報: 昇格 PowerShell は完了後に Enter 入力待ちになります。表示内容を確認してください。"

  local ps_command
  ps_command="\$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '$wrapper_script')"
  ps_command="$ps_command; \$process = Start-Process -FilePath 'powershell.exe' -ArgumentList \$arguments -Verb RunAs -Wait -PassThru; exit \$process.ExitCode"

  if ! run_powershell "$ps_command" >/dev/null; then
    cat >&2 <<EOF

警告: Windows UAC での portproxy 更新タスク登録がキャンセルされたか、失敗しました。
必要な場合は、Windows の管理者 PowerShell で一度だけ手動登録してください:

  .\\scripts\\windows\\install-portproxy-refresh-task.ps1${lan_ip:+ -LanIp $lan_ip}

EOF
    return 1
  fi

  for _ in $(seq 1 10); do
    if task_exists; then
      echo "OK: Windows portproxy 更新タスクを登録しました。"
      return 0
    fi
    sleep 1
  done

  echo "警告: 登録処理後も Windows portproxy 更新タスクを確認できませんでした。" >&2
  return 1
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
  echo "警告: Windows portproxy 更新タスクが 30 秒以内に完了しませんでした: $WINDOWS_PORTPROXY_TASK" >&2
  return 1
}

refresh_windows_portproxy() {
  local lan_ip="$1"

  if ! command -v powershell.exe >/dev/null 2>&1; then
    PORTPROXY_STATUS="スキップ（powershell.exe が見つかりません）"
    echo "警告: powershell.exe が見つからないため、Windows portproxy 更新をスキップします。"
    return 0
  fi

  if task_exists; then
    sync_windows_portproxy_scripts >/dev/null || true
    echo "情報: Windows portproxy を登録済みタスク経由で更新します。"
    if ! run_powershell "Start-ScheduledTask -TaskName '$WINDOWS_PORTPROXY_TASK'" >/dev/null; then
      PORTPROXY_STATUS="失敗（登録済みタスクを開始できません）"
      echo "警告: Windows portproxy 更新タスクを開始できませんでした。" >&2
      return 1
    fi
    if ! wait_task_finished; then
      PORTPROXY_STATUS="失敗（登録済みタスクが完了しません）"
      return 1
    fi
    PORTPROXY_STATUS="OK（登録済みタスクで更新）"
    echo "OK: Windows portproxy 更新タスクを実行しました。"
    return 0
  fi

  if install_portproxy_task_elevated "$lan_ip" && task_exists; then
    echo "情報: Windows portproxy を登録済みタスク経由で更新します。"
    if ! run_powershell "Start-ScheduledTask -TaskName '$WINDOWS_PORTPROXY_TASK'" >/dev/null; then
      PORTPROXY_STATUS="失敗（初回登録後のタスク開始に失敗）"
      echo "警告: Windows portproxy 更新タスクを開始できませんでした。" >&2
      return 1
    fi
    if ! wait_task_finished; then
      PORTPROXY_STATUS="失敗（初回登録後のタスクが完了しません）"
      return 1
    fi
    PORTPROXY_STATUS="OK（初回登録後に更新）"
    echo "OK: Windows portproxy 更新タスクを実行しました。"
    return 0
  fi

  if ! powershell_is_elevated; then
    PORTPROXY_STATUS="失敗（管理者権限が必要）"
    cat >&2 <<EOF

警告: Windows portproxy は更新できませんでした。
理由: portproxy / Firewall 更新には Windows の管理者権限が必要です。
対応: UAC ダイアログを承認するか、Windows の管理者 PowerShell で一度だけタスクを登録してください:

  .\\scripts\\windows\\install-portproxy-refresh-task.ps1${lan_ip:+ -LanIp $lan_ip}

その後、WSL で再実行してください:

  ./scripts/wsl/start-desktop-stack.sh

EOF
    return 1
  fi

  local windows_script_dir
  if ! windows_script_dir="$(sync_windows_portproxy_scripts)"; then
    PORTPROXY_STATUS="失敗（Windows 側へのスクリプト同期に失敗）"
    echo "警告: Windows 側への portproxy スクリプト同期に失敗しました。" >&2
    return 1
  fi

  local refresh_script
  refresh_script="$windows_script_dir\\refresh-wsl-portproxy.ps1"
  local command="& '$refresh_script' -Port $GIC_APP_PORT -SkipHealthCheck"
  if [ -n "$lan_ip" ]; then
    command="$command -LanIp '$lan_ip'"
  fi

  echo "情報: Windows portproxy を管理者 PowerShell 権限で直接更新します。"
  if run_powershell "$command"; then
    PORTPROXY_STATUS="OK（直接更新）"
    echo "OK: Windows portproxy を直接更新しました。"
    return 0
  fi

  PORTPROXY_STATUS="失敗（直接更新に失敗）"
  cat >&2 <<EOF

警告: Windows portproxy は更新できませんでした。
対応: Windows の管理者 PowerShell で一度だけタスクを登録してください:

  .\\scripts\\windows\\install-portproxy-refresh-task.ps1${lan_ip:+ -LanIp $lan_ip}

その後、WSL で再実行してください:

  ./scripts/wsl/start-desktop-stack.sh

EOF
  return 1
}

start_irodori() {
  require_command uv
  if [ ! -d "$IRODORI_TTS_SERVER_DIR" ]; then
    cat >&2 <<EOF
エラー: Irodori-TTS-Server のディレクトリが見つかりません:
  $IRODORI_TTS_SERVER_DIR

先にセットアップしてください:
  ./scripts/wsl/setup-irodori-wsl-amd.sh
EOF
    exit 1
  fi

  if curl -fsS "http://127.0.0.1:$IRODORI_PORT/health" >/dev/null 2>&1; then
    IRODORI_STATUS="OK（起動済み）"
    echo "OK: Irodori-TTS-Server は既に起動しています: http://127.0.0.1:$IRODORI_PORT"
    return 0
  fi

  echo "情報: Irodori-TTS-Server を起動します。"
  (
    cd "$IRODORI_TTS_SERVER_DIR"
    nohup uv run --extra "$IRODORI_UV_EXTRA" python -m irodori_openai_tts --host "$IRODORI_HOST" --port "$IRODORI_PORT" >"$LOG_DIR/irodori-wsl.log" 2>&1 &
    echo $! >"$LOG_DIR/irodori-wsl.pid"
  )
  wait_http "http://127.0.0.1:$IRODORI_PORT/health" "Irodori-TTS-Server" 120
  IRODORI_STATUS="OK（起動しました）"
}

check_windows_lan_health() {
  local lan_ip="$1"
  if [ -z "$lan_ip" ] || ! command -v powershell.exe >/dev/null 2>&1; then
    LAN_HEALTH_STATUS="スキップ（Windows LAN IP または powershell.exe なし）"
    return 0
  fi

  local url="http://$lan_ip:$GIC_APP_PORT/api/health"
  if run_powershell "Invoke-WebRequest -Uri '$url' -UseBasicParsing -TimeoutSec 5 | Out-Null" >/dev/null 2>&1; then
    LAN_HEALTH_STATUS="OK（Windows PC から LAN IP へ到達）"
    echo "OK: Windows PC から LAN IP の会話サーバーへ到達できました: $url"
    return 0
  fi

  LAN_HEALTH_STATUS="失敗（Windows PC から LAN IP へ到達不可）"
  cat >&2 <<EOF

警告: Windows PC から LAN IP の会話サーバーへ到達できませんでした:
  $url

診断する場合は Windows PowerShell で実行してください:
  .\\scripts\\windows\\check-lan-portproxy.ps1${lan_ip:+ -LanIp $lan_ip}

EOF
  return 1
}

start_conversation_server() {
  local ollama_host="$1"

  if curl -fsS "http://127.0.0.1:$GIC_APP_PORT/api/health" >/dev/null 2>&1; then
    CONVERSATION_STATUS="OK（起動済み）"
    echo "OK: 会話サーバーは既に起動しています: http://127.0.0.1:$GIC_APP_PORT"
    SERVER_ALREADY_RUNNING=1
    return 0
  fi

  local log_file="$LOG_DIR/conversation-wsl.log"
  echo "情報: 会話サーバーを起動します。"
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
    CONVERSATION_STATUS="失敗（起動できませんでした）"
    echo "エラー: 会話サーバーを起動できませんでした。直近ログ:" >&2
    tail -80 "$log_file" >&2 || true
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    exit 1
  fi
  CONVERSATION_STATUS="OK（起動しました）"
}

require_command curl
require_command awk

OLLAMA_HOST_VALUE="$(resolve_ollama_host)"
if ! curl -fsS "http://$OLLAMA_HOST_VALUE/api/tags" >/dev/null 2>&1; then
  cat >&2 <<EOF
エラー: WSL から Windows Ollama へ到達できません:
  http://$OLLAMA_HOST_VALUE/api/tags

Windows 側で Ollama を起動し、確認してください:
  ollama list
EOF
  exit 1
fi

WSL_IP="$(hostname -I | awk '{print $1}')"
LAN_IP="$(resolve_windows_lan_ip || true)"

echo "Gemma4 Irodori Chat: WSL スタック起動"
echo "  WSL IP:          ${WSL_IP:-不明}"
echo "  Windows LAN IP:  ${LAN_IP:-不明}"
echo "  Ollama:          http://$OLLAMA_HOST_VALUE"
echo "  Irodori:         $GIC_TTS_BASE_URL"
echo ""

start_irodori
refresh_windows_portproxy "$LAN_IP" || true
start_conversation_server "$OLLAMA_HOST_VALUE"
check_windows_lan_health "$LAN_IP" || true

cat <<EOF

起動結果:
  Irodori-TTS:      $IRODORI_STATUS
  portproxy更新:    $PORTPROXY_STATUS
  会話サーバー:      $CONVERSATION_STATUS
  LAN疎通確認:      $LAN_HEALTH_STATUS

会話サーバーは利用可能です。

ローカル確認:
  http://127.0.0.1:$GIC_APP_PORT/api/health
LAN確認:
  ${LAN_IP:+http://$LAN_IP:$GIC_APP_PORT/api/health}

ログ:
  $LOG_DIR/irodori-wsl.log
  $LOG_DIR/conversation-wsl.log
EOF

if [ "$SERVER_ALREADY_RUNNING" -eq 1 ]; then
  echo "情報: 会話サーバーは既に起動していたため、このスクリプトでは停止管理しません。"
  exit 0
fi

echo "停止するには Ctrl-C を押してください。会話サーバーを停止します。Irodori はバックグラウンドに残ります。"
echo ""

tail -n +1 -f "$LOG_DIR/conversation-wsl.log" &
TAIL_PID=$!

cleanup() {
  kill "$TAIL_PID" >/dev/null 2>&1 || true
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    echo "情報: 会話サーバーを停止します。"
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup INT TERM EXIT

wait "$SERVER_PID"
