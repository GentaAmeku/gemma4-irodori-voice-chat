# Server

## Development

```sh
uv sync
GIC_MOCK_SERVICES=1 uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

`GIC_MOCK_SERVICES=1` は開発用です。実運用ではOllamaとIrodori-TTS-Serverを起動し、以下を環境変数で指定します。

```sh
GIC_OLLAMA_BASE_URL=http://127.0.0.1:11434
GIC_OLLAMA_MODEL=gemma4:e4b-mlx
GIC_TTS_BASE_URL=http://127.0.0.1:8088
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

OllamaとIrodori-TTS-Serverをまとめて起動する場合:

```sh
../scripts/start-inference-stack.sh
```

この起動スクリプトはAMD GPU前提で、Irodori-TTS-Serverを `uv run --extra rocm` で起動します。

## Test

```sh
uv run pytest
```
