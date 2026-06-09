# Gemma4 Irodori Chat

日本語音声会話AIアプリのMVP実装。

現時点の縦切りは、Svelte WebクライアントからFastAPI会話サーバーへテキスト入力を送り、LLM応答、読み上げ音声生成、履歴表示、音声再生までを通す構成です。

## Structure

```text
/
├── server/   # FastAPI conversation server
├── client/   # Svelte + TypeScript + Vite web client
├── docs/     # design notes and ADRs
└── CONTEXT.md
```

## Server

開発用モックで起動:

```sh
cd server
uv sync
GIC_MOCK_SERVICES=1 uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Ollama / irodori-TTS を使う場合:

```sh
cd server
GIC_OLLAMA_BASE_URL=http://127.0.0.1:11434 \
GIC_OLLAMA_MODEL=gemma4:12b \
GIC_TTS_BASE_URL=http://127.0.0.1:8088 \
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

テスト:

```sh
cd server
uv run pytest
```

## Irodori-TTS-Server

公式のOpenAI互換サーバーを別ディレクトリに用意します。

### Windows AMD / WSL

Windows AMD推論PCでは、WSL2 UbuntuでこのプロジェクトとIrodori-TTS-Serverを動かす構成を標準手順にします。OllamaはWindowsネイティブで起動し、WSL側の会話サーバーから接続します。

詳しい手順は [WSL AMD Setup](./docs/wsl-amd-setup.md) を参照してください。

この手順では、WSL2 Ubuntuがインストール済みであることを前提にします。WSL自体のインストールはプロジェクトのセットアップ範囲外です。

### Windows Native Fallback

Windowsネイティブのみで進める手順は標準ではありません。必要な場合だけ、Irodori-TTS-ServerをCPU backendで動かすフォールバックとして使います。

詳しい手順は [Windows AMD Setup](./docs/windows-amd-setup.md) を参照してください。

```powershell
.\scripts\windows\setup-irodori-windows.ps1
```

OllamaとIrodori-TTS-Serverを起動:

```powershell
.\scripts\windows\start-inference-stack-windows.ps1
```

別ターミナルで会話サーバーを起動:

```powershell
.\scripts\windows\start-conversation-server-real-windows.ps1
```

疎通確認:

```powershell
.\scripts\windows\check-real-stack-windows.ps1
```

### Linux AMD

Linux AMD / ROCmでは以下を使います。

```sh
./scripts/setup-irodori-amd.sh
```

起動:

```sh
cd ../Irodori-TTS-Server
uv run --extra rocm python -m irodori_openai_tts --host 0.0.0.0 --port 8088
```

確認:

```sh
curl http://127.0.0.1:8088/health
curl http://127.0.0.1:8088/v1/audio/voices
```

参照音声を使う場合は `../Irodori-TTS-Server/voices/` に音声ファイルを置きます。ファイル名のstemが `voice` IDになります。

## Linux Inference Stack

OllamaとIrodori-TTS-Serverがセットアップ済みなら、以下の1コマンドで両方を起動できます。

```sh
./scripts/start-inference-stack.sh
```

このスクリプトはデフォルトでIrodori-TTS-Serverを `uv run --extra rocm` で起動します。

`Irodori-TTS-Server` の場所が既定の `../Irodori-TTS-Server` と違う場合:

```sh
IRODORI_TTS_SERVER_DIR=/path/to/Irodori-TTS-Server ./scripts/start-inference-stack.sh
```

このスクリプトは初回インストールを完全自動化しません。ROCmドライバ、PyTorch backend、GPU認識は環境差が大きいため、Irodori-TTS-Serverの初期セットアップだけは明示的に行ってください。

実サービスに接続して会話サーバーを起動:

```sh
./scripts/start-conversation-server-real.sh
```

モデル名が違う場合:

```sh
GIC_OLLAMA_MODEL=gemma4:12b ./scripts/start-conversation-server-real.sh
```

疎通確認:

```sh
./scripts/check-real-stack.sh
```

## Client

```sh
cd client
pnpm install
pnpm dev
```

ブラウザで `http://127.0.0.1:5173/` を開きます。

検証:

```sh
cd client
pnpm check
pnpm build
pnpm test:e2e
```

## Documents

- [MVP Plan](./docs/mvp-plan.md)
- [Design Notes](./docs/design.md)
- [Verification Guide](./docs/verification.md)
- [Handoff](./docs/handoff.md)
- [WSL AMD Setup](./docs/wsl-amd-setup.md)
- [Windows AMD Setup](./docs/windows-amd-setup.md)
- [Context Glossary](./CONTEXT.md)

## Agent Skills

- [Gemma4 Irodori Setup](./.agents/skills/gemma4-irodori-setup/SKILL.md): Windows AMD / WSLセットアップ支援用のCodexスキル。
