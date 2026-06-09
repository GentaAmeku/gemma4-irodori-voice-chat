# WSL AMD Setup

## 方針

Windows AMD推論PCでは、この手順を推奨します。

- このリポジトリ、会話サーバー、Irodori-TTS-ServerはWSL2 Ubuntu側に置く。
- OllamaはまずWindowsネイティブで起動する。
- Irodori-TTS-ServerはWSL2 Ubuntu上で `rocm` extraを使う。
- クライアントはWindowsブラウザから `http://localhost:5173` にアクセスする。

この構成にする理由は、Irodori-TTS-Serverの `rocm` extraがLinux向けで、WindowsネイティブよりWSL2 Ubuntuの方がROCm/PyTorchの前提に近いためです。ただし、ROCm on WSLはGPU、Windowsドライバ、WSL、Ubuntu versionの互換条件に強く依存します。Irodoriのセットアップ前にAMD公式の互換表とWSL手順を確認してください。

## 事前に知っておくこと

PowerShellで実行するコマンドと、WSL Ubuntuで実行するコマンドを混ぜないでください。

```text
Windows PowerShell:
  wsl, winget, ollama

WSL Ubuntu:
  sudo apt, uv, pnpm, ./scripts/wsl/*.sh
```

プロジェクトはWSLのLinuxファイルシステム側に置きます。`/mnt/c/Users/...` 配下で開発すると、ファイル監視や依存インストールが遅くなりやすいです。

```text
推奨:
  ~/ghq/gemma4-irodori-voice-chat

非推奨:
  /mnt/c/Users/<User>/...
```

## 1. Windows側でWSLを用意する

管理者PowerShellでWSLを入れます。

```powershell
wsl --install -d Ubuntu-24.04
wsl --update
```

PCを再起動し、Ubuntuを初回起動してLinuxユーザー名とパスワードを作成します。

WSLの状態確認:

```powershell
wsl --list --verbose
```

`Ubuntu-24.04` が `VERSION 2` になっていることを確認します。もし `1` の場合:

```powershell
wsl --set-version Ubuntu-24.04 2
```

WSLを完全停止したい時:

```powershell
wsl --shutdown
```

WSLに入る:

```powershell
wsl -d Ubuntu-24.04
```

## 2. AMD GPU / ROCm on WSLの前提確認

Windows側でAMD Software: Adrenalin Editionを最新のWSL対応版にします。対応GPUと必要なWindows driverはAMD公式の互換表で確認してください。

AMDの現行WSL手順では、ROCDXGを使う構成が案内されています。Irodoriの `uv sync --extra rocm` を実行する前に、AMD公式のWSL guideに従ってROCDXGのQuickstartまで完了させてください。

WSL Ubuntu側で最低限確認:

```bash
ls /dev/dxg
```

`/dev/dxg` が存在しない場合、WSLからWindows GPUへ到達できていません。先にWindows driver、WSL update、ROCDXG手順を見直します。

## 3. Windows側でOllamaを用意する

OllamaをWindowsに入れます。

```powershell
winget install Ollama.Ollama
```

新しいPowerShellを開き直して、Ollamaモデルを入れます。

```powershell
ollama pull gemma4:e4b-mlx
ollama list
```

Ollamaの疎通確認:

```powershell
curl http://127.0.0.1:11434/api/tags
```

WSL側からWindows上のOllamaへ接続する場合、環境によって接続先が変わります。WSLのmirrored networkingが有効なら `127.0.0.1:11434` で届くことがあります。通常のNAT構成ではWindowsホストIPを使います。

WSL Ubuntu側で確認:

```bash
curl http://127.0.0.1:11434/api/tags
```

失敗する場合:

```bash
WINDOWS_HOST="$(ip route show default | awk '{print $3; exit}')"
curl "http://${WINDOWS_HOST}:11434/api/tags"
```

この2つ目も失敗する場合は、Windows側のOllamaが外部インターフェイスで待ち受けていない可能性があります。MVPではLAN外公開はしない前提なので、必要な場合だけWindows側でユーザー環境変数 `OLLAMA_HOST=0.0.0.0:11434` を設定し、Ollamaのタスクトレイアプリを終了してからスタートメニューで起動し直してください。WindowsファイアウォールではLAN内だけ許可してください。

## 4. WSL側の基本ツール

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

## 5. WSL側でリポジトリをcloneする

WSLのLinuxファイルシステム側にcloneします。`/mnt/c/...` 配下は避けます。

```bash
mkdir -p ~/ghq
cd ~/ghq
git clone https://github.com/GentaAmeku/gemma4-irodori-voice-chat.git
cd gemma4-irodori-voice-chat
```

VS Codeで開く場合は、Windows側のVS CodeにWSL拡張を入れたうえで、WSL Ubuntu内のリポジトリディレクトリから実行します。

```bash
code .
```

これでVS Codeが「WSL: Ubuntu-24.04」として開きます。Windows側の通常フォルダとして開かないでください。

## 6. Irodori-TTS-Server

```bash
./scripts/wsl/setup-irodori-wsl-amd.sh
```

このスクリプトは既定で `../Irodori-TTS-Server` にcloneし、`uv sync --extra rocm` を実行します。

別ターミナルで起動します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/start-irodori-wsl-amd.sh
```

起動確認:

```bash
curl http://127.0.0.1:8088/health
curl http://127.0.0.1:8088/v1/audio/voices
```

## 7. 会話サーバー

別ターミナルで起動します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/start-conversation-server-wsl.sh
```

Ollamaモデルを変える場合:

```bash
GIC_OLLAMA_MODEL=gemma4:12b ./scripts/wsl/start-conversation-server-wsl.sh
```

起動確認:

```bash
curl http://127.0.0.1:8000/api/health
```

## 8. 疎通確認

別ターミナルで実行します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/check-wsl-stack.sh
```

このチェックは以下を順番に確認します。

- Windows側Ollama API
- WSL側Irodori-TTS-Server
- WSL側会話サーバー
- テキスト会話ターン

## 9. クライアント

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

## 日常の起動順

2回目以降は、基本的にこの順番です。

Windows PowerShell:

```powershell
ollama list
```

WSL Ubuntu ターミナル 1:

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/start-irodori-wsl-amd.sh
```

WSL Ubuntu ターミナル 2:

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/start-conversation-server-wsl.sh
```

WSL Ubuntu ターミナル 3:

```bash
cd ~/ghq/gemma4-irodori-voice-chat/client
pnpm dev
```

Windowsブラウザ:

```text
http://localhost:5173
```

## よく使うWSLコマンド

PowerShell:

```powershell
wsl --list --verbose
wsl --shutdown
wsl --update
wsl -d Ubuntu-24.04
```

WSL Ubuntu:

```bash
pwd
ls
cd ~/ghq/gemma4-irodori-voice-chat
hostname -I
```

Windows ExplorerでWSLのファイルを見る場合:

```powershell
explorer.exe \\wsl$\Ubuntu-24.04\home
```

見るだけに留め、依存インストールやGit操作はWSL Ubuntu側で行ってください。

## トラブルシュート

### Windowsブラウザから `localhost:5173` が開けない

まずWSL側でViteが起動しているか確認します。

```bash
curl http://127.0.0.1:5173
```

Windows側のlocalhost forwardingが効かない場合、WSLのIPを使います。

```bash
hostname -I
```

Windowsブラウザで:

```text
http://<WSLのIP>:5173
```

### 会話サーバーがOllamaに接続できない

WSL Ubuntu側からWindows Ollamaへアクセスできるか確認します。

```bash
curl http://127.0.0.1:11434/api/tags
```

失敗する場合、WindowsホストIPで確認します。

```bash
WINDOWS_HOST="$(ip route show default | awk '{print $3; exit}')"
curl "http://${WINDOWS_HOST}:11434/api/tags"
```

それでも失敗する場合、Windows PowerShellでOllamaが動いているか確認します。

```powershell
ollama list
```

必要な場合だけ、Windows側でOllamaのユーザー環境変数 `OLLAMA_HOST=0.0.0.0:11434` を設定し、Ollamaを再起動します。この設定はLAN内の他端末からも到達可能になりうるため、WindowsファイアウォールでLAN限定にしてください。

### `uv sync --extra rocm` が失敗する

ROCm on WSLの前提が未整備です。AMD GPU、Windows driver、WSL kernel、Ubuntu versionが互換表に入っているか確認してください。

まずはエラーログを保存します。

```bash
./scripts/wsl/setup-irodori-wsl-amd.sh 2>&1 | tee setup-irodori.log
```

### WSLを再起動したい

PowerShell:

```powershell
wsl --shutdown
wsl -d Ubuntu-24.04
```

## 注意

- ROCm on WSLの対応GPU、Windows driver、Ubuntu versionはAMDの互換表に依存します。
- `uv sync --extra rocm` が失敗する場合は、ROCm/WSL側の前提が未整備です。
- まずWindowsネイティブOllama + WSL Irodori + WSL会話サーバーで成功させ、その後に構成を単純化するか判断します。

## 参考

- Microsoft WSL install: https://learn.microsoft.com/en-us/windows/wsl/install
- Microsoft WSL basic commands: https://learn.microsoft.com/en-us/windows/wsl/basic-commands
- Microsoft WSL networking: https://learn.microsoft.com/en-us/windows/wsl/networking
- Ollama Windows: https://docs.ollama.com/windows
- Ollama FAQ: https://docs.ollama.com/faq
- AMD ROCm compatibility matrices: https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibility.html
- AMD ROCm WSL guide: https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installrad/wsl/howto_wsl.html
