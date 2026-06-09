# Handoff

最終更新: 2026-06-09

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
- 応答履歴
- 最後の読み上げプレイヤー
- 自動再生失敗時の手動再生導線
- 設定パネル
- 履歴クリア
- キャラクター画像アップロード

### Scripts

WSL標準:

- `scripts/wsl/setup-irodori-wsl-amd.sh`
- `scripts/wsl/start-irodori-wsl-amd.sh`
- `scripts/wsl/start-conversation-server-wsl.sh`
- `scripts/wsl/check-wsl-stack.sh`

Windows native fallback:

- `scripts/windows/*.ps1`

Linux AMD:

- `scripts/setup-irodori-amd.sh`
- `scripts/start-inference-stack.sh`
- `scripts/start-conversation-server-real.sh`
- `scripts/check-real-stack.sh`

## 重要ドキュメント

- [Verification Guide](./verification.md)
- [WSL AMD Setup](./wsl-amd-setup.md)
- [MVP Plan](./mvp-plan.md)
- [Design Notes](./design.md)
- [Context Glossary](../CONTEXT.md)
- [Gemma4 Irodori Setup Skill](../.agents/skills/gemma4-irodori-setup/SKILL.md)

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

## 直近の検証状況

直近の確認では以下が成功済み。

- `uv run pytest`: 3 passed
- `pnpm check`: 0 errors
- `pnpm build`: success
- `pnpm test:e2e`: 2 passed
- `bash -n scripts/wsl/*.sh`: success

## 次にやる候補

推奨順:

1. MacBookからdesktop PC WSL会話サーバーへの実機UI確認
2. 実irodori音声の再生品質と話者選択の確認
3. 失敗時ログとUIメッセージの改善
4. UIデザイン調整
5. 音声入力フェーズ
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
- 読み上げON/OFFは設計には残すがMVPでは不要。
- Tauri化はWebクライアントと会話サーバーが安定してから。
- スマホ実機対応もPC Webの縦切り後。

## セッションリセット時の開始プロンプト例

```text
このリポジトリの docs/handoff.md と docs/verification.md を読んで、現在地を把握してください。
MacBookから同じLAN内のdesktop PC WSL上の会話サーバーへ接続する前提で、次の作業を進めます。
まず git status と最新ドキュメントを確認してください。
```
