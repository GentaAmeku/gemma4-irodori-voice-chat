# Run speech-to-text on the LAN, as a separate service

音声入力の文字起こし（STT）は、ブラウザの Web Speech API ではなく、LAN内のサーバー側 faster-whisper で行う。

ブラウザの Web Speech API（SpeechRecognition）は、特に Chrome では録音音声を外部（Google）の音声認識サーバーへ送信するため、[LAN-only 方針](./0002-lan-only-conversation-server.md) と矛盾する。サーバー側 STT であれば音声データがLANの外へ出ない。

構成は既存の [thin client](./0001-thin-client-conversation-server.md) と adapters パターンに合わせ、faster-whisper は Ollama / Irodori-TTS と同様に**独立したサービス**として動かし、会話サーバーはそれをプロキシする（`POST /api/stt`、`SttClient` adapter）。重いMLモデルを thin な会話サーバープロセスへ載せない。

通信はまずバッチREST（録音停止後に音声をPOSTして一括文字起こし）とする。同期REST中心の既存ターンフローと整合し、実装が小さい。WebSocketストリーミング + サーバーVAD + 部分認識による低レイテンシ化は将来の拡張とする。

注意: ブラウザのマイク取得（`getUserMedia`）はセキュアコンテキスト（localhost / https / Tauri）を要求するため、サーバー側STTにしても素の LAN http ではマイクを使えない。サーバー側STTの利点はマイク利用可否ではなく、音声データをLAN内に閉じることにある。最終形は Tauri（セキュアコンテキスト）+ サーバーSTT で、録音から文字起こしまでLAN内で完結する。
