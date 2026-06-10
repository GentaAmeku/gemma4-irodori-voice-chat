# Handoff

最終更新: 2026-06-10

## 現在のゴール

Tauri化の前に、Svelte WebクライアントとFastAPI会話サーバーで、日本語テキスト会話からLLM応答、irodori-TTS読み上げ、音声再生までをLAN内で安定して動かす。

## 現在の標準構成

```text
MacBook client
  -> desktop PC WSL conversation server
  -> Windows Ollama gemma4:12b
  -> WSL irodori-TTS-Server
```

重要:

- MacBookはOllamaやirodori-TTSへ直接接続しない。
- MacBookが接続するのは会話サーバーだけ。
- Windows AMD環境ではWSL2 Ubuntuを標準手順にする。
- Windows native Irodoriはフォールバック扱い。
- WSL自体はインストール済み前提。
- `corepack enable` / `corepack prepare` は使わず、WSLでは `sudo npm install -g pnpm@11.1.2` を使う。

## MacBookローカル開発構成

Windows AMD / WSL構成とは別に、開発中のMacBookだけでも動かせる構成を追加する。

```text
MacBook client
  -> MacBook conversation server
  -> MacBook Ollama gemma4:e4b-mlx
  -> MacBook Irodori-TTS-Server
```

重要:

- MacBookローカルではOllamaモデルを `gemma4:e4b-mlx` にする。
- MacBookローカルではIrodori-TTS-Serverを既定で `cpu` extra起動にする。
- MacBookローカルでは会話サーバーを `127.0.0.1:8000` で起動し、LAN公開しない。
- Windows推論PC接続用のクライアント保存値とは別のlocalStorageキーを使う。

## リポジトリ

- GitHub: https://github.com/GentaAmeku/gemma4-irodori-voice-chat
- default branch: `main`

最新コミットは `git log --oneline -5` で確認する。

## 実装済み

### Server

- FastAPI会話サーバー
- REST API:
  - `GET /api/health`
  - `GET /api/settings`
  - `PUT /api/settings`
  - `GET /api/speakers`
  - `GET /api/history`
  - `DELETE /api/history`
  - `POST /api/turns/text`
  - `GET /api/character-image`
  - `POST /api/character-image`
- Ollama adapter
- irodori-TTS adapter
- 話す速さ `speech_speed` の設定保存とIrodori speech `speed` への橋渡し
- busy制御
- 設定保存時の履歴クリア
- キャラクター画像アップロード
- モックサービス

### Client

- Svelte + TypeScript + Vite
- 接続先URLのUI編集とlocalStorage保存
- health表示
- 会話サーバー / Ollama / irodori-TTS の状態パネル
- テキスト会話
- 送信直後のユーザー発話表示
- 応答待ち表示（`リノンが返答生成中…` / `リノンが読み上げ準備中…`）
- 返答待ち中のキャンセル
- キャンセル済みturnの画面上破棄と遅延応答の無視
- 応答履歴
- 最後の読み上げプレイヤー
- 自動再生失敗時の手動再生導線
- 設定パネル
- 話者選択と話す速さの保存
- 設定パネルのフォーム説明 `aria-describedby` 紐付け
- 設定保存 / 接続確認 / 画像アップロード / 履歴クリア中の二重送信防止
- 会話サーバー未接続 / Ollama不可 / irodori-TTS不可 / TTS timeout / 自動再生失敗の原因別エラー表示
- 長時間生成向けの待機表示（返答生成中 -> 読み上げ準備中）
- 履歴クリア
- キャラクター画像アップロード

### Scripts

WSL標準:

- `scripts/wsl/setup-irodori-wsl-amd.sh`
- `scripts/wsl/start-irodori-wsl-amd.sh`
- `scripts/wsl/start-conversation-server-wsl.sh`
- `scripts/wsl/check-wsl-stack.sh`
- `scripts/register-irodori-voice.sh`

MacBookローカル:

- `scripts/mac/setup-irodori-mac.sh`
- `scripts/mac/start-inference-stack-mac.sh`
- `scripts/mac/start-irodori-mac.sh`
- `scripts/mac/start-conversation-server-mac.sh`
- `scripts/mac/start-client-mac.sh`
- `scripts/mac/check-mac-stack.sh`

Windows native fallback:

- `scripts/windows/*.ps1`

Linux AMD:

- `scripts/setup-irodori-amd.sh`
- `scripts/start-inference-stack.sh`
- `scripts/start-conversation-server-real.sh`
- `scripts/check-real-stack.sh`

## 重要ドキュメント

- [Verification Guide](./verification.md)
- [Reference Voice Setup](./reference-voice-setup.md)
- [MacBook Local Setup](./macbook-local-setup.md)
- [UI Implementation Plan](./ui-implementation-plan.md)
- [WSL AMD Setup](./wsl-amd-setup.md)
- [MVP Plan](./mvp-plan.md)
- [Design Notes](./design.md)
- [Context Glossary](../CONTEXT.md)
- [Gemma4 Irodori Setup Skill](../.agents/skills/gemma4-irodori-setup/SKILL.md)
- [Gemma4 MacBook Local Setup Skill](../.agents/skills/gemma4-macbook-local-setup/SKILL.md)
- [Gemma4 Windows AMD Setup Skill](../.agents/skills/gemma4-windows-amd-setup/SKILL.md)

## 動作確認

基本は [Verification Guide](./verification.md) を使う。

ローカル自動チェック:

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

実サービス確認:

```bash
cd ~/ghq/gemma4-irodori-voice-chat
./scripts/wsl/check-wsl-stack.sh
```

MacBookローカル実サービス確認:

```bash
./scripts/mac/check-mac-stack.sh
```

## 直近の検証状況

直近の確認では以下が成功済み。

- MacBookから `http://192.168.3.2:8000/api/health`: success
- MacBookから実テキスト会話ターン: success
- 実irodori音声WAV取得: success
- MacBook Web UI状態表示: 会話サーバー / Ollama / irodori-TTS が接続済み
- `uv run pytest`: 4 passed
- `pnpm check`: 0 errors
- `pnpm build`: success
- `pnpm test:e2e`: 3 passed
- `bash -n scripts/wsl/*.sh`: success
- MacBookローカル `ollama list`: `gemma4:e4b-mlx` installed
- MacBookローカル `./scripts/mac/setup-irodori-mac.sh`: success
- MacBookローカル `./scripts/mac/check-mac-stack.sh`: success
- MacBookローカル Web UI状態表示: 会話サーバー / Ollama / irodori-TTS が接続済み
- MacBookローカル初回Irodori音声生成: モデルロード込みで約127秒。以後の実測は約46秒。
- MacBookローカル自動チェック: `uv run pytest` 4 passed / `pnpm check` 0 errors / `pnpm build` success / `pnpm test:e2e` 3 passed / `bash -n scripts/mac/*.sh scripts/wsl/*.sh scripts/*.sh` success
- desktop PC側WSLリポジトリへの最新修正反映と会話サーバー再起動: done
- desktop PC / WSL実機UIで返答中表示と新しい人格プロンプトを再確認: done
- UI Implementation Plan Phase 1相当のクライアント仕上げ: done
- `pnpm -C client format`: success
- `pnpm -C client check`: 0 errors
- `pnpm -C client build`: success
- `pnpm -C client test:e2e`: 5 passed
- `UV_CACHE_DIR=/private/tmp/uv-cache-gemma4-irodori uv run pytest`: 4 passed
- Browser desktop/mobile layout確認: 横スクロールなし、ヘッダー / スレッド / 入力欄の重なりなし、mobile設定パネルがviewport内に表示されることを確認
- Browser screenshot取得: Browser側の `Page.captureScreenshot` timeoutで未取得。DOM / viewport寸法確認は完了
- UI Implementation Plan Phase 2の実装・手順整備: done
- Irodori-TTS-Serverの実装確認: `/v1/audio/voices` はAPI uploadと `voices/` スキャンに対応、`/v1/audio/speech` は `speed` に対応
- `scripts/register-irodori-voice.sh` 追加
- `speech_speed` を会話サーバー設定として保存し、Irodori speech requestへ `speed` として送信
- `UV_CACHE_DIR=/private/tmp/uv-cache-gemma4-irodori uv run pytest`: 6 passed
- `pnpm -C client format`: success
- `pnpm -C client check`: 0 errors
- `pnpm -C client build`: success
- `pnpm -C client test:e2e`: 5 passed
- `bash -n scripts/register-irodori-voice.sh scripts/mac/*.sh scripts/wsl/*.sh scripts/*.sh`: success
- 参照音声ファイル候補: このリポジトリ近辺では未検出。実機で `none` 以外の話者確認は参照音声ファイル用意後に実施
- desktop PC実サービス確認: `curl http://192.168.3.2:8000/api/health` は `ready: true` / `gemma4:12b` / `mock_services: false`
- desktop PC実サービス確認: `/api/speakers` は `none` のみ
- desktop PC実サービス確認: `/api/settings` に `speech_speed` がまだ無い。会話サーバー再起動後も同じため、desktop PC側会話サーバーはPhase 2のサーバー変更未反映
- desktop PC実サービス確認: `POST /api/turns/text` は成功し、WAV URL `/media/audio/dcc8d7f2cd31404bbcdb52cf62890517.wav` が返った
- desktop PC実サービス確認: 上記WAVは `HTTP 200` / `content-type: audio/x-wav` / `content-length: 341804` でMacBookから取得可能
- desktop PC実サービス確認: MacBook上の新クライアントを `http://192.168.3.2:8000` へ接続し、設定パネルが `speech_speed` 欠落時も `1.00×` として表示されることを確認
- desktop PC再起動後の再確認: `curl http://192.168.3.2:8000/api/health` は `ready: true` / `gemma4:12b` / `mock_services: false`
- desktop PC再起動後の再確認: `/api/settings` は引き続き `speech_speed` なし
- desktop PC再起動後の再確認: `/api/speakers` は引き続き `none` のみ
- desktop PC再起動後の再確認: `POST /api/turns/text` は成功し、返答 `了解、しっかり届いているよ。` とWAV URL `/media/audio/81bc04ab0cdf4a39900bcc3829896199.wav` が返った
- desktop PC再起動後の再確認: 上記WAVは `HTTP 200` / `content-type: audio/x-wav` / `content-length: 253484` でMacBookから取得可能
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `/api/settings` に `speech_speed: 1.0` が出ることを確認
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `curl http://192.168.3.2:8000/api/health` は `ready: true` / `gemma4:12b` / `mock_services: false`
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `/api/speakers` は引き続き `none` のみ
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `POST /api/turns/text` は成功し、返答 `確認したよ。準備ができたら教えてね。` とWAV URL `/media/audio/d5c9d0093c2143aa8c92a4efd67c39f3.wav` が返った
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: 上記WAVは `HTTP 200` / `content-type: audio/x-wav` / `content-length: 349484` でMacBookから取得可能
- UI Implementation Plan Phase 4のクライアント側キャンセル: done
- Phase 4キャンセルの実機UI確認: desktop PC会話サーバーへ接続したMacBook Web UIで、キャンセル後にpending発話が消え、遅延応答が画面へ反映されないことを確認
- Phase 4の制約: 同期RESTのため、キャンセルはクライアント側request中断と画面上の破棄。サーバー側LLM/TTS処理停止までは保証しない
- `pnpm -C client format`: success
- `pnpm -C client check`: 0 errors
- `pnpm -C client build`: success
- `pnpm -C client test:e2e`: 6 passed
- `UV_CACHE_DIR=/private/tmp/uv-cache-gemma4-irodori uv run pytest` in `server/`: 7 passed
- `bash -n scripts/register-irodori-voice.sh scripts/mac/*.sh scripts/wsl/*.sh scripts/*.sh`: success

## 次にやる候補

推奨順:

1. 参照音声ファイルを用意し、Irodori-TTS-Serverへ登録して `/api/speakers` で `none` 以外が出ることを実機確認する
2. 将来のジョブID方式またはWebSocket方式へ移れるよう、会話進行状態の型を整理する
3. 失敗時ログとUIメッセージの改善
4. 音声入力フェーズ
   - WebSocket設計
   - ブラウザマイク入力
   - PCM変換
   - サーバー側VAD
   - faster-whisper STT
   - 発話終端でテキスト会話ターンへ接続

## 注意点

- LAN限定方針は維持する。
- MVPではトークン認証なし。
- 会話履歴はMVPではメモリ保持。
- 同時会話は1つのみ。busy時は409で拒否。
- テキスト会話は同期REST。ユーザー発話はクライアント側で即時表示し、サーバー応答で置換する。
- テキスト会話のキャンセルはクライアント側のrequest中断と画面上の破棄。サーバー側処理は完了まで続き、その間はbusyになる場合がある。
- 読み上げON/OFFは設計には残すがMVPでは不要。
- 現状の実機 `/api/speakers` は `none` のみ。声質をキャラクターに寄せるにはIrodori-TTS-Serverへ参照音声を登録する必要がある。手順は [Reference Voice Setup](./reference-voice-setup.md)。
- `read_aloud_prompt` は将来用のメタデータで、現行Irodori-TTS-Serverのspeech endpointには直接渡していない。
- `speech_speed` はIrodori-TTS-Serverのspeech endpointへ `speed` として渡す。
- Windows AMD環境セットアップやLAN公開の切り分けは `gemma4-windows-amd-setup` skill を使う。
- MacBookローカル構成は [MacBook Local Setup](./macbook-local-setup.md) と `gemma4-macbook-local-setup` skill を使う。
- MacBookローカルのIrodori初回生成は長い。会話サーバーはMac用スクリプトで `GIC_REQUEST_TIMEOUT_SECONDS=600` にする。
- 新UIは基本的に正として扱い、未接続UIは [UI Implementation Plan](./ui-implementation-plan.md) に沿って段階的に実処理へ接続する。
- Tauri化はWebクライアントと会話サーバーが安定してから。
- スマホ実機対応もPC Webの縦切り後。

## セッションリセット時の開始プロンプト例

```text
このリポジトリの docs/handoff.md と docs/verification.md を読んで、現在地を把握してください。
MacBookから同じLAN内のdesktop PC WSL上の会話サーバーへ接続する前提で、次の作業を進めます。
まず git status と最新ドキュメントを確認してください。
```
