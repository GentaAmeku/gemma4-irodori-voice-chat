# WSL AMD Setup

## 方針

Windows AMD推論PCでは、この手順を推奨します。

- このリポジトリ、会話サーバー、Irodori-TTS-ServerはWSL2 Ubuntu側に置く。
- OllamaはまずWindowsネイティブで起動する。
- Irodori-TTS-ServerはWSL2 Ubuntu上で `rocm` extraを使う。
- クライアントはWindowsブラウザから `http://localhost:5173` にアクセスする。

この構成にする理由は、Irodori-TTS-Serverの `rocm` extraがLinux向けで、WindowsネイティブよりWSL2 Ubuntuの方がROCm/PyTorchの前提に近いためです。ただし、ROCm on WSLはGPU、Windowsドライバ、WSL、Ubuntu versionの互換条件に強く依存します。Irodoriのセットアップ前にAMD公式の互換表とWSL手順を確認してください。

## 前提

この手順では、Windows PCにWSL2 Ubuntuがインストール済みであることを前提にします。WSL自体のインストールはプロジェクトのセットアップ範囲外です。

推奨:

- Windows 11
- WSL2
- Ubuntu 24.04 または Ubuntu 22.04
- Windows側にOllama
- WSL Ubuntu側にこのリポジトリ、会話サーバー、Irodori-TTS-Server

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

## 1. WSL状態確認

Windows PowerShellで確認します。

```powershell
wsl --list --verbose
```

Ubuntuが `VERSION 2` になっていることを確認します。もし `1` の場合だけ、PowerShellで変換します。

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
ollama pull gemma4:12b
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
sudo npm install -g pnpm@11.1.2
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

軽量モデルなどへ変える場合:

```bash
GIC_OLLAMA_MODEL=gemma4:e4b-mlx ./scripts/wsl/start-conversation-server-wsl.sh
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

## MacBookからdesktop PCへ接続する

MacBookから使う場合も、MacBookのクライアントがOllamaやirodori-TTSへ直接接続する構成にはしません。MacBookからはdesktop PC上の会話サーバーだけに接続します。

```text
MacBook client
  -> http://<desktop-pc-lan-ip>:8000
  -> desktop PC WSL conversation server
  -> Windows Ollama / WSL irodori-TTS
```

MacBook側でこのリポジトリのクライアントを起動する場合:

```bash
cd ~/ghq/gemma4-irodori-voice-chat/client
pnpm install
pnpm dev
```

MacBookブラウザで `http://127.0.0.1:5173` を開き、画面の接続先にdesktop PCの会話サーバーURLを指定します。

```text
http://<desktop-pc-lan-ip>:8000
```

desktop PCのLAN IPはWindows PowerShellで確認します。

```powershell
ipconfig
```

使うのは、MacBookと同じLANに出ているWindows本体のIPv4アドレスです。`デフォルト ゲートウェイ` はルーターなので使いません。

例:

```text
IPv4 アドレス       : 192.168.3.2  <- MacBookから指定する入口
デフォルト ゲートウェイ: 192.168.3.1  <- これは使わない
```

WSLや依存サービスのアドレスとは役割が違います。

```text
MacBook
  -> http://<desktop-pc-lan-ip>:8000  # Windows本体のLAN IP
  -> Windows portproxy
  -> http://<wsl-ip>:8000             # WSL内の会話サーバー
  -> http://<windows-host-ip>:11434    # WSLから見たWindows Ollama
  -> http://127.0.0.1:8088            # WSL内のirodori-TTS
```

WSL2の既定NAT構成では、LAN内の別端末からWSL上のサーバーへ直接届かないことがあります。その場合は、Windows 11 22H2以降ならWSL mirrored networkingを使うか、Windows側でportproxyを設定します。

portproxyを使う例:

```powershell
$LanIp = "192.168.3.2"
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

設定後に、desktop PCのPowerShellでLAN IP宛てに確認します。

```powershell
netsh interface portproxy show v4tov4
curl.exe http://192.168.3.2:8000/api/health
```

`portproxy show v4tov4` の転送先は、`172.x.x.x` のようなWSLのIPv4になっている必要があります。文字化けした値や空の値が出る場合は、`hostname -I` の結果からWSL IPv4を手で確認し、`$WslIp` に直接入れて作り直してください。

MacBookから疎通確認:

```bash
curl http://<desktop-pc-lan-ip>:8000/api/health
```

このAPIが返れば、MacBookのクライアント接続先にも同じURLを入れます。

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

### Windows PowerShellで `127.0.0.1:8000` は成功するが、LAN IPでは失敗する

Windows localhost forwardingは効いていますが、LAN向けの待ち受けまたは転送ができていません。Windows PowerShellで確認します。

```powershell
curl.exe http://127.0.0.1:8000/api/health
curl.exe http://<desktop-pc-lan-ip>:8000/api/health
netsh interface portproxy show v4tov4
Get-Service iphlpsvc
Get-NetConnectionProfile
```

確認ポイント:

- `curl.exe http://127.0.0.1:8000/api/health` が成功するなら、WSL内の会話サーバー自体は動いています。
- `curl.exe http://<desktop-pc-lan-ip>:8000/api/health` が失敗するなら、portproxyまたはWindows Firewallを見ます。
- `portproxy show v4tov4` の転送先は、WSLのIPv4になっている必要があります。
- `iphlpsvc` は `Running` である必要があります。
- `NetworkCategory` が `Public` の場合、`-Profile Private` のFirewallルールは効きません。信頼できる自宅LANなら、管理者PowerShellでPrivateに変更します。

```powershell
Set-NetConnectionProfile -InterfaceIndex <Get-NetConnectionProfileで見えたInterfaceIndex> -NetworkCategory Private
```

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
- `corepack enable` / `corepack prepare` はWindows/WSLのNode.js導入経路によって失敗することがあるため、この手順では使いません。
- まずWindowsネイティブOllama + WSL Irodori + WSL会話サーバーで成功させ、その後に構成を単純化するか判断します。

## 参考

- Microsoft WSL install: https://learn.microsoft.com/en-us/windows/wsl/install
- Microsoft WSL basic commands: https://learn.microsoft.com/en-us/windows/wsl/basic-commands
- Microsoft WSL networking: https://learn.microsoft.com/en-us/windows/wsl/networking
- Ollama Windows: https://docs.ollama.com/windows
- Ollama FAQ: https://docs.ollama.com/faq
- AMD ROCm compatibility matrices: https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibility.html
- AMD ROCm WSL guide: https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installrad/wsl/howto_wsl.html
