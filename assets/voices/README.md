# assets/voices

Irodori-TTS-Server に登録する参照音声を置くディレクトリです。

ここに置いた音声ファイルは、セットアップスクリプト
(`scripts/wsl/setup-irodori-wsl-amd.sh` / `scripts/mac/setup-irodori-mac.sh`)
の実行時に `../Irodori-TTS-Server/voices/` へコピーされ、
ファイル名(拡張子を除く)がそのまま話者IDになります。

例: `rena.wav` → 話者ID `rena`

## ルール

- 対応拡張子: `.wav` `.flac` `.mp3` `.m4a` `.ogg` `.opus` `.aac` `.webm`
- ファイル名(話者ID)はASCII英数字・`_`・`-` のみ
- 長さは10〜30秒を推奨([VoiceDesign Sample Setup](../../docs/voicedesign-sample-setup.md)参照)
- コピーは「存在しない場合のみ」。Irodori側で差し替えた音声は上書きされない
- このリポジトリは公開リポジトリなので、実在の人物の録音は置かない。
  VoiceDesignで生成した合成音声のみを置くこと
