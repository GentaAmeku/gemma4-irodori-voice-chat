---
name: gemma4-irodori-setup
description: Use when setting up, documenting, or debugging the Gemma4 Irodori Chat project on a Windows AMD inference PC with WSL, Ollama, Irodori-TTS-Server, FastAPI, and the Svelte client.
---

# Gemma4 Irodori Setup

Use this skill for setup and troubleshooting work in this repository.

## Default stance

- Treat WSL2 Ubuntu as the standard Windows AMD setup path.
- Assume WSL is already installed; do not make the project setup depend on `wsl --install`.
- Keep Windows native Irodori as a fallback only, not the main path.
- Keep Irodori-TTS-Server outside this repository by default, usually as `../Irodori-TTS-Server`.
- Default Ollama model is `gemma4:12b`; use `GIC_OLLAMA_MODEL` only for overrides.
- MacBook or other LAN clients connect to the conversation server only, for example `http://<desktop-pc-lan-ip>:8000`; they do not connect directly to Ollama or irodori-TTS.
- For MacBook local development, keep it as a separate profile: local Ollama model `gemma4:e4b-mlx`, local Irodori-TTS-Server with `cpu` extra by default, local conversation server on `127.0.0.1:8000`, and client started through `scripts/mac/start-client-mac.sh`.

## Setup workflow

1. Read `docs/wsl-amd-setup.md` before changing setup instructions.
2. Use `docs/verification.md` for manual verification and `docs/handoff.md` after a session reset. Read `docs/macbook-local-setup.md` when setting up or debugging MacBook local development.
3. Keep PowerShell commands and WSL Ubuntu commands clearly separated.
4. Use `sudo npm install -g pnpm@11.1.2` for pnpm in WSL. Do not reintroduce `corepack enable` or `corepack prepare` as the default path.
5. Start services in this order:
   - Windows Ollama
   - WSL Irodori-TTS-Server: `./scripts/wsl/start-irodori-wsl-amd.sh`
   - WSL conversation server: `./scripts/wsl/start-conversation-server-wsl.sh`
   - WSL client: `cd client && pnpm dev`
6. Validate with `./scripts/wsl/check-wsl-stack.sh` after services are running.

## Troubleshooting priorities

- If WSL cannot reach Ollama, check `http://127.0.0.1:11434/api/tags` first, then the Windows host IP from `ip route show default`.
- If Irodori ROCm setup fails, check AMD ROCm on WSL prerequisites before editing app code.
- If Windows browser cannot open the client, check Vite is running in WSL and then use the WSL IP from `hostname -I`.
- If a MacBook cannot reach the desktop WSL conversation server, check Windows private firewall rules, WSL mirrored networking, or a Windows `netsh interface portproxy` rule for port 8000.
- Preserve LAN-only assumptions; do not suggest public exposure or tunneling as a default fix.

## Validation before finishing

Run the smallest relevant checks:

```bash
bash -n scripts/wsl/*.sh
cd server && uv run pytest
cd client && pnpm check
cd client && pnpm build
```

Run `cd client && pnpm test:e2e` when client behavior or displayed model/settings changed.
