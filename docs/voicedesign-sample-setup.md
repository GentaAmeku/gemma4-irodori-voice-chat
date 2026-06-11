# VoiceDesign Sample Setup

Irodori-TTS-600M-v3-VoiceDesignで「ハスキーで低めの声の、落ち着いた大人の女性」の参照音声サンプルを作り、通常会話はIrodori-TTS-500M-v3 + 参照音声で運用するための手順です。

## 方針

- VoiceDesign(600M-v3)は**オフラインの声デザイン専用**に使う。会話のランタイムは500M-v3のまま変更しない。
  - 600M常用はターンあたり約1.3〜1.6倍の生成時間増(パラメータ+20% + caption用CFG分岐)とサーバー改修が必要になるため、まず参照音声方式で試す。
- captionは日本語で書く(公式の例文がすべて日本語のため)。
- 生成・登録はdesktop PC / WSL側で行う。MacBookへのVoiceDesignセットアップは不要。

## 最大時間の仕様(確認済み)

上限は**30秒**です(20秒という制限は存在しません)。制御は以下の3層で既に入っています。

| 層 | 上限 | 実装 |
| --- | --- | --- |
| 音声生成(infer.py / 会話の読み上げ共通) | 30秒 | 推論ランタイムの `max_seconds` デフォルト。v3系はテキストから長さを自動予測し、この上限でクランプされる |
| 会話サーバー経由の読み上げ | チャンク毎に30秒 | Irodori-TTS-Serverの `default_max_seconds = 30.0`。長文はチャンク分割されるため実質無制限 |
| 参照音声 | 先頭30秒まで使用 | Irodori-TTS-Serverの `default_max_ref_seconds = 30.0`。超過分は警告付きで切り詰め |

加えて `scripts/generate-voicedesign-sample.sh` に、生成サンプルの長さ確認(10〜30秒推奨の表示、30秒超の警告)と、`--seconds` の30秒超指定の拒否を実装しています。

## セットアップ(desktop PC / WSL)

```bash
cd ~/ghq/gemma4-irodori-voice-chat
scripts/wsl/setup-voicedesign-wsl-amd.sh
```

`../Irodori-TTS` にリポジトリをcloneし、ROCm extraで依存をインストールします。初回生成時にHugging Faceからモデル(0.6B)をダウンロードします。

## 候補サンプルの生成

```bash
scripts/generate-voicedesign-sample.sh
```

デフォルトで「ハスキーで低めの声の、落ち着いた大人の女性。余裕のあるゆっくりした話し方で、感情表現は控えめ。」のcaptionと約20秒相当の会話文を使い、シード1〜3の3候補を `../Irodori-TTS/outputs/voicedesign/` に生成します。

イメージと違う場合はシードやcaptionを変えて再生成します。

```bash
scripts/generate-voicedesign-sample.sh --seeds "10 11 12 13"
scripts/generate-voicedesign-sample.sh --caption "低くかすれた声の、物静かな大人の女性。"
```

## 登録と切替

1. 候補を試聴し、一番イメージに近いwavを選ぶ。
2. 参照音声として登録する([Reference Voice Setup](./reference-voice-setup.md)の登録方法A):

   ```bash
   SERVER_BASE_URL=http://127.0.0.1:8000 \
     scripts/register-conversation-voice.sh husky-mature /path/to/picked.wav
   ```

3. `speaker_id` を切り替える(話者選択UIはMVP外のため、APIで直接設定する):

   ```bash
   curl -s http://127.0.0.1:8000/api/settings \
     | python3 -c "import sys,json; s=json.load(sys.stdin); s['speaker_id']='husky-mature'; print(json.dumps(s))" \
     | curl -s -X PUT http://127.0.0.1:8000/api/settings -H 'Content-Type: application/json' -d @-
   ```

4. 実ターンで読み上げを確認し、必要なら `speech_speed` を調整する。

## 切り分け

- `infer.py` が見つからない場合は、先に `scripts/wsl/setup-voicedesign-wsl-amd.sh` を実行する。
- 生成が遅い・GPUが使われていない場合は、`uv sync --extra rocm` 済みか、`rocm-smi` でGPU認識を確認する([WSL AMD Setup](./wsl-amd-setup.md)参照)。
- 生成サンプルが30秒を超えた場合は、`--text` を短くするか `--seconds` で指定し直す(登録しても先頭30秒しか使われない)。
- クローニングでハスキーさが弱まる場合は、captionを強めて(例: 「低くかすれた声」)再生成する。それでも不足する場合に初めて600M-v3-VoiceDesignの常用化(サーバーへのcaption対応パッチ)を検討する。
