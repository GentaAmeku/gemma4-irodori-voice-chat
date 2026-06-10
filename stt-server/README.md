# STT Server (faster-whisper)

音声入力の文字起こしサービス。会話サーバーが `POST /api/stt` からこのサービスをプロキシする。
音声データをLAN内で処理し、外部の音声認識サービスへは送らない（[ADR 0004](../docs/adr/0004-server-side-stt.md)）。

## エンドポイント

- `GET /health` — `{ ok, model, mock }`
- `POST /v1/audio/transcriptions` — OpenAI互換風。multipart で `file`（音声）、任意で `model` / `language` / `response_format`。`{ "text": "..." }` を返す。

## 起動

実STT（faster-whisper が必要）:

```bash
cd stt-server
uv run --extra whisper uvicorn app.main:app --host 127.0.0.1 --port 8099
```

mock（モデル不要・依存なしで起動。固定文字列を返す）:

```bash
cd stt-server
GIC_STT_MOCK=1 uv run uvicorn app.main:app --host 127.0.0.1 --port 8099
```

## 設定（環境変数）

| 変数 | 既定 | 説明 |
|---|---|---|
| `GIC_STT_WHISPER_MODEL` | `kotoba-tech/kotoba-whisper-v2.0-faster` | モデル。代替: `large-v3`（高精度・CPUは遅い） / `small`（軽量） |
| `GIC_STT_DEVICE` | `auto` | `auto` / `cpu` / `cuda` |
| `GIC_STT_COMPUTE_TYPE` | `default` | CPUは `int8` が無難。GPUは `float16` など |
| `GIC_STT_LANGUAGE` | `ja` | 既定の認識言語 |
| `GIC_STT_BEAM_SIZE` | `5` | ビームサイズ |
| `GIC_STT_MOCK` | `0` | `1` でモデルを読まずモック応答 |

## モデル選択の目安

- 日本語短文を素早く: `kotoba-tech/kotoba-whisper-v2.0-faster`（既定）
- MacBook CPU: `compute_type=int8`。重いと感じたら `small`
- GPU（cuda）あり: `large-v3` + `compute_type=float16`

## テスト

```bash
cd stt-server
uv run pytest
```

mockモードのテストは faster-whisper なしで動く。
