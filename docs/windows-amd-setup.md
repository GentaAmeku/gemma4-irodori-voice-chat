# Windows AMD Setup

この手順は、AMD GPU搭載のWindows推論PCでOllamaとIrodori-TTS-Serverを動かし、このアプリの会話サーバーへ接続するためのものです。

## 前提

- Windows 11を推奨。
- OllamaはWindowsネイティブでAMD Radeon GPU対応。
- Irodori-TTS-Serverの `rocm` extraは公式README上ではLinux向け。
- WindowsではまずIrodoriをCPU backendで起動し、実接続を成立させる。
- IrodoriのWindows AMD GPU化は、PyTorch ROCm on Windowsの対応GPU/OS/Python条件を満たすか確認してから別途検証する。

## 1. 必要ツール

PowerShellで確認します。

```powershell
git --version
uv --version
ollama --version
```

足りないものを入れます。

```powershell
winget install Git.Git
winget install astral-sh.uv
winget install Ollama.Ollama
```

Ollamaを入れた後、新しいPowerShellを開き直します。

## 2. Ollamaモデル

```powershell
ollama pull gemma4:12b
ollama list
```

別モデルを使う場合は、後で `-OllamaModel` にその名前を指定します。

## 3. Irodori-TTS-Server

```powershell
.\scripts\windows\setup-irodori-windows.ps1
```

このスクリプトは既定で `..\Irodori-TTS-Server` にcloneし、`uv sync --extra cpu` を実行します。

## 4. 推論スタック起動

```powershell
.\scripts\windows\start-inference-stack-windows.ps1
```

これで以下を起動します。

- Ollama: `http://127.0.0.1:11434`
- Irodori-TTS-Server: `http://127.0.0.1:8088`

## 5. 会話サーバー起動

別PowerShellで実行します。

```powershell
.\scripts\windows\start-conversation-server-real-windows.ps1
```

モデルを変える場合:

```powershell
.\scripts\windows\start-conversation-server-real-windows.ps1 -OllamaModel gemma4:e4b-mlx
```

## 6. 疎通確認

さらに別PowerShellで実行します。

```powershell
.\scripts\windows\check-real-stack-windows.ps1
```

成功すると、Ollama、Irodori-TTS-Server、会話サーバー、テキスト会話ターンが順に確認されます。

## 7. クライアント接続

このリポジトリの `client` を起動します。

```powershell
cd client
pnpm install
pnpm dev
```

画面の接続先に、推論PCのLAN内URLを入れます。

```text
http://<推論PCのLAN内IP>:8000
```

## 注意

WindowsでIrodoriをCPU backendにしているため、TTS生成は遅い可能性があります。まず動作確認を優先し、その後にIrodoriのGPU化を別検証してください。
