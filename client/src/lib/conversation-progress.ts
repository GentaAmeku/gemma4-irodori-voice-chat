export type ConversationStage = "thinking" | "synthesizing";
export type ConversationTransport = "rest" | "job" | "websocket";

type ActiveConversationBase = {
  turnId: string;
  stage: ConversationStage;
  stageTimer: number | null;
};

export type RestConversation = ActiveConversationBase & {
  transport: "rest";
  abortController: AbortController;
};

export type JobConversation = ActiveConversationBase & {
  transport: "job";
  jobId: string;
};

export type WebSocketConversation = ActiveConversationBase & {
  transport: "websocket";
  sessionId: string;
};

export type ActiveConversation = RestConversation | JobConversation | WebSocketConversation;

export const SYNTHESIZING_HINT_DELAY_MS = 12_000;
