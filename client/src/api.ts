export type DependencyStatus = {
  ok: boolean;
  detail?: string | null;
};

export type HealthResponse = {
  server_ok: boolean;
  ready: boolean;
  model: string;
  ollama_base_url?: string;
  tts_base_url?: string;
  mock_services: boolean;
  ollama: DependencyStatus;
  tts: DependencyStatus;
};

export type AppSettings = {
  character_name: string;
  character_prompt: string;
  read_aloud_prompt: string;
  speaker_id: string;
  speech_speed: number;
  tone_preset: TonePresetId;
  distance: number;
};

export type TonePresetId = "polite" | "friendly" | "calm" | "playful" | "senpai";

export type SpeakerOption = {
  id: string;
  label: string;
};

export type ConversationTurn = {
  user_text: string;
  assistant_text: string;
  audio_url: string;
};

export type HistoryResponse = {
  turns: ConversationTurn[];
};

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

function cleanBaseUrl(baseUrl: string): string {
  return baseUrl.replace(/\/+$/, "");
}

async function request<T>(baseUrl: string, path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${cleanBaseUrl(baseUrl)}${path}`, {
    ...init,
    headers: {
      ...(init?.body instanceof FormData ? {} : { "Content-Type": "application/json" }),
      ...init?.headers,
    },
  });
  if (!response.ok) {
    let detail = response.statusText;
    try {
      const data = (await response.json()) as { detail?: string };
      detail = data.detail ?? detail;
    } catch {
      // Keep the HTTP status text when the body is not JSON.
    }
    throw new ApiError(detail, response.status);
  }
  return (await response.json()) as T;
}

function normalizeSettings(
  settings: AppSettings | Partial<Pick<AppSettings, "speech_speed" | "tone_preset" | "distance">>,
): AppSettings {
  return {
    ...(settings as AppSettings),
    speech_speed:
      "speech_speed" in settings && typeof settings.speech_speed === "number" ? settings.speech_speed : 0.95,
    tone_preset: "tone_preset" in settings && isTonePresetId(settings.tone_preset) ? settings.tone_preset : "senpai",
    distance: "distance" in settings && typeof settings.distance === "number" ? settings.distance : 58,
  };
}

function isTonePresetId(value: unknown): value is TonePresetId {
  return value === "polite" || value === "friendly" || value === "calm" || value === "playful" || value === "senpai";
}

export const api = {
  health: (baseUrl: string) => request<HealthResponse>(baseUrl, "/api/health"),
  settings: async (baseUrl: string) => normalizeSettings(await request<AppSettings>(baseUrl, "/api/settings")),
  saveSettings: (baseUrl: string, settings: AppSettings) =>
    request<AppSettings>(baseUrl, "/api/settings", {
      method: "PUT",
      body: JSON.stringify(settings),
    }).then(normalizeSettings),
  speakers: (baseUrl: string) => request<SpeakerOption[]>(baseUrl, "/api/speakers"),
  history: (baseUrl: string) => request<HistoryResponse>(baseUrl, "/api/history"),
  clearHistory: (baseUrl: string) =>
    request<HistoryResponse>(baseUrl, "/api/history", {
      method: "DELETE",
    }),
  textTurn: (baseUrl: string, text: string, signal?: AbortSignal) =>
    request<ConversationTurn>(baseUrl, "/api/turns/text", {
      method: "POST",
      body: JSON.stringify({ text }),
      signal,
    }),
  uploadCharacterImage: (baseUrl: string, file: File) => {
    const body = new FormData();
    body.append("file", file);
    return request<{ image_url: string; filename: string }>(baseUrl, "/api/character-image", {
      method: "POST",
      body,
    });
  },
  absoluteUrl(baseUrl: string, path: string): string {
    if (path.startsWith("http://") || path.startsWith("https://")) {
      return path;
    }
    return `${cleanBaseUrl(baseUrl)}${path}`;
  },
};
