# Claude Code フック

トークン消費を抑えるため、format / 型チェックを Claude の手動実行から外し、ハーネスのフックへ移したもの。設定は [`.claude/settings.json`](../settings.json) を参照。

## フック

### `format-file.sh` — PostToolUse(Write|Edit)

Claude が `client/` 配下のファイルを書き換えるたびに、その**1ファイルだけ**を `prettier --write` で整形する。

- 成功時は無言・非ブロッキング(Claude は整形を自分でやらないのでトークンを使わない)。
- `prettier` が扱えない拡張子・`.prettierignore` 対象は `--ignore-unknown` でスキップ。
- `.svelte` / `.ts` / `.js` を触ったときは、Stop フック用に `.claude/.needs-check` マーカーを置く。

### `check-on-stop.sh` — Stop

Claude がターンを終えようとしたとき、**コード変更があった場合のみ** `pnpm -s check`(svelte-check)を実行する。

- マーカーが無いターン(質問への回答など)では何もしない=ムダに走らせない。
- 成功時は無言でマーカーを消して停止を許可。
- 失敗時のみ `{"decision":"block","reason": <エラー全文>}` を返し、Claude にエラーを差し戻して修正させる。
- 無限ループ防止のため試行回数を 4 回でキャップする(`.claude/.check-attempts`)。

`.needs-check` / `.check-attempts` は内部状態。`.gitignore` 済み。

## 有効化

`.claude/settings.json` のフックは、**このリポジトリをプロジェクトルートとして** Claude Code を起動したときに読み込まれる。

```sh
cd /path/to/gemma4-irodori-chat && claude
```

既に起動中のセッションで反映されない場合は、`/hooks` を一度開く(設定が再読み込みされる)か、再起動する。

## 補足: E2E はフック化していない

Playwright はモックサーバー起動・ポート占有・数秒の実行時間があり、毎ターン自動実行はコスト高で環境依存。手動実行のまま。ポート衝突を避けるため、`playwright.config.ts` はテスト専用ポート(5180)で dev サーバーを起動する。

```sh
cd client && pnpm test:e2e
```
