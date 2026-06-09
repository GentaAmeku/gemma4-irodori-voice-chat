# WSL AMD Setup

Windows AMD推論PCでは、この手順を推奨します。

## 方針

- このリポジトリ、会話サーバー、Irodori-TTS-ServerはWSL2 Ubuntu側に置く。
- OllamaはまずWindowsネイティブで起動する。
- Irodori-TTS-ServerはWSL2 Ubuntu上で `rocm` extraを使う。
- クライアントはWindowsブラウザから `http://localhost:5173` にアクセスする。

この構成にする理由は、Irodori-TTS-Serverの `rocm` extraがLinux向けで、WindowsネイティブよりWSL2 Ubuntuの方がROCm/PyTorchの前提に近いためです。

## 1. Windows側

管理者PowerShellでWSLを入れます。

```powershell
wsl --install -d Ubuntu-24.04
wsl --update
```

OllamaをWindowsに入れます。

```powershell
winget install Ollama.Ollama
```

新しいPowerShellを開き直して、Ollamaモデルを入れます。

```powershell
ollama pull gemma4:e4b-mlx
ollama list
```

## 2. WSL側の基本ツール

Ubuntuを開きます。

```bash
sudo apt update
sudo apt install -y git curl build-essential
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
corepack enable
corepack prepare pnpm@11.1.2 --activate
```

新しいシェルを開き直し、確認します。

```bash
git --version
uv --version
node --version
pnpm --version
```

## 3. リポジトリclone

WSLのLinuxファイルシステム側にcloneします。`/mnt/c/...` 配下は避けます。

```bash
mkdir -p ~/ghq
cd ~/ghq
git clone https://github.com/GentaAmeku/gemma4-irodori-voice-chat.git
cd gemma4-irodori-voice-chat
```

## 4. Irodori-TTS-Server

```bash
./scripts/wsl/setup-irodori-wsl-amd.sh
```

このスクリプトは既定で `../Irodori-TTS-Server` にcloneし、`uv sync --extra rocm` を実行します。

別ターミナルで起動します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/start-irodori-wsl-amd.sh
```

## 5. 会話サーバー

別ターミナルで起動します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/start-conversation-server-wsl.sh
```

Ollamaモデルを変える場合:

```bash
GIC_OLLAMA_MODEL=gemma4:12b ./scripts/wsl/start-conversation-server-wsl.sh
```

## 6. 疎通確認

別ターミナルで実行します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/check-wsl-stack.sh
```

## 7. クライアント

```bash
cd ~/ghq/gemma4-irodori-voice-chat/client
pnpm install
pnpm dev
```

Windows側のブラウザで開きます。

```text
http://localhost:5173
```

画面の接続先は通常これでよいです。

```text
http://127.0.0.1:8000
```

WSL localhost forwardingが効かない場合は、WSL側でIPを確認して、そのIPを使います。

```bash
hostname -I
```

例:

```text
http://172.20.10.2:8000
```

## 注意

- ROCm on WSLの対応GPU、Windows driver、Ubuntu versionはAMDの互換表に依存します。
- `uv sync --extra rocm` が失敗する場合は、ROCm/WSL側の前提が未整備です。
- まずWindowsネイティブOllama + WSL Irodori + WSL会話サーバーで成功させ、その後に構成を単純化するか判断します。
