// クライアントローカルの会話プリファレンス。
// 自動読み上げのみクライアント側で扱う。口調・距離感・話す速さはサーバー設定で扱う。

import type { TonePresetId } from "../api";

export type TonePreset = {
  id: TonePresetId;
  label: string;
  sample: string;
};

export const TONE_PRESETS: TonePreset[] = [
  { id: "polite", label: "丁寧", sample: "承知しました。お手伝いしますね。" },
  { id: "friendly", label: "フレンドリー", sample: "いいね！ぜひやってみよう。" },
  { id: "calm", label: "落ち着き", sample: "大丈夫、ゆっくりで構いませんよ。" },
  { id: "playful", label: "ちょっと甘え", sample: "ねえ、もう少しだけ話さない…？" },
  { id: "senpai", label: "先輩", sample: "無理しなくていい。今は、できることを一つだけ片付けよう。" },
];

export type LocalPrefs = {
  autoplay: boolean;
  // 読み上げの再生音量 (0–1)。クライアント側の audio.volume に反映する。
  volume: number;
};

export const DEFAULT_PREFS: LocalPrefs = {
  autoplay: true,
  volume: 0.5,
};

const STORAGE_KEY = "gemma4-irodori-chat.local-prefs";

function clampVolume(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_PREFS.volume;
  }
  return Math.min(1, Math.max(0, value));
}

export function loadPrefs(): LocalPrefs {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return { ...DEFAULT_PREFS };
    }
    const parsed = JSON.parse(raw) as Partial<LocalPrefs>;
    return {
      autoplay: typeof parsed.autoplay === "boolean" ? parsed.autoplay : DEFAULT_PREFS.autoplay,
      volume: clampVolume(parsed.volume),
    };
  } catch {
    return { ...DEFAULT_PREFS };
  }
}

export function savePrefs(prefs: LocalPrefs): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
  } catch {
    // localStorage が使えない環境では保存をあきらめる
  }
}
