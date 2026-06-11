#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VITE_GIC_DEFAULT_BASE_URL="${VITE_GIC_DEFAULT_BASE_URL:-http://127.0.0.1:8000}"
VITE_GIC_BASE_URL_STORAGE_KEY="${VITE_GIC_BASE_URL_STORAGE_KEY:-gemma4-irodori-chat.base-url.mac-local}"

cd "$ROOT_DIR/client"

if [ ! -d node_modules ]; then
  echo "Installing client dependencies (node_modules not found)..."
  pnpm install
fi

VITE_GIC_DEFAULT_BASE_URL="$VITE_GIC_DEFAULT_BASE_URL" \
VITE_GIC_BASE_URL_STORAGE_KEY="$VITE_GIC_BASE_URL_STORAGE_KEY" \
pnpm dev
