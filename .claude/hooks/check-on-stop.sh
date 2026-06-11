#!/usr/bin/env bash
# Stop: コード変更(マーカー)があるときだけチェックを実行し、
# 失敗時のみ {"decision":"block"} でエラーを Claude に差し戻す。
# - client マーカー: svelte-check
# - server マーカー: ruff check + pytest
# 成功時・変更なし時は無言で停止を許可する(トークンを消費しない)。
set -uo pipefail

# stdin(Stop フックの JSON)は使わないので捨てる
cat >/dev/null 2>&1 || true

proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
marker_client="$proj/.claude/.needs-check-client"
marker_server="$proj/.claude/.needs-check-server"
counter="$proj/.claude/.check-attempts"

# 旧マーカー名(.needs-check)からの互換
[ -f "$proj/.claude/.needs-check" ] && mv "$proj/.claude/.needs-check" "$marker_client" 2>/dev/null

# 変更マーカーが無ければ何もしない(Q&A ターン等でムダに走らせない)
[ -f "$marker_client" ] || [ -f "$marker_server" ] || exit 0

errors=""

if [ -f "$marker_client" ] && [ -d "$proj/client" ]; then
  out=$(cd "$proj/client" && pnpm -s check 2>&1)
  if [ $? -eq 0 ]; then
    rm -f "$marker_client"
  else
    errors+=$'svelte-check に失敗しました。型/テンプレートのエラーを修正してください:\n\n'"$out"$'\n'
  fi
fi

if [ -f "$marker_server" ] && [ -d "$proj/server" ]; then
  out=$(cd "$proj/server" && uv run -q ruff check . 2>&1 && uv run -q pytest -q 2>&1)
  if [ $? -eq 0 ]; then
    rm -f "$marker_server"
  else
    errors+=$'サーバーのチェック(ruff check / pytest)に失敗しました。修正してください:\n\n'"$out"$'\n'
  fi
fi

if [ -z "$errors" ]; then
  rm -f "$counter"
  exit 0
fi

# 失敗: 無限ループ防止のため試行回数を上限でキャップ(4回目で打ち切り)
n=0
[ -f "$counter" ] && n=$(cat "$counter" 2>/dev/null || echo 0)
n=$((n + 1))
printf '%s' "$n" >"$counter"

if [ "$n" -ge 4 ]; then
  rm -f "$marker_client" "$marker_server" "$counter"
  printf '{"systemMessage":"Stop フックのチェックが複数回失敗しました。手動で確認してください。","suppressOutput":true}\n'
  exit 0
fi

# 失敗時のみエラー全文を Claude に差し戻して修正させる
reason=$(printf '%s' "$errors" | jq -Rs .)
printf '{"decision":"block","reason":%s}\n' "$reason"
exit 0
