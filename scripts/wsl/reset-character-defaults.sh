#!/usr/bin/env bash
set -euo pipefail

# 会話サーバーのキャラクター設定をデフォルトへ戻す。
# - data/settings.json を削除 → 次回読込時に AppSettings() のデフォルトで再生成
#
# キャラクター画像はキャラクタープリセットに紐づく同梱アセット
# (server/app/assets/character-image-{preset_id}.png) なので、リセット対象はない。
#
# サーバーは /api/settings を都度ディスクから読むため、
# 起動したままでも次のリクエストからデフォルトが反映される(再起動不要)。
#
# 使い方:
#   scripts/wsl/reset-character-defaults.sh       # settings.json を初期化(確認あり)
#   scripts/wsl/reset-character-defaults.sh -y    # 確認なしで実行
#
# データの場所は GIC_DATA_DIR を尊重する(未設定なら server/data)。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assume_yes=false

usage() {
  cat <<'USAGE'
Usage: reset-character-defaults.sh [-y|--yes]

  (引数なし)        settings.json を削除してデフォルト設定へ戻す
  -y, --yes         確認プロンプトを出さずに実行する
  -h, --help        このヘルプを表示する
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y | --yes)
      assume_yes=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "不明な引数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

# config.py の既定(server/data)と揃える。GIC_DATA_DIR があればそれを優先。
DATA_DIR="${GIC_DATA_DIR:-$ROOT_DIR/server/data}"
DATA_DIR="${DATA_DIR/#\~/$HOME}"

if [ ! -d "$DATA_DIR" ]; then
  echo "データディレクトリが見つかりません: $DATA_DIR" >&2
  echo "サーバーを一度起動したことがあるか、GIC_DATA_DIR の指定を確認してください。" >&2
  exit 1
fi

echo "対象データディレクトリ: $DATA_DIR"

if [ ! -f "$DATA_DIR/settings.json" ]; then
  echo "削除対象はありません。すでにデフォルト状態です。"
  exit 0
fi

echo "以下を削除します:"
echo "  - $DATA_DIR/settings.json  (→ デフォルト設定で再生成される)"

if [ "$assume_yes" != true ]; then
  printf "実行しますか? [y/N]: "
  read -r answer
  case "$answer" in
    y | Y | yes | YES) ;;
    *)
      echo "中止しました。"
      exit 0
      ;;
  esac
fi

rm -f -- "$DATA_DIR/settings.json"
echo "削除しました: $DATA_DIR/settings.json"

echo "完了しました。アプリを再接続(または再読み込み)すればデフォルトが表示されます。"
