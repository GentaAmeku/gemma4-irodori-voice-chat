---
name: gemma4-macbook-local-setup
description: Use when setting up, starting, stopping, validating, or troubleshooting Gemma4 Irodori Chat entirely on the development MacBook, including local Ollama with gemma4:e4b-mlx, local Irodori-TTS-Server using the cpu extra, the FastAPI conversation server on 127.0.0.1:8000, and the Svelte client with a Mac-local storage key. Use this instead of the Windows AMD/WSL skill whenever the user says MacBook local, Mac, this Mac, local development, e4b-mlx, or wants to avoid depending on the desktop PC.
---

# Gemma4 MacBook Local Setup

Use this skill for MacBook-only development and recovery work in this repository.

## Default stance

- Treat MacBook local as a separate development profile, not a replacement for the Windows AMD / WSL production-like path.
- Use local Ollama with `gemma4:e4b-mlx` by default. Do not switch the Windows default `gemma4:12b` to the Mac default.
- Use local Irodori-TTS-Server with `IRODORI_UV_EXTRA=cpu` by default.
- Keep Irodori-TTS-Server outside this repository, normally as `../Irodori-TTS-Server`.
- Keep all MacBook local services bound to `127.0.0.1` unless the user explicitly asks for LAN exposure.
- Start the Mac client through `scripts/mac/start-client-mac.sh` so it uses the Mac-local default URL and a separate localStorage key from the desktop PC profile.
- Expect Irodori's first speech request to be slow. The Mac conversation server script sets `GIC_REQUEST_TIMEOUT_SECONDS=600` because first model load and Hugging Face cache setup can take several minutes.

## First files to read

Before changing MacBook local setup instructions or diagnosing a MacBook local issue, read:

1. `docs/macbook-local-setup.md`
2. `docs/scripts-and-startup.md`
3. `docs/verification.md`

Use those docs as the source of truth for current command names and known timings.

## Command boundary

MacBook local commands:

```bash
ollama pull gemma4:e4b-mlx
./scripts/mac/setup-irodori-mac.sh
./scripts/mac/start-inference-stack-mac.sh
./scripts/mac/start-irodori-mac.sh
./scripts/mac/start-conversation-server-mac.sh
./scripts/mac/start-client-mac.sh
./scripts/mac/check-mac-stack.sh
```

Do not use WSL scripts for MacBook local work. Do not use PowerShell commands for MacBook local work.

## Setup workflow

1. Confirm local tools are present:

```bash
command -v ollama
command -v uv
command -v pnpm
```

2. Confirm or install the Mac model:

```bash
ollama list
ollama pull gemma4:e4b-mlx
```

3. Set up Irodori-TTS-Server:

```bash
./scripts/mac/setup-irodori-mac.sh
```

4. Start services in this order:

```text
Mac Ollama + Irodori: ./scripts/mac/start-inference-stack-mac.sh
Mac conversation server: ./scripts/mac/start-conversation-server-mac.sh
Mac client: ./scripts/mac/start-client-mac.sh
```

5. Validate:

```bash
./scripts/mac/check-mac-stack.sh
```

## Stopping services

Stop foreground sessions with `Ctrl-C`.

If a script started background processes, check `.logs/` for pid files and logs before killing anything:

```bash
ls .logs/
cat .logs/irodori-mac.pid
cat .logs/ollama-mac.pid
```

Be careful with Ollama. If Ollama was already running before this project started, do not stop it unless the user explicitly asks.

## Troubleshooting priorities

- If `/api/health` shows `model` other than `gemma4:e4b-mlx`, confirm the server was started with `scripts/mac/start-conversation-server-mac.sh`.
- If the client shows `http://192.168.3.2:8000`, confirm it was started with `scripts/mac/start-client-mac.sh`; that script uses `gemma4-irodori-chat.base-url.mac-local`.
- If Irodori health is OK but text turns timeout, suspect first model load. Keep `GIC_REQUEST_TIMEOUT_SECONDS=600` and check Irodori logs.
- If `/api/speakers` returns only `none`, no reference voice is registered in `../Irodori-TTS-Server/voices/`.
- If Irodori exits after background startup, retry with foreground `./scripts/mac/start-irodori-mac.sh` and inspect the visible logs.

## Validation before finishing

Run the smallest relevant checks:

```bash
bash -n scripts/mac/*.sh
cd server && UV_CACHE_DIR=/private/tmp/uv-cache-gemma4-irodori uv run pytest
cd client && pnpm check
cd client && pnpm build
```

Run `cd client && pnpm test:e2e` when client behavior or displayed URL/model/settings changed.

For real MacBook local services, confirm:

```bash
./scripts/mac/check-mac-stack.sh
```
