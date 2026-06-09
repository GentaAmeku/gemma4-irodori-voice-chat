<script lang="ts">
  import { onMount } from "svelte";
  import { api, ApiError, type AppSettings, type ConversationTurn, type HealthResponse, type SpeakerOption } from "./api";

  type DisplayState = "disconnected" | "connecting" | "ready" | "conversing" | "error";

  const savedBaseUrl = "gemma4-irodori-chat.base-url";
  const defaultBaseUrl = "http://127.0.0.1:8000";

  let baseUrl = localStorage.getItem(savedBaseUrl) ?? defaultBaseUrl;
  let draftBaseUrl = baseUrl;
  let displayState: DisplayState = "disconnected";
  let health: HealthResponse | null = null;
  let settings: AppSettings | null = null;
  let settingsDraft: AppSettings | null = null;
  let speakers: SpeakerOption[] = [];
  let turns: ConversationTurn[] = [];
  let textInput = "";
  let errorMessage = "";
  let statusMessage = "";
  let showSettings = false;
  let imageVersion = Date.now();
  let imageMissing = false;
  let audioElement: HTMLAudioElement | null = null;

  const displayLabels: Record<DisplayState, string> = {
    disconnected: "未接続",
    connecting: "接続中",
    ready: "利用可能",
    conversing: "会話中",
    error: "エラー",
  };

  $: canConverse = displayState === "ready" && textInput.trim().length > 0;
  $: characterImageUrl = `${baseUrl.replace(/\/+$/, "")}/api/character-image?v=${imageVersion}`;

  onMount(() => {
    void connect();
  });

  async function connect() {
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
      turns = history.turns;
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
    }
  }

  async function sendTextTurn() {
    const text = textInput.trim();
    if (!text || displayState !== "ready") {
      return;
    }
    displayState = "conversing";
    errorMessage = "";
    statusMessage = "考え中";
    textInput = "";
    try {
      const turn = await api.textTurn(baseUrl, text);
      turns = [...turns, turn];
      statusMessage = "読み上げ中";
      await playAudio(turn.audio_url);
      displayState = "ready";
      statusMessage = "利用可能です";
    } catch (error) {
      displayState = "error";
      errorMessage = formatError(error);
    }
  }

  async function saveSettings() {
    if (!settingsDraft) {
      return;
    }
    try {
      const saved = await api.saveSettings(baseUrl, settingsDraft);
      settings = saved;
      settingsDraft = { ...saved };
      turns = [];
      statusMessage = "設定を保存しました";
    } catch (error) {
      errorMessage = formatError(error);
    }
  }

  async function clearHistory() {
    try {
      await api.clearHistory(baseUrl);
      turns = [];
      statusMessage = "履歴をクリアしました";
    } catch (error) {
      errorMessage = formatError(error);
    }
  }

  async function uploadImage(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) {
      return;
    }
    try {
      await api.uploadCharacterImage(baseUrl, file);
      imageMissing = false;
      imageVersion = Date.now();
      statusMessage = "キャラクター画像を更新しました";
    } catch (error) {
      errorMessage = formatError(error);
    } finally {
      input.value = "";
    }
  }

  async function playAudio(audioUrl: string) {
    const source = api.absoluteUrl(baseUrl, audioUrl);
    if (!audioElement) {
      audioElement = new Audio();
    }
    audioElement.src = source;
    await audioElement.play();
  }

  function formatError(error: unknown): string {
    if (error instanceof ApiError) {
      if (error.status === 409) {
        return "会話中です。少し待ってから再入力してください。";
      }
      return `${error.status}: ${error.message}`;
    }
    if (error instanceof Error) {
      return error.message;
    }
    return "不明なエラーが発生しました";
  }

  function dependencyMessage(nextHealth: HealthResponse): string {
    const errors = [];
    if (!nextHealth.ollama.ok) {
      errors.push(`Ollama: ${nextHealth.ollama.detail ?? "利用できません"}`);
    }
    if (!nextHealth.tts.ok) {
      errors.push(`irodori-TTS: ${nextHealth.tts.detail ?? "利用できません"}`);
    }
    return errors.join(" / ") || "会話サーバーは応答しましたが、利用可能状態ではありません";
  }
</script>

<svelte:head>
  <title>Gemma4 Irodori Chat</title>
</svelte:head>

<main class="app-shell">
  <section class="portrait-pane" aria-labelledby="character-title">
    <header class="topbar">
      <div>
        <h1 id="character-title">{settings?.character_name ?? "Gemma4 Irodori Chat"}</h1>
        <p class="model-line">{health?.model ?? "model unknown"}{health?.mock_services ? " / mock" : ""}</p>
      </div>
      <button type="button" class="ghost-button" on:click={() => (showSettings = !showSettings)} aria-expanded={showSettings}>
        Options
      </button>
    </header>

    <figure class="character-frame">
      {#if imageMissing}
        <div class="image-placeholder" aria-label="キャラクター画像未設定">No Image</div>
      {:else}
        <img
          src={characterImageUrl}
          alt={`${settings?.character_name ?? "キャラクター"}の画像`}
          width="720"
          height="900"
          fetchpriority="high"
          on:error={() => (imageMissing = true)}
        />
      {/if}
      <figcaption>{displayLabels[displayState]}</figcaption>
    </figure>

    <form class="connection-form" on:submit|preventDefault={connect}>
      <label for="server-url">接続先</label>
      <div class="inline-row">
        <input id="server-url" type="url" bind:value={draftBaseUrl} required />
        <button type="submit">接続</button>
      </div>
    </form>

    {#if showSettings && settingsDraft}
      <aside class="settings-panel" aria-labelledby="settings-title">
        <div class="panel-heading">
          <h2 id="settings-title">設定</h2>
          <button type="button" class="ghost-button" on:click={() => (showSettings = false)}>閉じる</button>
        </div>

        <form class="settings-form" on:submit|preventDefault={saveSettings}>
          <label for="character-name">キャラクター名</label>
          <input id="character-name" bind:value={settingsDraft.character_name} required />

          <label for="speaker">話者</label>
          <select id="speaker" bind:value={settingsDraft.speaker_id}>
            {#each speakers as speaker}
              <option value={speaker.id}>{speaker.label}</option>
            {/each}
          </select>

          <label for="character-prompt">キャラクター設定</label>
          <textarea id="character-prompt" bind:value={settingsDraft.character_prompt} rows="7" required></textarea>

          <label for="voice-prompt">読み上げ設定</label>
          <textarea id="voice-prompt" bind:value={settingsDraft.read_aloud_prompt} rows="5" required></textarea>

          <div class="button-row">
            <button type="submit">保存</button>
            <button type="button" class="danger-button" on:click={clearHistory}>履歴クリア</button>
          </div>
        </form>

        <label class="upload-control" for="character-image">キャラクター画像</label>
        <input id="character-image" type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml" on:change={uploadImage} />
      </aside>
    {/if}
  </section>

  <section class="conversation-pane" aria-labelledby="conversation-title">
    <header class="conversation-header">
      <div>
        <h2 id="conversation-title">会話</h2>
        <p aria-live="polite">{statusMessage || displayLabels[displayState]}</p>
      </div>
      {#if errorMessage}
        <p class="error-message" role="alert">{errorMessage}</p>
      {/if}
    </header>

    <ol class="history-list" aria-label="会話履歴">
      {#if turns.length === 0}
        <li class="empty-history">まだ会話はありません。</li>
      {:else}
        {#each turns as turn}
          <li class="turn">
            <article class="bubble user-bubble">
              <h3>あなた</h3>
              <p>{turn.user_text}</p>
            </article>
            <article class="bubble assistant-bubble">
              <h3>{settings?.character_name ?? "AI"}</h3>
              <p>{turn.assistant_text}</p>
              <audio controls src={api.absoluteUrl(baseUrl, turn.audio_url)}></audio>
            </article>
          </li>
        {/each}
      {/if}
    </ol>

    <form class="input-form" on:submit|preventDefault={sendTextTurn}>
      <label for="text-input">テキスト入力</label>
      <div class="input-row">
        <textarea
          id="text-input"
          bind:value={textInput}
          rows="3"
          placeholder="話しかけてください"
          disabled={displayState === "conversing"}
        ></textarea>
        <button type="submit" disabled={!canConverse}>送信</button>
      </div>
    </form>
  </section>
</main>
