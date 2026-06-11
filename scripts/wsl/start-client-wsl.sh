#!/usr/bin/env bash
set -euo pipefail

# Windows PC 1台で完結する構成用のクライアント起動。
# WSL内で Vite dev サーバーを起動し、Windows のブラウザから
# http://localhost:5173 で開く(WSL2 の localhost フォワーディングを使う)。
# 接続先の既定は同じ WSL 内の会話サーバー http://127.0.0.1:8000。
# 推論PC接続用(MacBookなど)の保存値と混ざらないよう、専用の localStorage キーを使う。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VITE_GIC_DEFAULT_BASE_URL="${VITE_GIC_DEFAULT_BASE_URL:-http://127.0.0.1:8000}"
VITE_GIC_BASE_URL_STORAGE_KEY="${VITE_GIC_BASE_URL_STORAGE_KEY:-gemma4-irodori-chat.base-url.wsl-local}"

cd "$ROOT_DIR/client"

if [ ! -d node_modules ]; then
  echo "Installing client dependencies (node_modules not found)..."
  pnpm install
fi

VITE_GIC_DEFAULT_BASE_URL="$VITE_GIC_DEFAULT_BASE_URL" \
VITE_GIC_BASE_URL_STORAGE_KEY="$VITE_GIC_BASE_URL_STORAGE_KEY" \
pnpm dev
