---
name: start-stack
description: 実行環境（Mac か WSL か）を判別して Ollama / Irodori-TTS-Server / 会話サーバー / クライアントを起動し、check スクリプトで疎通確認する。「スタックを起動して」「アプリを動かして」「サーバー一式立ち上げて」と言われたときに使う。
---

# スタック起動（start-stack）

このリポジトリの実行スタック（Ollama / Irodori-TTS-Server / 会話サーバー / Web クライアント）を起動し、疎通確認まで行う。スクリプトの詳細は `docs/scripts-and-startup.md` を参照。

## 1. 環境を判別する

```sh
uname -s                      # Darwin → MacBook ローカル構成
grep -qi microsoft /proc/version 2>/dev/null && echo WSL   # WSL → 推論PC構成
```

## 2-A. MacBook ローカル構成（Darwin）

1. 前提確認: `command -v ollama uv pnpm` と `ollama list | grep e4b-mlx`
2. `../Irodori-TTS-Server` が無ければ初回のみ: `./scripts/mac/setup-irodori-mac.sh`
3. Ollama + Irodori をバックグランド起動: `./scripts/mac/start-inference-stack-mac.sh`
4. 会話サーバーを起動（フォアグラウンドのため **バックグラウンド実行で起動する**）: `./scripts/mac/start-conversation-server-mac.sh`
5. クライアントを起動（同じくバックグラウンド実行）: `./scripts/mac/start-client-mac.sh`
6. 疎通確認: `./scripts/mac/check-mac-stack.sh`

## 2-B. 推論PC / WSL 構成（WSL）

1. 前提確認: Windows 側 Ollama に WSL から届くか `curl -fsS http://127.0.0.1:11434/api/tags`（だめなら `ip route show default` のゲートウェイ IP で再試行）
2. `../Irodori-TTS-Server` が無ければ初回のみ: `./scripts/wsl/setup-irodori-wsl-amd.sh`
3. 一括起動（Irodori + portproxy refresh + 会話サーバー。フォアグラウンドのため **バックグラウンド実行で起動する**）: `./scripts/wsl/start-desktop-stack.sh`
4. クライアントも同じ PC で使う場合（バックグラウンド実行）: `./scripts/wsl/start-client-wsl.sh` → Windows のブラウザで `http://localhost:5173`
5. 疎通確認: `./scripts/wsl/check-wsl-stack.sh`

## 注意

- すでに起動済みのサービスは二重起動しない（各スクリプトが health を見て自動でスキップする）。
- Ollama がこのプロジェクトの起動前から動いていた場合、ユーザーの明示がない限り停止しない。
- ログと PID は `.logs/` に置かれる。失敗時はまず該当ログの末尾を確認する。
- Irodori の初回起動・初回読み上げはモデルロードで数分かかることがある（仕様）。

## 報告形式

起動した（またはスキップした）プロセスと、check スクリプトの結果（会話サーバー / Ollama / Irodori の health、サンプル会話ターンの成否）を報告する。クライアントを起動した場合は開くべき URL も伝える。
