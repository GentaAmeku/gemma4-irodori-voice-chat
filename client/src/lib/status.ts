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
  ];
}
