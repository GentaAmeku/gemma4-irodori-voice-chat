# Server

## Development

```sh
uv sync
GIC_MOCK_SERVICES=1 uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

`GIC_MOCK_SERVICES=1` は開発用です。実運用ではOllamaとIrodori-TTS-Serverを起動し、以下を環境変数で指定します。

```sh
GIC_OLLAMA_BASE_URL=http://127.0.0.1:11434
GIC_OLLAMA_MODEL=gemma4:12b
GIC_TTS_BASE_URL=http://127.0.0.1:8088
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

通常は環境別の起動スクリプトを使います（WSL標準構成は `../scripts/wsl/`、MacBookローカルは `../scripts/mac/`）。各スクリプトの役割は [`docs/scripts-and-startup.md`](../docs/scripts-and-startup.md) を参照してください。

MacBookローカルで使う場合は `gemma4:e4b-mlx` を既定にした専用スクリプトを使います。
このスクリプトはIrodoriの初回モデルロードに備えて `GIC_REQUEST_TIMEOUT_SECONDS=600` を既定にします。

```sh
../scripts/mac/start-conversation-server-mac.sh
```

## 読み上げの声質を固定する (`GIC_TTS_SEED`)

`speaker_id: "none"`(no-ref読み上げ)では、声質が生成時のシードで決まります。
シード未指定だとIrodori-TTS側が読み上げのたびに乱数シードを引くため、長い返答が
チャンク分割されると同じ返答の途中で声が別人に変わったり、ターンごとに声が変わります。
会話サーバーは既定で固定シード(`1234567`)を渡し、声質を一貫させます。

```sh
# 声質を変えたいとき(別のシードを試す)
GIC_TTS_SEED=42 uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
# 従来どおり毎回ランダムにする
GIC_TTS_SEED=none uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

参照音声を登録して声質を固定する方法は [`docs/reference-voice-setup.md`](../docs/reference-voice-setup.md) を参照してください。

## Test

```sh
uv run pytest
```
