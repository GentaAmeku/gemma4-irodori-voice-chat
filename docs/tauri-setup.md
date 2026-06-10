# Tauri Setup（デスクトップアプリ化の足場）

Svelte + Vite の Web クライアントを Tauri v2 でデスクトップアプリ化するための足場です。最終形（MacBook 上のネイティブアプリで音声入力まで動かす）に向けた基盤で、既存の Web クライアントをそのまま WebView に載せます。

## 構成

- 配置: `client/src-tauri/`（Rust プロジェクト + `tauri.conf.json`）
- フロントエンド: 既存の Svelte/Vite クライアント（`client/`）をそのまま使う
  - `frontendDist`: `../dist`（`vite build` の出力）
  - `devUrl`: `http://127.0.0.1:5173`（`vite --host 127.0.0.1` の dev サーバー）
  - `beforeDevCommand`: `pnpm dev` / `beforeBuildCommand`: `pnpm build`
- アプリ名 / 識別子: productName `Irodori Chat` / identifier `com.gentaameku.irodorichat`
- ウィンドウ既定: 1120×760（最小 640×560）

## 前提（macOS）

- Rust ツールチェーン（`rustup` / `cargo`）
- Xcode Command Line Tools
- Node / pnpm

`pnpm exec tauri info` で環境を確認できます。

## 実行

開発（ネイティブウィンドウで Vite dev を表示。初回は Rust 依存のコンパイルで数分かかる）:

```sh
cd client
pnpm tauri dev
```

配布ビルド（`.app` / `.dmg`）:

```sh
cd client
pnpm tauri build
```

## 会話サーバーとの関係

クライアントの接続先（`VITE_GIC_DEFAULT_BASE_URL` または画面の接続先設定）はそのまま使えます。Tauri アプリも同一 LAN 内のデスクトップ PC 上の会話サーバーへ接続します（[ADR 0001](./adr/0001-thin-client-conversation-server.md) のクライアント境界をそのまま維持）。

## 音声入力との関係（重要）

Tauri の WebView はセキュアコンテキスト扱いのため、ブラウザの **Web Speech API（マイク）が動きます**。素の LAN http で配信したブラウザではマイクが無効ですが、Tauri アプリなら音声入力が使えます。これが「音声入力は最終的に Tauri（MacBook）で動かす」という方針の根拠です（[Handoff](./handoff.md) の音声入力メモ参照）。

- macOS の配布ビルドでは、マイク利用に Info.plist の `NSMicrophoneUsageDescription` 付与が必要になる場合があります（将来対応）。

## まだやっていないこと

- `pnpm tauri dev` / `pnpm tauri build` の初回実行（Rust 依存の初回コンパイルが必要なため、本足場では未実行）。実機で初回ビルドを通すのが次の確認。
- ネイティブ API を使う場合は `@tauri-apps/api` とプラグインを追加し、`src-tauri/capabilities/default.json` で権限を付与する（現状の Web クライアントは未使用）。
