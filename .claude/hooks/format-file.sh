#!/usr/bin/env bash
# PostToolUse(Write|Edit): 編集されたファイルを整形する。
# - client 配下: prettier で整形。svelte-check の対象(.svelte/.ts/.js)なら Stop 用マーカーを置く
# - server 配下: ruff format で整形(.py)。Stop 用マーカーを置く
# 成功時は無言・非ブロッキング(トークンを消費しない)。
set -uo pipefail

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)
[ -n "$f" ] || exit 0

proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"

mark() {
  mkdir -p "$proj/.claude" 2>/dev/null || true
  : >"$proj/.claude/$1" 2>/dev/null || true
}

case "$f" in
  */client/*)
    client="$proj/client"
    prettier="$client/node_modules/.bin/prettier"
    # 整形(prettier が扱えない拡張子・.prettierignore 対象は --ignore-unknown でスキップ)
    if [ -x "$prettier" ]; then
      (cd "$client" && "$prettier" --write --ignore-unknown "$f") >/dev/null 2>&1 || true
    fi
    # 型/テンプレートに影響する変更なら Stop でチェックするためのマーカーを置く
    case "$f" in
      *.svelte | *.ts | *.js) mark ".needs-check-client" ;;
    esac
    ;;
  */server/*)
    case "$f" in
      *.py)
        (cd "$proj/server" && uv run -q ruff format "$f") >/dev/null 2>&1 || true
        mark ".needs-check-server"
        ;;
    esac
    ;;
esac

exit 0
