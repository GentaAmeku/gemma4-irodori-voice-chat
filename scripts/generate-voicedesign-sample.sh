#!/usr/bin/env bash
set -euo pipefail

# VoiceDesign (Irodori-TTS-600M-v3-VoiceDesign) で、参照音声用の候補サンプルを生成する。
# 生成したサンプルは register-conversation-voice.sh で登録し、
# 通常会話は Irodori-TTS-500M-v3 + 参照音声のまま運用する。
# 詳細: docs/voicedesign-sample-setup.md

HF_CHECKPOINT="Aratako/Irodori-TTS-600M-v3-VoiceDesign"
# Irodori推論ランタイムの生成上限と、参照音声として使われる長さの上限(どちらも30秒)。
MAX_REF_SECONDS=30

DEFAULT_SEEDS="1 2 3"
DEFAULT_CAPTION="ハスキーで低めの声の、落ち着いた大人の女性。余裕のあるゆっくりした話し方で、感情表現は控えめ。"
DEFAULT_TEXT="お疲れさま。今日は少し頑張りすぎたんじゃない？そういう日は、無理に全部片付けようとしなくていいと思う。温かいものでも飲んで、ゆっくり息をついて。焦らなくても、やるべきことはちゃんと進んでるから。明日のことは、明日の自分に任せておけばいい。"

usage() {
  cat <<'USAGE'
Usage:
  scripts/generate-voicedesign-sample.sh [--seeds "1 2 3"] [--caption CAPTION] [--text TEXT] [--seconds N] [--output-dir DIR]

VoiceDesignで参照音声用の候補サンプルを生成する。
事前に scripts/wsl/setup-voicedesign-wsl-amd.sh を実行しておくこと。

Options:
  --seeds       スペース区切りのシード一覧。デフォルト: "1 2 3"
  --caption     声の説明文。デフォルト: ハスキーで低めの落ち着いた大人の女性
  --text        読み上げテキスト。デフォルト: 約20秒相当の会話文
  --seconds     生成秒数の手動指定。省略時はテキストから自動予測(上限30秒)
  --output-dir  出力先。デフォルト: <Irodori-TTS>/outputs/voicedesign

Environment:
  IRODORI_TTS_DIR  Irodori-TTSリポジトリの場所。デフォルト: このリポジトリ隣の ../Irodori-TTS

Examples:
  scripts/generate-voicedesign-sample.sh
  scripts/generate-voicedesign-sample.sh --seeds "10 11 12 13"
  scripts/generate-voicedesign-sample.sh --caption "低くかすれた声の、物静かな大人の女性。"
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IRODORI_TTS_DIR="${IRODORI_TTS_DIR:-"$ROOT_DIR/../Irodori-TTS"}"

seeds="$DEFAULT_SEEDS"
caption="$DEFAULT_CAPTION"
text="$DEFAULT_TEXT"
seconds=""
output_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seeds)
      seeds="${2:?--seeds requires a value}"
      shift 2
      ;;
    --caption)
      caption="${2:?--caption requires a value}"
      shift 2
      ;;
    --text)
      text="${2:?--text requires a value}"
      shift 2
      ;;
    --seconds)
      seconds="${2:?--seconds requires a value}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:?--output-dir requires a value}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v uv >/dev/null 2>&1; then
  echo "missing command: uv" >&2
  exit 1
fi

if [[ ! -f "$IRODORI_TTS_DIR/infer.py" ]]; then
  echo "Irodori-TTS not found: $IRODORI_TTS_DIR" >&2
  echo "Run scripts/wsl/setup-voicedesign-wsl-amd.sh first." >&2
  exit 1
fi

# 30秒を超えるサンプルは参照音声として先頭30秒に切り詰められるため、手動指定は拒否する。
if [[ -n "$seconds" ]]; then
  if ! awk -v s="$seconds" -v max="$MAX_REF_SECONDS" 'BEGIN { exit !(s > 0 && s <= max) }'; then
    echo "--seconds must be in (0, ${MAX_REF_SECONDS}]. Reference audio is truncated to the first ${MAX_REF_SECONDS}s." >&2
    exit 2
  fi
fi

if [[ -z "$output_dir" ]]; then
  output_dir="$IRODORI_TTS_DIR/outputs/voicedesign"
fi
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

wav_duration() {
  uv run --no-sync python -c '
import sys
import wave

with wave.open(sys.argv[1], "rb") as w:
    print(f"{w.getnframes() / w.getframerate():.1f}")
' "$1"
}

cd "$IRODORI_TTS_DIR"

generated=()
for seed in $seeds; do
  out="$output_dir/voicedesign-seed${seed}.wav"
  echo "=== seed=${seed} -> ${out}"
  uv run --no-sync python infer.py \
    --hf-checkpoint "$HF_CHECKPOINT" \
    --text "$text" \
    --caption "$caption" \
    --no-ref \
    --seed "$seed" \
    ${seconds:+--seconds "$seconds"} \
    --output-wav "$out"
  generated+=("$out")
done

echo
echo "Generated candidates (target: 10-${MAX_REF_SECONDS}s):"
for out in "${generated[@]}"; do
  duration="$(wav_duration "$out")"
  note="ok"
  if awk -v d="$duration" -v max="$MAX_REF_SECONDS" 'BEGIN { exit !(d > max) }'; then
    note="WARNING: exceeds ${MAX_REF_SECONDS}s; only the first ${MAX_REF_SECONDS}s will be used as reference"
  elif awk -v d="$duration" 'BEGIN { exit !(d < 10) }'; then
    note="short; consider a longer --text for a more stable reference"
  fi
  echo "  ${out}  ${duration}s  (${note})"
done

cat <<EOF

Next steps:
  1. Listen and pick the best candidate.
  2. Register it as a reference voice:
       SERVER_BASE_URL=http://127.0.0.1:8000 \\
         "$ROOT_DIR/scripts/register-conversation-voice.sh" husky-mature /path/to/picked.wav
  3. Switch speaker_id (see docs/voicedesign-sample-setup.md).
EOF
