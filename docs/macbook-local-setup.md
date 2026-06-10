# MacBook Local Setup

この手順は、開発中のMacBookだけでOllama、Irodori-TTS-Server、会話サーバー、Webクライアントを動かすためのものです。

## 方針

```text
MacBook browser / client
  -> MacBook conversation server
  -> MacBook Ollama gemma4:e4b-mlx
  -> MacBook Irodori-TTS-Server
```

Windows AMD推論PC / WSL構成は引き続き標準の実機構成です。MacBookローカル構成は、開発中にLANやWindows PCへ依存せずに動作確認するための別プロファイルとして扱います。

重要:

- MacBookでは既定モデルを `gemma4:e4b-mlx` にする。
- MacBookではROCmを使わない。Irodori-TTS-Serverは既定で `cpu` extraを使う。
- MacBookローカル構成では、会話サーバーとクライアントは `127.0.0.1` に閉じる。
- Windows推論PC接続用のクライアント保存値と混ぜないため、MacBookローカル用クライアントは別のlocalStorageキーを使う。

## 1. Ollama

Ollamaを起動し、MacBook用モデルを用意します。

```sh
ollama pull gemma4:e4b-mlx
ollama list
```

Ollamaが起動していない場合は、`scripts/mac/start-inference-stack-mac.sh` が `ollama serve` を起動します。

確認:

```sh
curl http://127.0.0.1:11434/api/tags
```

## 2. Irodori-TTS-Server

初回セットアップ:

```sh
./scripts/mac/setup-irodori-mac.sh
```

既定では `../Irodori-TTS-Server` にcloneし、`uv sync --extra cpu` を実行します。

別ディレクトリを使う場合:

```sh
IRODORI_TTS_SERVER_DIR=/path/to/Irodori-TTS-Server ./scripts/mac/setup-irodori-mac.sh
```

## 3. 推論スタック起動

OllamaとIrodori-TTS-Serverをまとめて起動します。

```sh
./scripts/mac/start-inference-stack-mac.sh
```

Irodori-TTS-Serverを単独で起動する場合:

```sh
./scripts/mac/start-irodori-mac.sh
```

Irodoriのbackend extraを変える必要がある場合:

```sh
IRODORI_UV_EXTRA=cpu ./scripts/mac/start-irodori-mac.sh
```

## 4. 会話サーバー起動

別ターミナルで起動します。

```sh
./scripts/mac/start-conversation-server-mac.sh
```

既定値:

- `GIC_OLLAMA_BASE_URL`: `http://127.0.0.1:11434`
- `GIC_OLLAMA_MODEL`: `gemma4:e4b-mlx`
- `GIC_TTS_BASE_URL`: `http://127.0.0.1:8088`
- `GIC_REQUEST_TIMEOUT_SECONDS`: `600`
- app listen: `127.0.0.1:8000`

モデルを変える場合:

```sh
GIC_OLLAMA_MODEL=gemma4:12b ./scripts/mac/start-conversation-server-mac.sh
```

## 5. Webクライアント起動

別ターミナルで起動します。

```sh
./scripts/mac/start-client-mac.sh
```

ブラウザで開きます。

```text
http://127.0.0.1:5173/
```

MacBookローカル用クライアントでは、接続先の既定値は `http://127.0.0.1:8000` です。Windows推論PC接続用に保存した `http://192.168.3.2:8000` とは別のlocalStorageキーを使います。

## 6. 疎通確認

推論スタックと会話サーバーが起動してから実行します。

```sh
./scripts/mac/check-mac-stack.sh
```

期待値:

- Ollamaの `/api/tags` が返る
- Irodori-TTS-Serverの `/health` が返る
- Irodori-TTS-Serverの `/v1/audio/voices` が返る
- 会話サーバーの `/api/health` が `ready: true` を返す
- `POST /api/turns/text` でLLM応答とWAV URLが返る

## 7. 参照音声

MacBookローカル構成でキャラクターの参照音声を使う場合は、MacBook上のIrodori-TTS-Serverへ登録します。

```sh
TTS_BASE_URL=http://127.0.0.1:8088 \
  ./scripts/register-irodori-voice.sh rinon /path/to/rinon.wav
```

または、Irodori-TTS-Serverの標準 `voices/` に直接置きます。

```sh
cp /path/to/rinon.wav ../Irodori-TTS-Server/voices/rinon.wav
```

詳細は [Reference Voice Setup](./reference-voice-setup.md) を参照してください。

## 注意点

- MacBookのIrodori-TTS-ServerはCPU backend想定のため、Windows AMD / WSL ROCm構成より遅い可能性があります。
- 初回音声生成ではIrodoriのモデルロードとHugging Face cache作成が入るため、数分かかることがあります。
- `gemma4:e4b-mlx` はMacBook開発用の軽量モデルです。Windows AMD推論PCの標準モデル `gemma4:12b` とは応答品質や速度が変わります。
- MacBookローカル構成をLAN公開する必要が出るまで、会話サーバーは `127.0.0.1` で起動します。
