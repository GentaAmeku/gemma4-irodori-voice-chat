# Irodori No-Reference Voice Setup

MVPでは、Irodori-TTS-Serverの参照音声登録を使わず、`speaker_id: "none"` の読み上げを使います。
声質はWebアプリ側ではなく、Irodori-TTS-Server側のno-reference voice設定で調整します。

## アプリ側の前提

- Webクライアントに話者選択UIは表示しない。
- 会話サーバーは読み上げ時に `voice.id` として `none` を送る。
- `speech_speed` はIrodori speech requestの `speed` へ送る。
- `read_aloud_prompt` は将来用メタデータで、現行speech endpointには直接渡さない。
- `/api/speakers` が `none` のみでもMVPでは正常扱い。

## 確認方法

会話サーバー経由で現在の設定を確認します。

```bash
curl http://127.0.0.1:8000/api/settings
```

期待値:

- `speaker_id` が `none`
- `speech_speed` が保存した値
- `tone_preset` と `distance` が保存した値

実ターンで読み上げまで確認します。

```bash
curl -X POST http://127.0.0.1:8000/api/turns/text \
  -H 'Content-Type: application/json' \
  -d '{"text":"読み上げ確認です。短く返事してください。"}'
```

返った `audio_url` を取得し、Irodori側で調整したno-ref声質になっているか聴感で確認します。

## 参照音声を使う場合

参照音声登録はMVP外の将来用です。
必要になった場合は [Reference Voice Setup](./reference-voice-setup.md) を参照してください。
VoiceDesignモデルで参照音声サンプルを生成する場合は [VoiceDesign Sample Setup](./voicedesign-sample-setup.md) を参照してください。
