#!/usr/bin/env bash
# PostToolUse(Write|Edit): 編集された client 配下のファイルを prettier で整形する。
# svelte-check の対象(.svelte/.ts/.js)を触ったら Stop 用のマーカーを置く。
# 成功時は無言・非ブロッキング(トークンを消費しない)。
set -uo pipefail

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)
[ -n "$f" ] || exit 0

# client 配下のファイルだけを対象にする
case "$f" in
  */client/*) ;;
  *) exit 0 ;;
esac

proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
client="$proj/client"
prettier="$client/node_modules/.bin/prettier"

# 整形(prettier が扱えない拡張子・.prettierignore 対象は --ignore-unknown でスキップ)
if [ -x "$prettier" ]; then
  (cd "$client" && "$prettier" --write --ignore-unknown "$f") >/dev/null 2>&1 || true
fi

# 型/テンプレートに影響する変更なら Stop でチェックするためのマーカーを置く
case "$f" in
  *.svelte | *.ts | *.js)
    mkdir -p "$proj/.claude" 2>/dev/null || true
    : >"$proj/.claude/.needs-check" 2>/dev/null || true
    ;;
esac

exit 0
