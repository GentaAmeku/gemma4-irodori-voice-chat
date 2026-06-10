// クライアントローカルの会話プリファレンス。
// 口調・距離感・話す速さは将来機能のためのUIで、会話サーバーへはまだ送られない。
// 自動読み上げのみクライアント側で実際に効く。

export type TonePreset = {
  id: string;
  label: string;
  sample: string;
};

export const TONE_PRESETS: TonePreset[] = [
  { id: "polite", label: "丁寧", sample: "承知しました。お手伝いしますね。" },
  { id: "friendly", label: "フレンドリー", sample: "いいね！ぜひやってみよう。" },
  { id: "calm", label: "落ち着き", sample: "大丈夫、ゆっくりで構いませんよ。" },
  { id: "playful", label: "ちょっと甘え", sample: "ねえ、もう少しだけ話さない…？" },
];

export type LocalPrefs = {
  tone: string;
  distance: number;
  speed: number;
  autoplay: boolean;
};

export const DEFAULT_PREFS: LocalPrefs = {
  tone: "calm",
  distance: 40,
  speed: 1.0,
  autoplay: true,
};

const STORAGE_KEY = "gemma4-irodori-chat.local-prefs";

export function loadPrefs(): LocalPrefs {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return { ...DEFAULT_PREFS };
    }
    const parsed = JSON.parse(raw) as Partial<LocalPrefs>;
    return {
      tone: typeof parsed.tone === "string" ? parsed.tone : DEFAULT_PREFS.tone,
      distance: typeof parsed.distance === "number" ? parsed.distance : DEFAULT_PREFS.distance,
      speed: typeof parsed.speed === "number" ? parsed.speed : DEFAULT_PREFS.speed,
      autoplay: typeof parsed.autoplay === "boolean" ? parsed.autoplay : DEFAULT_PREFS.autoplay,
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
