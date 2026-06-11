#!/usr/bin/env bash
set -euo pipefail

# 会話サーバーのキャラクターをデフォルトへ戻す。
# - data/character-image.*  を削除 → assets/default-character-image.png にフォールバック
# - data/settings.json      を削除 → 次回読込時に AppSettings() のデフォルトで再生成
#
# サーバーは /api/settings と /api/character-image を都度ディスクから読むため、
# 起動したままでも次のリクエストからデフォルトが反映される(再起動不要)。
#
# 使い方:
#   scripts/wsl/reset-character-defaults.sh            # 画像と設定の両方を初期化(確認あり)
#   scripts/wsl/reset-character-defaults.sh --image-only
#   scripts/wsl/reset-character-defaults.sh --settings-only
#   scripts/wsl/reset-character-defaults.sh -y         # 確認なしで実行
#
# データの場所は GIC_DATA_DIR を尊重する(未設定なら server/data)。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

reset_image=true
reset_settings=true
assume_yes=false

usage() {
  cat <<'USAGE'
Usage: reset-character-defaults.sh [--image-only|--settings-only] [-y|--yes]

  (引数なし)        キャラクター画像と設定の両方をデフォルトへ戻す
  --image-only      アップロード画像のみ削除(設定は残す)
  --settings-only   settings.json のみ削除(画像は残す)
  -y, --yes         確認プロンプトを出さずに実行する
  -h, --help        このヘルプを表示する
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --image-only)
      reset_image=true
      reset_settings=false
      ;;
    --settings-only)
      reset_image=false
      reset_settings=true
      ;;
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

# 削除対象を収集する(マッチなしでも安全に空配列にする)。
shopt -s nullglob
image_files=()
if [ "$reset_image" = true ]; then
  image_files=("$DATA_DIR"/character-image.*)
fi
settings_file=""
if [ "$reset_settings" = true ] && [ -f "$DATA_DIR/settings.json" ]; then
  settings_file="$DATA_DIR/settings.json"
fi
shopt -u nullglob

if [ "${#image_files[@]}" -eq 0 ] && [ -z "$settings_file" ]; then
  echo "削除対象はありません。すでにデフォルト状態です。"
  exit 0
fi

echo "以下を削除します:"
# 空配列を set -u 下で展開しても落ちないイディオム(古い bash 3.2 対策)。
for f in ${image_files[@]+"${image_files[@]}"}; do
  echo "  - $f  (→ デフォルト画像 default-character-image.png に戻る)"
done
if [ -n "$settings_file" ]; then
  echo "  - $settings_file  (→ デフォルト設定で再生成される)"
fi

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

for f in ${image_files[@]+"${image_files[@]}"}; do
  rm -f -- "$f"
  echo "削除しました: $f"
done
if [ -n "$settings_file" ]; then
  rm -f -- "$settings_file"
  echo "削除しました: $settings_file"
fi

echo "完了しました。アプリを再接続(または再読み込み)すればデフォルトが表示されます。"
