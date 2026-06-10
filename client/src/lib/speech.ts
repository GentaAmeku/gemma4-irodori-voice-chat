// 音声入力(マイク録音 → サーバーSTT)のヘルパー。
//
// 録音はブラウザの MediaRecorder で行い、録音データを会話サーバーの /api/stt へ送って
// faster-whisper で文字起こしする。音声はLAN内で処理され、外部の音声認識サービスへは送らない
// (ADR 0004)。
//
// マイク取得(getUserMedia)と MediaRecorder はセキュアコンテキスト(localhost / https / Tauri)が
// 必要。LAN の http で配信した場合は使えないため、必ず isMicCaptureSupported() で機能検出してから
// 使い、未対応時はマイクを無効化する。

export type MicRecording = {
  blob: Blob;
  filename: string;
};

export type MicRecorder = {
  // 録音を止め、録音データ(Blob)とファイル名を返す。マイクも解放する。
  stop(): Promise<MicRecording>;
  // 録音を破棄してマイクを解放する(送信しない)。
  cancel(): void;
};

export function isMicCaptureSupported(): boolean {
  if (typeof window === "undefined") {
    return false;
  }
  // セキュアコンテキスト(localhost / https / Tauri)でないと getUserMedia は使えない。
  if (window.isSecureContext === false) {
    return false;
  }
  return (
    typeof navigator !== "undefined" &&
    navigator.mediaDevices != null &&
    typeof navigator.mediaDevices.getUserMedia === "function" &&
    typeof window.MediaRecorder === "function"
  );
}

// 対応する MediaRecorder の mimeType と拡張子を選ぶ。faster-whisper(ffmpeg/av)側で
// webm/opus・ogg・mp4 いずれもデコードできる。
function pickMimeType(): { mimeType: string; ext: string } {
  const candidates = [
    { mimeType: "audio/webm;codecs=opus", ext: "webm" },
    { mimeType: "audio/webm", ext: "webm" },
    { mimeType: "audio/ogg;codecs=opus", ext: "ogg" },
    { mimeType: "audio/mp4", ext: "mp4" },
  ];
  if (typeof MediaRecorder.isTypeSupported === "function") {
    for (const candidate of candidates) {
      if (MediaRecorder.isTypeSupported(candidate.mimeType)) {
        return candidate;
      }
    }
  }
  // ブラウザ既定に任せる(Safari 等)。
  return { mimeType: "", ext: "webm" };
}

export async function startMicRecording(): Promise<MicRecorder> {
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  const { mimeType, ext } = pickMimeType();
  const recorder = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);
  const chunks: BlobPart[] = [];
  recorder.ondataavailable = (event) => {
    if (event.data && event.data.size > 0) {
      chunks.push(event.data);
    }
  };
  recorder.start();

  const releaseStream = () => {
    for (const track of stream.getTracks()) {
      track.stop();
    }
  };

  return {
    stop() {
      return new Promise<MicRecording>((resolve, reject) => {
        recorder.onstop = () => {
          releaseStream();
          const rawType = recorder.mimeType || mimeType || "audio/webm";
          const type = rawType.split(";", 1)[0];
          resolve({ blob: new Blob(chunks, { type }), filename: `speech.${ext}` });
        };
        recorder.onerror = () => {
          releaseStream();
          reject(new Error("recording_failed"));
        };
        try {
          recorder.stop();
        } catch (error) {
          releaseStream();
          reject(error instanceof Error ? error : new Error("recording_failed"));
        }
      });
    },
    cancel() {
      recorder.ondataavailable = null;
      try {
        recorder.stop();
      } catch {
        // 既に停止済みなどは無視する。
      }
      releaseStream();
    },
  };
}

// getUserMedia / 録音開始時のエラーを日本語の案内に変換する。
export function micErrorMessage(error: unknown): string {
  const name = error instanceof DOMException ? error.name : "";
  switch (name) {
    case "NotAllowedError":
    case "SecurityError":
      return "マイクの使用が許可されていません。ブラウザのマイク権限を確認してください。";
    case "NotFoundError":
    case "DevicesNotFoundError":
      return "マイクが見つかりません。デバイスを確認してください。";
    case "NotReadableError":
      return "マイクにアクセスできませんでした。他のアプリが使用中でないか確認してください。";
    default:
      return "音声入力でエラーが発生しました。";
  }
}
