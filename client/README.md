# Client

## Development

```sh
pnpm install
pnpm dev
```

既定の接続先は `http://127.0.0.1:8000` です。LAN内の推論PCへ接続する場合は、画面上の接続先入力から会話サーバーURL（例: `http://192.168.0.10:8000`）に変更します。接続に成功したURLはlocalStorageに保存され、次回起動時に優先されます。

既定値自体を変えたい場合は、`client/.env.example` を参考に `client/.env.local`（git管理外）を作成します。

```sh
VITE_GIC_DEFAULT_BASE_URL=http://192.168.0.10:8000
```

`pnpm dev` 起動中に `.env.local` を変更した場合は、Viteを再起動してください。

既定値を一時的に変える場合は、コマンドの環境変数が使えます。

```sh
VITE_GIC_DEFAULT_BASE_URL=http://127.0.0.1:8000 pnpm dev
```

MacBookローカル構成では、Windows推論PC接続用の保存値と分けるために専用スクリプトを使います。

```sh
../scripts/mac/start-client-mac.sh
```

## Check

```sh
pnpm check
pnpm build
pnpm test:e2e
```
