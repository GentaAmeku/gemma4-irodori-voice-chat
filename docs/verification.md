# Verification Guide

このドキュメントは、MacBookから同じLAN内のdesktop PC上の会話サーバーへ接続し、テキスト会話と読み上げまで確認するための手順です。

## 前提構成

```text
MacBook browser / client
  -> http://<desktop-pc-lan-ip>:8000
  -> desktop PC WSL conversation server
  -> Windows Ollama
  -> WSL irodori-TTS-Server
```

MacBookからOllamaやirodori-TTSへ直接接続しません。MacBookが接続する先は会話サーバーだけです。

## 1. desktop PC側の起動

Windows PowerShellでOllamaが動いていることを確認します。

```powershell
ollama list
```

WSL Ubuntuターミナル1でirodori-TTS-Serverを起動します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/start-irodori-wsl-amd.sh
```

WSL Ubuntuターミナル2で会話サーバーを起動します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/start-conversation-server-wsl.sh
```

desktop PC上で疎通確認します。

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/check-wsl-stack.sh
```

## 2. LAN公開確認

desktop PCのLAN IPをWindows PowerShellで確認します。

```powershell
ipconfig
```

`IPv4 アドレス` を使います。`デフォルト ゲートウェイ` はルーターなので使いません。

desktop PC自身から、LAN IP宛てでも会話サーバーへ届くことを確認します。

```powershell
curl.exe http://<desktop-pc-lan-ip>:8000/api/health
```

MacBookから会話サーバーのhealthを確認します。

```bash
curl http://<desktop-pc-lan-ip>:8000/api/health
```

期待値:

- JSONが返る
- `server_ok` が `true`
- `ready` が `true`
- `model` が `gemma4:12b`
- `ollama.ok` が `true`
- `tts.ok` が `true`

WSL2 NAT構成でMacBookから届かない場合は、Windows側でportproxyまたはWSL mirrored networkingを設定します。手順は [WSL AMD Setup](./wsl-amd-setup.md) の「MacBookからdesktop PCへ接続する」を参照してください。

## 3. MacBook側クライアント起動

MacBook側でこのリポジトリを開きます。

```bash
cd ~/ghq/gemma4-irodori-voice-chat/client
pnpm install
pnpm dev
```

MacBookブラウザで開きます。

```text
http://127.0.0.1:5173
```

画面の接続先にdesktop PCの会話サーバーURLを入力します。

```text
http://<desktop-pc-lan-ip>:8000
```

## 4. UIで確認する項目

接続後、左側の接続状態パネルを確認します。

- 会話サーバー: 接続済み
- Ollama: 接続済み
- irodori-TTS: 接続済み

テキスト入力で短い発話を送ります。

```text
こんにちは。短く返事してください。
```

期待値:

- ユーザー発話が送信直後に履歴へ表示される
- AI応答が返るまで `リノンが返答生成中…` が表示される
- 生成が長い場合は `リノンが読み上げ準備中…` へ切り替わる
- AI応答が履歴に表示される
- 最後の読み上げプレイヤーが表示される
- 履歴内のAI応答にも音声プレイヤーが表示される
- 自動再生がブラウザに止められた場合でも、手動再生できる

返答待ち中に送信ボタンがキャンセルボタンへ切り替わることも確認します。

期待値:

- キャンセルすると、画面上のpending発話が消える
- `キャンセルしました` が表示される
- テキスト入力欄が再び使える
- 遅れて返った応答は画面の履歴へ反映されない

注意: 現在のテキスト会話は同期RESTです。キャンセルはクライアント側のrequest中断と画面上の破棄であり、会話サーバー側のLLM/TTS処理停止までは保証しません。キャンセル直後に再送すると、サーバー側の処理が終わるまでbusy応答になる場合があります。

## 5. 設定操作の確認

Optionsを開きます。

確認項目:

- キャラクター名を編集できる
- キャラクター設定を編集できる
- 読み上げ設定を編集できる
- 話者を選択できる
- 保存すると履歴がクリアされる
- 履歴クリアボタンで履歴がクリアされる
- キャラクター画像をアップロードできる
- 参照音声を登録済みの場合、話者リストに `none` 以外の話者IDが表示される
- 話す速さを変更して保存できる

参照音声の登録手順は [Reference Voice Setup](./reference-voice-setup.md) を参照してください。
MacBookからdesktop PC / WSL構成へ登録する場合は、会話サーバー経由の登録を使います。

```bash
SERVER_BASE_URL=http://<desktop-pc-lan-ip>:8000 \
  ./scripts/register-conversation-voice.sh rinon /path/to/rinon.wav
```

## 6. 失敗時の切り分け

### MacBookからhealthが返らない

確認:

- desktop PCのLAN IPが正しいか
- 会話サーバーが `--host 0.0.0.0 --port 8000` で起動しているか
- Windows FirewallがPrivate networkでport 8000を許可しているか
- WSL2 NATの場合、portproxyが設定されているか
- Windowsのネットワークプロファイルが `Private` になっているか
- `netsh interface portproxy show v4tov4` の転送先がWSLのIPv4になっているか

desktop PCのPowerShellで `127.0.0.1:8000` は成功するのに `<desktop-pc-lan-ip>:8000` が失敗する場合は、WSLではなくWindows側のLAN公開設定を確認します。

```powershell
curl.exe http://127.0.0.1:8000/api/health
curl.exe http://<desktop-pc-lan-ip>:8000/api/health
netsh interface portproxy show v4tov4
Get-Service iphlpsvc
Get-NetConnectionProfile
```

### UIでOllamaだけ要確認になる

desktop PCのWSL Ubuntuで確認:

```bash
curl http://127.0.0.1:11434/api/tags
```

失敗する場合:

```bash
WINDOWS_HOST="$(ip route show default | awk '{print $3; exit}')"
curl "http://${WINDOWS_HOST}:11434/api/tags"
```

### UIでirodori-TTSだけ要確認になる

desktop PCのWSL Ubuntuで確認:

```bash
curl http://127.0.0.1:8088/health
curl http://127.0.0.1:8088/v1/audio/voices
```

### テキスト送信後に音声だけ出ない

確認:

- 応答テキストが表示されているか
- 最後の読み上げプレイヤーに音声URLが入っているか
- ブラウザの自動再生制限で止まっていないか
- irodori-TTSの起動ログにエラーが出ていないか

## 7. 自動テスト

MacBookまたは開発機で実行します。

```bash
cd server
uv run pytest
```

```bash
cd client
pnpm check
pnpm build
pnpm test:e2e
```

`pnpm test:e2e` はモックサービスで縦切りUIを確認します。実Ollama / 実irodori-TTSの検証は `./scripts/wsl/check-wsl-stack.sh` と手動UI確認で行います。

## 8. MacBookローカル構成の確認

MacBookだけでOllama、Irodori-TTS-Server、会話サーバー、Webクライアントを動かす場合は [MacBook Local Setup](./macbook-local-setup.md) を使います。

起動順:

```bash
./scripts/mac/start-inference-stack-mac.sh
./scripts/mac/start-conversation-server-mac.sh
./scripts/mac/start-client-mac.sh
```

確認:

```bash
./scripts/mac/check-mac-stack.sh
```

期待値:

- `/api/health` の `model` が `gemma4:e4b-mlx`
- `ollama.ok` が `true`
- `tts.ok` が `true`
- UIの接続先が `http://127.0.0.1:8000`
- テキスト送信後に応答と音声プレイヤーが表示される
