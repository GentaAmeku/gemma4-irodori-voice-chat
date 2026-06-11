---
name: check-all
description: このリポジトリの自動チェック一式（サーバー ruff + pytest、クライアント format / svelte-check / build / Playwright E2E、シェルスクリプト構文）をまとめて実行して結果を報告する。コミット前・push前・リリース前の確認、「全部チェックして」「検証一式」「全テスト実行」と言われたときに使う。
---

# 検証一式（check-all）

このリポジトリの自動チェックをすべて実行し、結果をまとめて報告する。

## 実行手順

以下を順に実行する。途中で失敗しても止めず、**全項目を実行してから**結果をまとめる。
独立した項目は並列実行してよい（ただし E2E と build は同時に走らせない）。

1. サーバー lint: `cd server && uv run ruff check .`
2. サーバーテスト: `cd server && uv run pytest`
3. クライアント整形: `pnpm -C client format`
4. クライアント型チェック: `pnpm -C client check`
5. クライアントビルド: `pnpm -C client build`
6. クライアント E2E: `pnpm -C client test:e2e`（専用ポート 5180 でモックサーバーを自動起動）
7. スクリプト構文: `bash -n scripts/*.sh scripts/mac/*.sh scripts/wsl/*.sh`

## 報告形式

各項目を pass / fail の一覧で報告し、fail があればエラーの要点と修正方針を添える。
`pnpm -C client format` で差分が出た場合は、整形されたファイル名を報告する。
