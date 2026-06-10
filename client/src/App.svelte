<script lang="ts">
  import { onMount } from "svelte";
  import {
    api,
    ApiError,
    type AppSettings,
    type ConversationTurn,
    type HealthResponse,
    type SpeakerOption,
  } from "./api";
  import { buildStatusItems, DISPLAY_LABELS, type DisplayState } from "./lib/status";
  import { SYNTHESIZING_HINT_DELAY_MS, type ActiveConversation } from "./lib/conversation-progress";
  import { loadPrefs, savePrefs } from "./lib/prefs";
  import AudioChip from "./lib/AudioChip.svelte";
  import CharacterRail from "./lib/CharacterRail.svelte";
  import Icon from "./lib/Icon.svelte";
  import SettingsPanel from "./lib/SettingsPanel.svelte";
  import StatusDot from "./lib/StatusDot.svelte";
  import TypingIndicator from "./lib/TypingIndicator.svelte";

  type DisplayTurn = ConversationTurn & {
    id: string;
    state: "complete" | "pending" | "error";
    errorMessage?: string;
  };

  const savedBaseUrl = import.meta.env.VITE_GIC_BASE_URL_STORAGE_KEY ?? "gemma4-irodori-chat.base-url";
  const legacyDefaultBaseUrl = "http://127.0.0.1:8000";
  const defaultBaseUrl = import.meta.env.VITE_GIC_DEFAULT_BASE_URL ?? "http://192.168.3.2:8000";
  const storedBaseUrl = localStorage.getItem(savedBaseUrl);
  const initialBaseUrl = storedBaseUrl && storedBaseUrl !== legacyDefaultBaseUrl ? storedBaseUrl : defaultBaseUrl;

  let baseUrl = $state(initialBaseUrl);
  let draftBaseUrl = $state(initialBaseUrl);
  let displayState = $state<DisplayState>("disconnected");
  let health = $state<HealthResponse | null>(null);
  let settings = $state<AppSettings | null>(null);
  let settingsDraft = $state<AppSettings | null>(null);
  let speakers = $state<SpeakerOption[]>([]);
  let turns = $state<DisplayTurn[]>([]);
  let textInput = $state("");
  let errorMessage = $state("");
  let statusMessage = $state("");
  let settingsOpen = $state(false);
  let imageVersion = $state(Date.now());
  let imageMissing = $state(false);
  let freshId = $state<string | null>(null);
  let autoplayId = $state<string | null>(null);
  let prefs = $state(loadPrefs());
  let savingSettings = $state(false);
  let connecting = $state(false);
  let clearingHistory = $state(false);
  let uploadingImage = $state(false);
  let activeConversation = $state<ActiveConversation | null>(null);

  let threadEl = $state<HTMLDivElement>();
  let textareaEl = $state<HTMLTextAreaElement>();

  const characterName = $derived(settings?.character_name ?? "リノン");
  const canConverse = $derived(displayState === "ready" && textInput.trim().length > 0);
  const characterImageUrl = $derived(`${baseUrl.replace(/\/+$/, "")}/api/character-image?v=${imageVersion}`);
  const statusItems = $derived(buildStatusItems(health, displayState, baseUrl));
  const allOk = $derived(health !== null && health.server_ok && health.ollama.ok && health.tts.ok);
  const dotState = $derived.by(() => {
    if (displayState === "ready" || displayState === "conversing") return "ok" as const;
    if (displayState === "connecting") return "warn" as const;
    if (displayState === "error") return "err" as const;
    return "unknown" as const;
  });
  const dotLive = $derived(displayState === "ready" || displayState === "conversing");
  const connectionHelp = $derived(
    isLocalConnection(draftBaseUrl)
      ? "MacBookローカル構成では、このMac上の会話サーバーに接続します。"
      : "MacBookからはdesktop PC上の会話サーバーを指定します。例: http://<desktop-pc-lan-ip>:8000",
  );
  const conversationStage = $derived(activeConversation?.stage ?? null);
  const pendingLabel = $derived(
    conversationStage === "synthesizing" ? `${characterName}が読み上げ準備中…` : `${characterName}が返答生成中…`,
  );

  onMount(() => {
    void connect();
  });

  // ローカルプリファレンスは変更のたびに保存する
  $effect(() => {
    savePrefs({ ...prefs });
  });

  // 会話ターンの追加・更新でスレッドを最下部へ
  $effect(() => {
    void turns.length;
    void turns.at(-1)?.state;
    if (threadEl) {
      threadEl.scrollTop = threadEl.scrollHeight;
    }
  });

  async function connect() {
    if (connecting) {
      return;
    }
    connecting = true;
    displayState = "connecting";
    errorMessage = "";
    statusMessage = "";
    baseUrl = draftBaseUrl.trim().replace(/\/+$/, "") || defaultBaseUrl;
    try {
      const [nextHealth, nextSettings, nextSpeakers, history] = await Promise.all([
        api.health(baseUrl),
        api.settings(baseUrl),
        api.speakers(baseUrl),
        api.history(baseUrl),
      ]);
      health = nextHealth;
      settings = nextSettings;
      settingsDraft = { ...nextSettings };
      speakers = nextSpeakers;
      turns = history.turns.map((turn, index) => toDisplayTurn(turn, `history-${index}`));
      imageMissing = false;
      imageVersion = Date.now();
      displayState = nextHealth.ready ? "ready" : "error";
      if (!nextHealth.ready) {
        errorMessage = dependencyMessage(nextHealth);
      } else {
        localStorage.setItem(savedBaseUrl, baseUrl);
        draftBaseUrl = baseUrl;
        statusMessage = "接続しました";
      }
    } catch (error) {
      displayState = "error";
      errorMessage = formatError(error);
    } finally {
      connecting = false;
    }
  }

  async function sendTextTurn() {
    const text = textInput.trim();
    if (!text || displayState !== "ready") {
      return;
    }
    displayState = "conversing";
    errorMessage = "";
    statusMessage = `${characterName}が返答生成中`;
    textInput = "";
    resetComposerHeight();
    const pendingId = createTurnId();
    const pendingTurn: DisplayTurn = {
      id: pendingId,
      state: "pending",
      user_text: text,
      assistant_text: "",
      audio_url: "",
    };
    turns = [...turns, pendingTurn];
    freshId = pendingId;
    const abortController = new AbortController();
    activeConversation = {
      turnId: pendingId,
      transport: "rest",
      stage: "thinking",
      stageTimer: null,
      abortController,
    };
    startConversationStageTimer(pendingId);
    try {
      const turn = await api.textTurn(baseUrl, text, abortController.signal);
      if (!isActiveConversation(pendingId)) {
        return;
      }
      turns = turns.map((existing) => (existing.id === pendingId ? toDisplayTurn(turn, pendingId) : existing));
      autoplayId = prefs.autoplay ? pendingId : null;
      displayState = "ready";
      clearActiveConversation();
      statusMessage = "";
    } catch (error) {
      if (isAbortError(error)) {
        return;
      }
      const nextErrorMessage = formatError(error);
      turns = turns.map((existing) =>
        existing.id === pendingId ? { ...existing, state: "error", errorMessage: nextErrorMessage } : existing,
      );
      displayState = "ready";
      clearActiveConversation();
      errorMessage = nextErrorMessage;
      statusMessage = "返答に失敗しました";
    } finally {
      if (isActiveConversation(pendingId)) {
        clearActiveConversation();
      }
    }
  }

  function cancelTextTurn() {
    if (displayState !== "conversing" || !activeConversation) {
      return;
    }
    const cancelledId = activeConversation.turnId;
    cancelActiveConversation(activeConversation);
    clearActiveConversation();
    turns = turns.filter((turn) => turn.id !== cancelledId);
    displayState = "ready";
    errorMessage = "";
    statusMessage = "キャンセルしました";
  }

  async function saveSettings() {
    if (!settingsDraft || savingSettings) {
      return;
    }
    savingSettings = true;
    try {
      const saved = await api.saveSettings(baseUrl, settingsDraft);
      settings = saved;
      settingsDraft = { ...saved };
      turns = [];
      errorMessage = "";
      statusMessage = "設定を保存しました";
    } catch (error) {
      errorMessage = formatError(error);
    } finally {
      savingSettings = false;
    }
  }

  async function clearHistory() {
    if (clearingHistory) {
      return;
    }
    clearingHistory = true;
    try {
      await api.clearHistory(baseUrl);
      turns = [];
      errorMessage = "";
      statusMessage = "履歴をクリアしました";
    } catch (error) {
      errorMessage = formatError(error);
    } finally {
      clearingHistory = false;
    }
  }

  async function uploadImage(file: File) {
    if (uploadingImage) {
      return;
    }
    uploadingImage = true;
    try {
      await api.uploadCharacterImage(baseUrl, file);
      imageMissing = false;
      imageVersion = Date.now();
      statusMessage = "キャラクター画像を更新しました";
    } catch (error) {
      errorMessage = formatError(error);
    } finally {
      uploadingImage = false;
    }
  }

  function onComposerKeydown(event: KeyboardEvent) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault();
      void sendTextTurn();
    }
  }

  // field-sizing 非対応ブラウザ (Firefox) 向けの自動伸長フォールバック
  function autoGrow(event: Event) {
    if (CSS.supports("field-sizing", "content")) {
      return;
    }
    const el = event.currentTarget as HTMLTextAreaElement;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 140)}px`;
  }

  function resetComposerHeight() {
    if (textareaEl && !CSS.supports("field-sizing", "content")) {
      textareaEl.style.height = "auto";
    }
  }

  function onAutoplayFail() {
    statusMessage = "自動再生できませんでした。メッセージの再生ボタンから再生してください。";
  }

  function startConversationStageTimer(turnId: string) {
    clearConversationStageTimer();
    const stageTimer = window.setTimeout(() => {
      if (displayState === "conversing" && isActiveConversation(turnId) && activeConversation) {
        activeConversation = { ...activeConversation, stage: "synthesizing", stageTimer: null };
        statusMessage = `${characterName}が読み上げ準備中`;
      }
    }, SYNTHESIZING_HINT_DELAY_MS);
    if (isActiveConversation(turnId) && activeConversation) {
      activeConversation = { ...activeConversation, stageTimer };
    }
  }

  function clearConversationStageTimer() {
    if (activeConversation?.stageTimer !== null && activeConversation?.stageTimer !== undefined) {
      window.clearTimeout(activeConversation.stageTimer);
      activeConversation = { ...activeConversation, stageTimer: null };
    }
  }

  function clearActiveConversation() {
    if (activeConversation?.stageTimer !== null && activeConversation?.stageTimer !== undefined) {
      window.clearTimeout(activeConversation.stageTimer);
    }
    activeConversation = null;
  }

  function isActiveConversation(turnId: string): boolean {
    return activeConversation?.turnId === turnId;
  }

  function cancelActiveConversation(conversation: ActiveConversation) {
    if (conversation.transport === "rest") {
      conversation.abortController.abort();
    }
  }

  function formatError(error: unknown): string {
    if (error instanceof ApiError) {
      if (error.status === 409) {
        return "会話中です。少し待ってから再入力してください。";
      }
      if (error.status === 504 || /timeout|timed out|読み上げ|tts/i.test(error.message)) {
        return `TTS生成または応答生成がタイムアウトしました。MacBookローカルの初回生成では時間がかかることがあります。詳細: ${error.message}`;
      }
      return `${error.status}: ${error.message}`;
    }
    if (error instanceof Error) {
      if (error.message === "Failed to fetch" || error.message === "Load failed") {
        return "会話サーバーに接続できません。接続先URL、desktop PCのIP、Windowsファイアウォール、WSLのポート公開を確認してください。";
      }
      return error.message;
    }
    return "不明なエラーが発生しました";
  }

  function isAbortError(error: unknown): boolean {
    return error instanceof Error && error.name === "AbortError";
  }

  function dependencyMessage(nextHealth: HealthResponse): string {
    const errors = [];
    if (!nextHealth.server_ok) {
      errors.push("会話サーバーが利用可能状態ではありません");
    }
    if (!nextHealth.ollama.ok) {
      errors.push(`Ollamaに接続できません: ${nextHealth.ollama.detail ?? "利用できません"}`);
    }
    if (!nextHealth.tts.ok) {
      errors.push(`irodori-TTSに接続できません: ${nextHealth.tts.detail ?? "利用できません"}`);
    }
    return errors.join(" / ") || "会話サーバーは応答しましたが、利用可能状態ではありません";
  }

  function toDisplayTurn(turn: ConversationTurn, id = createTurnId()): DisplayTurn {
    return {
      ...turn,
      id,
      state: "complete",
    };
  }

  function createTurnId(): string {
    return globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  function isLocalConnection(value: string): boolean {
    try {
      const url = new URL(value);
      return ["127.0.0.1", "localhost", "::1"].includes(url.hostname);
    } catch {
      return false;
    }
  }
</script>

<svelte:head>
  <title>Gemma4 Irodori Chat</title>
</svelte:head>

<main class="app">
  <CharacterRail
    name={characterName}
    model={health?.model ?? null}
    mock={health?.mock_services ?? false}
    prompt={settings?.character_prompt ?? ""}
    imageUrl={characterImageUrl}
    {imageMissing}
    stateLabel={DISPLAY_LABELS[displayState]}
    {dotState}
    live={dotLive}
    {allOk}
    onOpenSettings={() => (settingsOpen = true)}
    onImageError={() => (imageMissing = true)}
  />

  <section class="convo" aria-label="会話">
    <header class="convo-head">
      {#if imageMissing}
        <span class="mini-avatar" aria-hidden="true"></span>
      {:else}
        <img class="mini-avatar" src={characterImageUrl} alt="" onerror={() => (imageMissing = true)} />
      {/if}
      <div>
        <div class="title">{characterName}</div>
        <div class="sub" aria-live="polite">
          <StatusDot state={dotState} live={dotLive} />
          {statusMessage || DISPLAY_LABELS[displayState]}
        </div>
      </div>
      <span class="spacer"></span>
      <button type="button" class="icon-btn head-gear" aria-label="設定" onclick={() => (settingsOpen = true)}>
        <Icon name="gear" />
      </button>
    </header>

    {#if errorMessage}
      <p class="alertline" role="alert">{errorMessage}</p>
    {/if}

    <div class="thread" bind:this={threadEl} aria-label="会話履歴">
      {#if turns.length === 0}
        <p class="empty-history">まだ会話はありません。</p>
      {:else}
        {#each turns as turn (turn.id)}
          <div class="msg user">
            <div class="who">あなた</div>
            <div class="bubble" class:fresh={turn.id === freshId}>{turn.user_text}</div>
          </div>
          <div class="msg assistant" class:pending={turn.state === "pending"} aria-busy={turn.state === "pending"}>
            <div class="who">{characterName}</div>
            {#if turn.state === "pending"}
              <TypingIndicator charName={characterName} label={pendingLabel} />
            {:else}
              <div class="group">
                <div class="bubble" class:fresh={turn.id === freshId} class:error={turn.state === "error"}>
                  {turn.state === "error" ? (turn.errorMessage ?? "返答に失敗しました") : turn.assistant_text}
                </div>
                {#if turn.state === "complete" && turn.audio_url}
                  <AudioChip
                    src={api.absoluteUrl(baseUrl, turn.audio_url)}
                    autoplay={turn.id === autoplayId}
                    onautoplayfail={onAutoplayFail}
                  />
                {/if}
              </div>
            {/if}
          </div>
        {/each}
      {/if}
    </div>

    <div class="composer">
      <form
        class="field"
        onsubmit={(event) => {
          event.preventDefault();
          void sendTextTurn();
        }}
      >
        <button type="button" class="icon-btn" disabled title="音声入力（将来対応）" aria-label="音声入力（将来対応）">
          <Icon name="mic" />
        </button>
        <textarea
          bind:this={textareaEl}
          bind:value={textInput}
          rows="1"
          placeholder="話しかけてください…"
          aria-label="テキスト入力"
          disabled={displayState === "conversing"}
          onkeydown={onComposerKeydown}
          oninput={autoGrow}
        ></textarea>
        {#if displayState === "conversing"}
          <button type="button" class="send cancel" aria-label="キャンセル" onclick={cancelTextTurn}>
            <Icon name="stop" />
          </button>
        {:else}
          <button type="submit" class="send" disabled={!canConverse} aria-label="送信">
            <Icon name="send" />
          </button>
        {/if}
      </form>
      <div class="hint">
        <kbd>Enter</kbd> で送信 · <kbd>Shift</kbd>+<kbd>Enter</kbd> で改行
        {#if prefs.autoplay}
          <span class="right">自動読み上げ ON</span>
        {/if}
      </div>
    </div>
  </section>
</main>

<SettingsPanel
  bind:open={settingsOpen}
  bind:draft={settingsDraft}
  bind:draftBaseUrl
  bind:prefs
  {speakers}
  {statusItems}
  {connectionHelp}
  {savingSettings}
  {connecting}
  {clearingHistory}
  {uploadingImage}
  onSave={saveSettings}
  onConnect={connect}
  onClearHistory={clearHistory}
  onUploadImage={uploadImage}
/>
