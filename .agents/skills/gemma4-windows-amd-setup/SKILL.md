---
name: gemma4-windows-amd-setup
description: Use when setting up or troubleshooting Gemma4 Irodori Chat on a Windows AMD inference PC, including WSL2 Ubuntu, Windows Ollama, ROCm Irodori-TTS-Server, FastAPI server startup, LAN portproxy/firewall, and MacBook client connection.
---

# Gemma4 Windows AMD Setup

Use this skill for Windows AMD environment setup and recovery for Gemma4 Irodori Chat.

## Default stance

- Treat WSL2 Ubuntu as the standard path for this project.
- Assume WSL is already installed; do not make project setup depend on `wsl --install`.
- Keep Windows native Irodori as a fallback only.
- Keep this repo, the FastAPI server, and Irodori-TTS-Server on the WSL Linux filesystem, not under `/mnt/c/...`.
- Keep Irodori-TTS-Server outside this repository, normally as `../Irodori-TTS-Server`.
- Use Windows Ollama with default model `gemma4:12b`.
- Use `sudo npm install -g pnpm@11.1.2` in WSL; do not reintroduce `corepack enable` or `corepack prepare` as the default setup path.
- Preserve LAN-only assumptions. Do not suggest public exposure, tunnels, or internet-facing access as the default fix.

## First files to read

Before changing setup instructions or diagnosing a setup issue, read:

1. `docs/wsl-amd-setup.md`
2. `docs/scripts-and-startup.md`
3. `docs/verification.md`

Use those docs as the source of truth for command names and current project status.

## Command boundary

Keep PowerShell and WSL commands clearly separated.

PowerShell is for:

```powershell
wsl --list --verbose
wsl --shutdown
wsl -d Ubuntu-24.04
winget install Ollama.Ollama
ollama pull gemma4:12b
ollama list
ipconfig
netsh interface portproxy show v4tov4
Get-NetConnectionProfile
```

WSL Ubuntu is for:

```bash
sudo apt update
uv --version
node --version
pnpm --version
hostname -I
./scripts/wsl/setup-irodori-wsl-amd.sh
./scripts/wsl/start-desktop-stack.sh
./scripts/wsl/start-irodori-wsl-amd.sh
./scripts/wsl/start-conversation-server-wsl.sh
./scripts/wsl/start-client-wsl.sh
./scripts/wsl/check-wsl-stack.sh
```

## Setup workflow

1. Confirm WSL2 Ubuntu is available from PowerShell with `wsl --list --verbose`.
2. Confirm Windows Ollama is installed and has `gemma4:12b` with `ollama list`.
3. Confirm WSL can reach Windows Ollama:

```bash
curl http://127.0.0.1:11434/api/tags
```

If that fails in WSL, try the Windows host IP:

```bash
WINDOWS_HOST="$(ip route show default | awk '{print $3; exit}')"
curl "http://${WINDOWS_HOST}:11434/api/tags"
```

4. Set up Irodori-TTS-Server from WSL:

```bash
./scripts/wsl/setup-irodori-wsl-amd.sh
```

5. Start services. The recommended daily entry point is the bundled script:

```text
Windows Ollama
WSL stack (Irodori + portproxy refresh + conversation server): ./scripts/wsl/start-desktop-stack.sh
Client:
  - MacBook or another LAN device: connect its client to http://<inference-pc-lan-ip>:8000
  - Single Windows PC (no separate client device): ./scripts/wsl/start-client-wsl.sh,
    then open http://localhost:5173 in the Windows browser
```

Or start each service individually:

```text
Windows Ollama
WSL Irodori-TTS-Server: ./scripts/wsl/start-irodori-wsl-amd.sh
WSL conversation server: ./scripts/wsl/start-conversation-server-wsl.sh
WSL client: ./scripts/wsl/start-client-wsl.sh
```

6. Validate from WSL:

```bash
./scripts/wsl/check-wsl-stack.sh
```

## LAN and MacBook connection

MacBook or other LAN clients connect only to the conversation server:

```text
MacBook client
  -> http://<desktop-pc-lan-ip>:8000
  -> Windows portproxy or WSL mirrored networking
  -> WSL FastAPI conversation server
  -> Windows Ollama / WSL irodori-TTS
```

Do not make MacBook connect directly to Ollama or irodori-TTS.

Use the Windows LAN IPv4 from `ipconfig`, not the default gateway:

```text
IPv4 Address: 192.168.3.2          <- use this
Default Gateway: 192.168.3.1       <- do not use this
```

If Windows PowerShell can reach `127.0.0.1:8000` but cannot reach `<desktop-pc-lan-ip>:8000`, diagnose Windows LAN exposure, not the FastAPI server:

```powershell
curl.exe http://127.0.0.1:8000/api/health
curl.exe http://<desktop-pc-lan-ip>:8000/api/health
netsh interface portproxy show v4tov4
Get-Service iphlpsvc
Get-NetConnectionProfile
```

For WSL2 NAT, create or refresh portproxy from administrator PowerShell:

```powershell
$LanIp = "<desktop-pc-lan-ip>"
$WslIp = (wsl -d Ubuntu-24.04 hostname -I).Trim().Split(" ")[0]

netsh interface portproxy delete v4tov4 listenaddress=$LanIp listenport=8000
netsh interface portproxy add v4tov4 listenaddress=$LanIp listenport=8000 connectaddress=$WslIp connectport=8000

New-NetFirewallRule `
  -DisplayName "Gemma4 Irodori Chat API 8000" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalAddress $LanIp `
  -LocalPort 8000 `
  -Profile Private
```

If `Get-NetConnectionProfile` shows `NetworkCategory : Public`, the Private firewall rule will not apply. For a trusted home LAN, change it from administrator PowerShell:

```powershell
Set-NetConnectionProfile -InterfaceIndex <InterfaceIndex> -NetworkCategory Private
```

## Troubleshooting priorities

- If `address already in use` appears for `0.0.0.0:8000`, another conversation server is already running; do not start a second one.
- If `/api/health` works on `127.0.0.1` but not the LAN IP, inspect portproxy, firewall, `iphlpsvc`, and network profile.
- If `/api/speakers` returns only `none`, no reference voice is registered in Irodori-TTS-Server; voice tone may not match the intended character.
- If the Mac UI shows dependency failures, first verify `curl http://<desktop-pc-lan-ip>:8000/api/health` from the Mac.
- If Irodori ROCm setup fails, check AMD ROCm on WSL prerequisites before editing app code.

## Validation before finishing

Run the smallest relevant checks:

```bash
bash -n scripts/wsl/*.sh
cd server && UV_CACHE_DIR=/private/tmp/uv-cache-gemma4-irodori uv run pytest
cd client && pnpm check
cd client && pnpm build
```

Run `cd client && pnpm test:e2e` when client behavior or displayed model/settings changed.

For real services, confirm:

```bash
curl http://<desktop-pc-lan-ip>:8000/api/health
curl -X POST http://<desktop-pc-lan-ip>:8000/api/turns/text \
  -H "Content-Type: application/json" \
  -d '{"text":"実接続の確認です。短く返事してください。"}'
```
