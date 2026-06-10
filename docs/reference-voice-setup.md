# Reference Voice Setup

Irodori-TTS-Serverでキャラクターの参照音声を使うための手順です。

## 方針

- 参照音声はIrodori-TTS-Server側に登録する。
- クライアントや会話サーバーは、Irodoriの話者IDを選んで保存するだけにする。
- MacBookからdesktop PC / WSL構成を使う場合も、MacBookに音声を置くのではなく、desktop PC側のIrodori-TTS-Serverへ登録する。
- `read_aloud_prompt` は現時点では将来用メタデータ。現行Irodori speech endpointへ直接渡していない。
- 話す速さは会話サーバー設定の `speech_speed` として保存し、Irodori speech requestの `speed` へ渡す。

## 参照音声ファイル

Irodori-TTS-Serverが受け付ける拡張子:

```text
.wav .flac .mp3 .m4a .ogg .opus .aac .webm
```

話者IDはASCII英数字、`_`、`-` のみ使えます。

例:

```text
rinon
rinon-soft
sample_01
```

## 登録方法A: APIでアップロードする

Irodori-TTS-Serverが起動している状態で実行します。

```bash
TTS_BASE_URL=http://127.0.0.1:8088 \
  ./scripts/register-irodori-voice.sh rinon /path/to/rinon.wav
```

同じ話者IDを置き換える場合:

```bash
TTS_BASE_URL=http://127.0.0.1:8088 \
  ./scripts/register-irodori-voice.sh rinon /path/to/rinon.wav --replace
```

Irodori側で `IRODORI_API_KEY` を設定している場合:

```bash
IRODORI_API_KEY=<key> TTS_BASE_URL=http://127.0.0.1:8088 \
  ./scripts/register-irodori-voice.sh rinon /path/to/rinon.wav
```

## 登録方法B: voices/へ直接置く

Irodori-TTS-Serverは `voices/` に置かれた音声ファイルを話者としてスキャンします。

MacBookローカル構成の標準配置:

```bash
cp /path/to/rinon.wav ../Irodori-TTS-Server/voices/rinon.wav
```

desktop PC / WSL構成の標準配置:

```bash
cd ~/ghq/gemma4-irodori-voice-chat
cp /path/to/rinon.wav ../Irodori-TTS-Server/voices/rinon.wav
```

直置きした場合は、必要に応じてIrodori-TTS-Serverを再起動します。

## 確認

Irodori-TTS-Serverで話者が見えることを確認します。

```bash
curl http://127.0.0.1:8088/v1/audio/voices
```

会話サーバー経由で見えることを確認します。

```bash
curl http://127.0.0.1:8000/api/speakers
```

期待値:

- `none` に加えて、登録した話者IDが返る
- 例: `rinon`

## UIで使う

1. Webクライアントを開く。
2. Optionsを開く。
3. `声 ・ 読み上げ` の `話者` で登録した話者IDを選ぶ。
4. `話す速さ` を必要に応じて調整する。
5. 保存する。
6. 次の会話ターンで、選択話者と速度がIrodori-TTS-Serverへ送られる。

## 切り分け

`/api/speakers` に `none` しか出ない場合:

- Irodori-TTS-Serverの `/v1/audio/voices` に話者IDが出ているか確認する。
- API登録で409が出る場合は `--replace` を使う。
- 話者IDに日本語や空白を使っていないか確認する。
- MacBookからdesktop PC / WSL構成を使う場合、音声をMacBook側ではなくdesktop PC / WSL側の `../Irodori-TTS-Server/voices/` またはIrodori APIへ登録しているか確認する。
- Irodori-TTS-Serverを再起動してから再確認する。
