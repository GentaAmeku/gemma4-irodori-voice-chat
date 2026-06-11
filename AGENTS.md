# AGENTS.md

Gemma4 Irodori Chat — コーディングエージェント共通の作業ガイド(Claude Code / Codex など)。

## 構成

- `server/` — Python(uv)の会話サーバー。
- `client/` — Svelte 5 + Vite + TypeScript のクライアントアプリ。UI デザインは [`client/DESIGN.md`](client/DESIGN.md)。
- 用語は [`CONTEXT.md`](CONTEXT.md) のユビキタス言語に従う(接続先 / 読み上げ / 履歴クリア / キャラクター設定 など)。

## 編集フロー(必須)

`client/` のコードを編集したら、終了前に以下を実行する:

```sh
pnpm -C client format   # prettier 整形
pnpm -C client check    # svelte-check(型 / テンプレート)
```

UI に観測可能な変更を加えたときは検証する:

```sh
pnpm -C client test:e2e # Playwright(専用ポート5180でモックサーバーを自動起動)
```

`server/` のコードを編集したら、終了前に以下を実行する:

```sh
cd server
uv run ruff format .    # 整形
uv run ruff check .     # lint
uv run pytest           # テスト
```

- クライアントのフォーマッタ設定は `client/.prettierrc.json`、lint / 型は svelte-check。
- サーバーの format / lint は ruff(dev 依存)、テストは pytest。
- E2E はモックサーバーを自動起動する。実行時間とポート占有があるため、UI を触ったときだけでよい。

## format / チェックの自動化(ツール別)

同じ format / チェックを、編集時とコミット時の両方で自動化している。

- **Claude Code**: [`.claude/settings.json`](.claude/settings.json) のフック。PostToolUse で編集ファイルを整形(client: prettier / server: ruff format)、Stop で svelte-check / ruff check / pytest。詳細は [`.claude/hooks/README.md`](.claude/hooks/README.md)。
- **すべてのツール / 人間(Codex 含む)**: git の pre-commit フック([`.githooks/`](.githooks/))。**クローン後に一度だけ有効化する**:

  ```sh
  git config core.hooksPath .githooks
  ```

  以後、コミット時にステージされたファイルを自動整形して再ステージし、`client/` は `svelte-check`、`server/` は `ruff check` + `pytest` を実行する(失敗するとコミットを中止)。

Codex で作業する場合も、上記の編集フローに従い、`git config core.hooksPath .githooks` を一度実行しておくこと。
