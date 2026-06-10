import type { HealthResponse } from "../api";

export type DisplayState = "disconnected" | "connecting" | "ready" | "conversing" | "error";

export type StatusItem = {
  label: string;
  state: "ok" | "error" | "unknown";
  detail: string;
};

export const DISPLAY_LABELS: Record<DisplayState, string> = {
  disconnected: "未接続",
  connecting: "接続中",
  ready: "利用可能",
  conversing: "会話中",
  error: "エラー",
};

export function buildStatusItems(
  health: HealthResponse | null,
  displayState: DisplayState,
  baseUrl: string,
): StatusItem[] {
  if (!health) {
    return [
      { label: "会話サーバー", state: displayState === "connecting" ? "unknown" : "error", detail: baseUrl },
      { label: "Ollama", state: "unknown", detail: "未確認" },
      { label: "irodori-TTS", state: "unknown", detail: "未確認" },
      { label: "音声入力STT", state: "unknown", detail: "未確認" },
    ];
  }
  return [
    { label: "会話サーバー", state: health.server_ok ? "ok" : "error", detail: baseUrl },
    {
      label: "Ollama",
      state: health.ollama.ok ? "ok" : "error",
      detail: health.ollama.ok
        ? `${health.model} / ${health.ollama_base_url ?? "接続済み"}`
        : (health.ollama.detail ?? "利用できません"),
    },
    {
      label: "irodori-TTS",
      state: health.tts.ok ? "ok" : "error",
      detail: health.tts.ok ? (health.tts_base_url ?? "接続済み") : (health.tts.detail ?? "利用できません"),
    },
    {
      // 音声入力専用。テキスト会話には不要なため、未接続でも会話の可否には影響しない。
      // 未更新の会話サーバーは stt を返さないため、その場合は未確認扱いにする。
      label: "音声入力STT",
      state: health.stt ? (health.stt.ok ? "ok" : "error") : "unknown",
      detail: health.stt
        ? health.stt.ok
          ? (health.stt_base_url ?? "接続済み")
          : (health.stt.detail ?? "音声入力は任意です")
        : "未確認（サーバー未対応の可能性）",
    },
  ];
}
