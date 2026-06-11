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

クライアントの接続先（`VITE_GIC_DEFAULT_BASE_URL` または画面の接続先設定）はそのまま使えます。Tauri アプリも同一 LAN 内の推論PC上の会話サーバーへ接続します（[ADR 0001](./adr/0001-thin-client-conversation-server.md) のクライアント境界をそのまま維持）。

## 音声入力との関係（重要）

Tauri の WebView はセキュアコンテキスト扱いのため、ブラウザの **Web Speech API（マイク）が動きます**。素の LAN http で配信したブラウザではマイクが無効ですが、Tauri アプリなら音声入力が使えます。これが「音声入力は最終的に Tauri（MacBook）で動かす」という方針の根拠です（音声入力の流れは [Architecture Overview](./architecture.md) を参照）。

- macOS の配布ビルドでは、マイク利用に Info.plist の `NSMicrophoneUsageDescription` 付与が必要になる場合があります（将来対応）。

## まだやっていないこと

- `pnpm tauri dev` / `pnpm tauri build` の初回実行（Rust 依存の初回コンパイルが必要なため、本足場では未実行）。実機で初回ビルドを通すのが次の確認。
- ネイティブ API を使う場合は `@tauri-apps/api` とプラグインを追加し、`src-tauri/capabilities/default.json` で権限を付与する（現状の Web クライアントは未使用）。

## 事前調査メモ: 初回ビルド前に知っておく懸念点（2026-06 調査）

ビルド自体は最後の工程として後回しにし、円滑に進むよう先に調査した結果。足場（設定・アイコン・identifier）は揃っており、ビルドを止める不備はない。懸念は以下の3点。

### 1. 【最重要】製品ビルドでの平文 http 接続が WebKit にブロックされる可能性

macOS の WKWebView は、セキュアな origin から `http://`（平文）への接続をブロックする既知の制限がある（[tauri#5451](https://github.com/tauri-apps/tauri/issues/5451)、上流の [WebKit bug 171934](https://bugs.webkit.org/show_bug.cgi?id=171934)）。

- **開発（`pnpm tauri dev`）**: origin が `http://127.0.0.1:5173` のため mixed content 規制がかからず、`http://<推論PCのIP>:8000` への接続も音声入力も動く見込み。
- **製品ビルド（`pnpm tauri build`）**: origin が `tauri://localhost`（セキュア扱い）になるため、会話サーバーへの平文 http fetch がブロックされる可能性がある。**ビルド後に最初に確認すべき項目**。
- ブロックされた場合の対策: [`@tauri-apps/plugin-http`](https://v2.tauri.app/reference/javascript/http/) を導入し、Tauri 実行時だけ `fetch` を plugin 版に差し替える（Rust 側で HTTP するため WebView の mixed content 規制を受けない）。`client/src/api.ts` の fetch 呼び出しが差し替えポイント。

### 2. 音声入力（SpeechRecognition）はmacOSで Info.plist の権限記述が必要

WKWebView でも Web Speech API は動くが、認識（マイク）には Info.plist の利用目的記述が要る（[tauri discussion#13460](https://github.com/tauri-apps/tauri/discussions/13460)、[tauri#6208](https://github.com/tauri-apps/tauri/issues/6208)）。

- `src-tauri/Info.plist` を作成して `NSMicrophoneUsageDescription`（および `NSSpeechRecognitionUsageDescription`）を記述する（Tauri v2 はビルド時に自動マージする）。
- なお Linux（WebKitGTK）では認識が未サポート。最終ターゲットは macOS なので影響なし。Windows（WebView2）は追加設定不要。

### 3. CSP が `null`

現状 `tauri.conf.json` の `app.security.csp` は `null`（無制限）。動作確認を優先するならこのままでよいが、配布を考えるなら `connect-src` に会話サーバーの接続先を許可した CSP を設定するのが望ましい（その場合、接続先が可変である点と plugin-http 利用時の挙動も合わせて確認する）。

### ビルド時の確認手順（推奨順）

1. `pnpm tauri dev` で起動し、LAN の会話サーバー接続と音声入力を確認（ここはおそらく素直に動く）
2. `src-tauri/Info.plist` にマイク権限を追加してから `pnpm tauri build`
3. ビルド版で `http://<推論PCのIP>:8000` への接続を確認。ブロックされたら plugin-http を導入
4. 音声入力（マイク許可ダイアログ → 認識）を確認
