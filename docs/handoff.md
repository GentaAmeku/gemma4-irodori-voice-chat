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
  - `POST /api/speakers/{speaker_id}`
  - `GET /api/history`
  - `DELETE /api/history`
  - `POST /api/turns/text`
  - `GET /api/character-image`
  - `POST /api/character-image`
- Ollama adapter
- irodori-TTS adapter
- 話す速さ `speech_speed` の設定保存とIrodori speech `speed` への橋渡し
- no_ref読み上げの声質を固定するTTSシード（`DEFAULT_TTS_SEED`）。チャンク／ターンを跨いで同じ声質に保つ。`GIC_TTS_SEED` で変更、`none`/`random` でランダムに戻す
- 口調プリセット `tone_preset` と距離感 `distance` の設定保存、Ollama system promptへの合成
- 会話サーバー経由の参照音声アップロードとIrodori話者登録（MVP UIでは未使用）
- busy制御
- 会話ターン失敗の構造化エラー（`llm_timeout` / `llm_unavailable` / `llm_empty` / `tts_timeout` / `tts_unavailable`）。`/api/turns/text` は段階・原因別に 502/504 を返し、`gic.conversation` ロガーへ警告ログを出す
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
- 口調プリセット、距離感、話す速さの保存
- 設定パネルの自動保存（変更があればパネルを閉じた時に保存。保存ボタンは廃止。保存は会話履歴クリアを伴う）
- 音声入力（ブラウザの Web Speech API / SpeechRecognition、`ja-JP`）。録音→入力欄へ反映→既存のテキストターンで送信。未対応ブラウザ／非セキュアコンテキスト（素のLAN http）ではマイクを無効化
- 読み上げ音量のローカル保存（この端末のみ。会話サーバーへは送らない）
- 返答生成中の中立スピナー表示（録音中の赤い塗りと区別）
- 話者選択はMVP UIから削除。読み上げは `speaker_id: "none"` とIrodori-TTS-Server側no-refカスタマイズを使う
- 設定パネルのフォーム説明 `aria-describedby` 紐付け
- 設定の自動保存 / 接続確認 / 画像アップロード / 履歴クリア中の二重送信防止
- 会話サーバー未接続 / Ollama不可 / irodori-TTS不可 / タイムアウト / 自動再生失敗の原因別エラー表示（会話ターン失敗はサーバーの失敗コード別に文言を出し分け）
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
- `scripts/register-conversation-voice.sh`

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
- [Irodori No-Reference Voice Setup](./no-ref-voice-setup.md)
- [MacBook Local Setup](./macbook-local-setup.md)
- [UI Implementation Plan](./ui-implementation-plan.md)
- [WSL AMD Setup](./wsl-amd-setup.md)
- [MVP Plan](./mvp-plan.md)
- [Design Notes](./design.md)
- [Tauri Setup](./tauri-setup.md)
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
- `scripts/register-conversation-voice.sh` 追加
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
- 会話サーバー経由の参照音声登録APIを追加。MacBookからIrodori 8088番へ直接接続できない標準構成でも、会話サーバー8000番へアップロードしてIrodoriへ登録できる
- `UV_CACHE_DIR=/private/tmp/uv-cache-gemma4-irodori uv run pytest` in `server/`: 10 passed
- `bash -n scripts/register-conversation-voice.sh scripts/register-irodori-voice.sh scripts/mac/*.sh scripts/wsl/*.sh scripts/*.sh`: success
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `POST /api/speakers/endpoint_check` は `unsupported_voice_type` の400を返し、新しい参照音声登録endpointの反映を確認
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `curl http://192.168.3.2:8000/api/health` は `ready: true` / `gemma4:12b` / `mock_services: false`
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `/api/settings` は `speech_speed: 1.0`
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `/api/speakers` は引き続き `none` のみ
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `POST /api/turns/text` は成功し、返答 `了解したよ。準備ができたら教えてね。` とWAV URL `/media/audio/d010f601b33642aebd8c7630b65c4059.wav` が返った
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: 上記WAVは `HTTP 200` / `content-type: audio/x-wav` / `content-length: 326444` でMacBookから取得可能
- Phase 4残作業の会話進行状態型整理: `ActiveConversation` と `transport` を追加し、現在の同期RESTキャンセルを将来のjob/WebSocket方式へ拡張しやすい形に整理
- `pnpm -C client format`: success
- `pnpm -C client check`: 0 errors
- `pnpm -C client build`: success
- `pnpm -C client test:e2e`: 6 passed
- `UV_CACHE_DIR=/private/tmp/uv-cache-gemma4-irodori uv run pytest` in `server/`: 10 passed
- Phase 3の口調プリセット / 距離感の実処理化: `tone_preset` / `distance` をサーバー設定へ昇格し、Ollama送信前に `character_prompt` へ合成
- 話者選択をMVP UIから削除。MVPは `speaker_id: "none"` とIrodori-TTS-Server側のno-refカスタマイズで進める
- `UV_CACHE_DIR=/private/tmp/uv-cache-gemma4-irodori uv run pytest` in `server/`: 11 passed
- `pnpm -C client format`: success
- `pnpm -C client check`: 0 errors
- `pnpm -C client build`: success
- `pnpm -C client test:e2e`: 6 passed
- Browser DOM確認: 設定パネルから話者テキスト / 話者selectが消え、口調プリセット / 距離感 / 話す速さが表示されることを確認
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `curl http://192.168.3.2:8000/api/health` は `ready: true` / `gemma4:12b` / `mock_services: false`
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `/api/settings` は `speech_speed: 1.0` / `tone_preset: calm` / `distance: 40` / `speaker_id: none`
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `/api/speakers` は `none` のみ。MVP方針では正常
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: `POST /api/turns/text` は成功し、返答 `はい、しっかり受け取ったよ。これからよろしくね。` とWAV URL `/media/audio/853491d11431432aab019ba03a0bcfd1.wav` が返った
- desktop PC側WSLリポジトリpull / 会話サーバー再起動後の確認: 上記WAVは `HTTP 200` / `content-type: audio/x-wav` / `content-length: 399404` でMacBookから取得可能
- `client/.env.example` を追加し、`client/.env.local` で `VITE_GIC_DEFAULT_BASE_URL` を指定できる手順に整理。`client/.env.local` はgit管理外
- 音声入力（Web Speech API）・読み上げ音量・設定の自動保存・TTSシード固定・UIレイアウト調整（レール幅424px・キャラ画像拡大）をコミット `cdffa80` としてmainへ反映
- コミット `cdffa80` 後のローカル検証: `pnpm -C client check` 0 errors / `pnpm -C client build` success / `pnpm -C client test:e2e` 7 passed / `server` で `uv run pytest` 12 passed
- 一時的にサーバー側STT（faster-whisper）を実装（コミット `01be1b5`）したが、認識相違により revert。音声入力は Web Speech API のまま継続する。「LAN限定」はLLM推論・会話サーバー経路の話で、音声がChrome経由で外部音声認識（Google等）に渡るのは許容、というのが正しい意図
- revert 後のローカル検証: `server` で `uv run pytest` / `pnpm -C client check` / `pnpm -C client build` / `pnpm -C client test:e2e`（結果は revert コミットに記録）
- 失敗時ログ/UIメッセージ改善: 会話ターン失敗を段階別の構造化エラー（502/504 + `llm_*`/`tts_*` コード）＋サーバーログ（`gic.conversation`）化し、クライアントは原因別メッセージを表示。検証 `server` pytest 15 passed / `pnpm -C client check` 0 errors / build success / e2e 8 passed
- 音声入力(Web Speech API)の仕上げ: 録音最大時間のセーフティ自動停止・アンマウント時クリーンアップ・network/無音メッセージ調整。`pnpm -C client check` 0 errors / build / e2e 8 passed
- Tauri v2 の足場を `client/src-tauri/` に作成（公式CLIで init、productName=Irodori Chat / identifier=com.gentaameku.irodorichat / ウィンドウ1120×760 に調整、`tauri info` で設定検証）。初回 `tauri dev`/`build` は未実行（Rust初回コンパイルが必要）

## 次にやる候補

推奨順:

1. Irodori-TTS-Server側のno-ref音声カスタマイズ後、`speaker_id: "none"` のまま期待する声質で読み上がることを実機確認する
   - 声質を固定するTTSシード（`DEFAULT_TTS_SEED`）は実装・コミット済み。残りは desktop PC（WSL）へ pull → 会話サーバー再起動 → 実機試聴での確認
2. 音声入力（Web Speech API）の実機確認と仕上げ
   - セキュアコンテキスト（`pnpm dev` の localhost / 将来の Tauri）で、マイク録音→入力欄反映→送信を実機確認する
   - 認識精度・無音時の扱い・エラーメッセージの調整
   - 最終形は Tauri アプリ（MacBook）で音声入力を動かす
3. Tauri 初回ビルドの実機確認
   - 足場は `client/src-tauri/`（Tauri v2）に作成済み。`pnpm tauri dev` / `pnpm tauri build` を実機で通す（初回は Rust 依存のコンパイルで数分）。手順は [Tauri Setup](./tauri-setup.md)

（完了: 失敗時ログとUIメッセージの改善 — 会話ターン失敗を段階別の構造化エラー＋サーバーログ化し、クライアントは原因別メッセージを表示）

## 注意点

- LAN限定方針は維持する（対象はLLM推論・会話サーバー経路。MacBookクライアントから同一LAN内のデスクトップPCのローカルLLMを呼ぶこと。音声入力の文字起こし経路は対象外で、次項のとおりWeb Speech APIを使う）。
- MVPではトークン認証なし。
- 会話履歴はMVPではメモリ保持。
- 同時会話は1つのみ。busy時は409で拒否。
- テキスト会話は同期REST。ユーザー発話はクライアント側で即時表示し、サーバー応答で置換する。
- テキスト会話のキャンセルはクライアント側のrequest中断と画面上の破棄。サーバー側処理は完了まで続き、その間はbusyになる場合がある。
- 読み上げON/OFFは設計には残すがMVPでは不要。
- 音声入力はブラウザの Web Speech API（SpeechRecognition）を使う。Chrome では音声が外部（Google）の音声認識へ送られるが、これは許容する（音声経路はLAN限定方針の対象外）。
- Web Speech API はセキュアコンテキスト必須。`pnpm dev` の localhost / https / Tauri では動くが、素のLAN http（例: スマホから `http://192.168.3.2`）では無効で、その場合はマイクを無効表示にする。最終形は Tauri アプリ（MacBook）で音声入力を動かす想定。
- 設定はパネルを閉じたときに変更があれば自動保存する（保存ボタンなし）。保存は会話履歴クリアを伴う。変更がなければ保存しない。
- 読み上げ音量はこの端末のlocalStorageのみに保存し、会話サーバーへは送らない。
- no_ref読み上げの声質はTTSシード（`DEFAULT_TTS_SEED`、`GIC_TTS_SEED`で上書き）で固定する。`none`/`random` で従来のランダム挙動に戻る。
- 現状の実機 `/api/speakers` は `none` のみ。MVPではこれを正常扱いにし、声質はIrodori-TTS-Server側のno-ref設定で調整する。
- 参照音声登録APIとスクリプトは残すが、MVP外の将来用。手順は [Reference Voice Setup](./reference-voice-setup.md)。
- `read_aloud_prompt` は将来用のメタデータで、現行Irodori-TTS-Serverのspeech endpointには直接渡していない。
- `speech_speed` はIrodori-TTS-Serverのspeech endpointへ `speed` として渡す。
- Windows AMD環境セットアップやLAN公開の切り分けは `gemma4-windows-amd-setup` skill を使う。
- MacBookローカル構成は [MacBook Local Setup](./macbook-local-setup.md) と `gemma4-macbook-local-setup` skill を使う。
- MacBookローカルのIrodori初回生成は長い。会話サーバーはMac用スクリプトで `GIC_REQUEST_TIMEOUT_SECONDS=600` にする。
- 新UIは基本的に正として扱い、未接続UIは [UI Implementation Plan](./ui-implementation-plan.md) に沿って段階的に実処理へ接続する。
- Tauri化はWebクライアントと会話サーバーが安定してから。足場（`client/src-tauri/`、Tauri v2）は用意済み。初回 `pnpm tauri dev` / `pnpm tauri build` は実機で通す。手順は [Tauri Setup](./tauri-setup.md)。Tauri の WebView はセキュアコンテキストなので、ブラウザで無効だった音声入力（Web Speech API）もアプリ内では動く。
- スマホ実機対応もPC Webの縦切り後。

## セッションリセット時の開始プロンプト例

```text
このリポジトリの docs/handoff.md と docs/verification.md を読んで、現在地を把握してください。
MacBookから同じLAN内のdesktop PC WSL上の会話サーバーへ接続する前提で、次の作業を進めます。
まず git status と最新ドキュメントを確認してください。
```
