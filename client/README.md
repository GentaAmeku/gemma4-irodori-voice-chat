# Client

## Development

```sh
pnpm install
pnpm dev
```

既定の接続先は `http://192.168.3.2:8000` です。画面上の接続先入力からLAN内の会話サーバーURLに変更できます。接続に成功したURLはlocalStorageに保存され、次回起動時に優先されます。

既定値を一時的に変える場合:

```sh
VITE_GIC_DEFAULT_BASE_URL=http://127.0.0.1:8000 pnpm dev
```

## Check

```sh
pnpm check
pnpm build
pnpm test:e2e
```
