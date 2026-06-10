#!/usr/bin/env bash
# Stop: コード変更(マーカー)があるときだけ svelte-check を実行し、
# 失敗時のみ {"decision":"block"} でエラーを Claude に差し戻す。
# 成功時・変更なし時は無言で停止を許可する(トークンを消費しない)。
set -uo pipefail

# stdin(Stop フックの JSON)は使わないので捨てる
cat >/dev/null 2>&1 || true

proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
marker="$proj/.claude/.needs-check"
counter="$proj/.claude/.check-attempts"

# 変更マーカーが無ければ何もしない(Q&A ターン等でムダに走らせない)
[ -f "$marker" ] || exit 0

client="$proj/client"
[ -d "$client" ] || exit 0

out=$(cd "$client" && pnpm -s check 2>&1)
status=$?

if [ "$status" -eq 0 ]; then
  rm -f "$marker" "$counter"
  exit 0
fi

# 失敗: 無限ループ防止のため試行回数を上限でキャップ(4回目で打ち切り)
n=0
[ -f "$counter" ] && n=$(cat "$counter" 2>/dev/null || echo 0)
n=$((n + 1))
printf '%s' "$n" >"$counter"

if [ "$n" -ge 4 ]; then
  rm -f "$marker" "$counter"
  printf '{"systemMessage":"svelte-check が複数回失敗しました。手動で確認してください。","suppressOutput":true}\n'
  exit 0
fi

# 失敗時のみエラー全文を Claude に差し戻して修正させる
reason=$(printf 'svelte-check に失敗しました。型/テンプレートのエラーを修正してください:\n\n%s' "$out" | jq -Rs .)
printf '{"decision":"block","reason":%s}\n' "$reason"
exit 0
