// 音声入力(ブラウザの Web Speech API / SpeechRecognition)のヘルパー。
//
// SpeechRecognition は Baseline 外の機能。Chrome/Edge/Safari は webkit プレフィックス付き、
// Firefox は非対応。将来 Tauri の WebView で動かす場合も利用できないことがあるため、
// 必ず機能検出(isSpeechRecognitionSupported)してから使い、未対応時はマイクを無効化する。

// 標準の lib.dom には SpeechRecognition 本体・イベント型が無いため、使う分だけ補う。
// (SpeechRecognitionResult / -ResultList / -Alternative は lib.dom に存在するため再定義しない)
declare global {
  interface SpeechRecognitionEvent extends Event {
    readonly resultIndex: number;
    readonly results: SpeechRecognitionResultList;
  }

  interface SpeechRecognitionErrorEvent extends Event {
    readonly error: string;
    readonly message: string;
  }

  interface SpeechRecognition extends EventTarget {
    lang: string;
    continuous: boolean;
    interimResults: boolean;
    maxAlternatives: number;
    start(): void;
    stop(): void;
    abort(): void;
    onstart: ((event: Event) => void) | null;
    onresult: ((event: SpeechRecognitionEvent) => void) | null;
    onerror: ((event: SpeechRecognitionErrorEvent) => void) | null;
    onend: ((event: Event) => void) | null;
  }

  type SpeechRecognitionConstructor = {
    prototype: SpeechRecognition;
    new (): SpeechRecognition;
  };

  interface Window {
    SpeechRecognition?: SpeechRecognitionConstructor;
    webkitSpeechRecognition?: SpeechRecognitionConstructor;
  }
}

function getConstructor(): SpeechRecognitionConstructor | null {
  if (typeof window === "undefined") {
    return null;
  }
  return window.SpeechRecognition ?? window.webkitSpeechRecognition ?? null;
}

export function isSpeechRecognitionSupported(): boolean {
  if (getConstructor() === null) {
    return false;
  }
  // SpeechRecognition はセキュアコンテキスト(localhost / https / Tauri)が必要。
  // LAN の http で配信した場合は start() が失敗するため、ここで弾く。
  return typeof window === "undefined" || window.isSecureContext !== false;
}

export function createSpeechRecognition(lang: string): SpeechRecognition | null {
  const Constructor = getConstructor();
  if (!Constructor) {
    return null;
  }
  const recognition = new Constructor();
  recognition.lang = lang;
  recognition.continuous = true;
  recognition.interimResults = true;
  recognition.maxAlternatives = 1;
  return recognition;
}

// SpeechRecognition のエラーコードを日本語の案内に変換する。
// 空文字を返した場合はユーザーへの通知不要(ユーザー操作による中断など)。
export function speechErrorMessage(error: string): string {
  switch (error) {
    case "not-allowed":
    case "service-not-allowed":
      return "マイクの使用が許可されていません。ブラウザのマイク権限を確認してください。";
    case "no-speech":
      return "音声を聞き取れませんでした。もう一度お試しください。";
    case "audio-capture":
      return "マイクが見つかりません。デバイスを確認してください。";
    case "network":
      return "音声認識サービスに接続できませんでした。";
    case "aborted":
      return "";
    default:
      return `音声入力でエラーが発生しました (${error})。`;
  }
}
