<script lang="ts">
  import type { AppSettings } from "../api";
  import type { StatusItem } from "./status";
  import { TONE_PRESETS, type LocalPrefs } from "./prefs";
  import Icon from "./Icon.svelte";
  import StatusDot from "./StatusDot.svelte";

  let {
    open = $bindable(false),
    draft = $bindable(null),
    draftBaseUrl = $bindable(""),
    prefs = $bindable(),
    statusItems,
    connectionHelp,
    connecting = false,
    clearingHistory = false,
    uploadingImage = false,
    onClose,
    onConnect,
    onClearHistory,
    onUploadImage,
  }: {
    open?: boolean;
    draft?: AppSettings | null;
    draftBaseUrl?: string;
    prefs: LocalPrefs;
    statusItems: StatusItem[];
    connectionHelp: string;
    connecting?: boolean;
    clearingHistory?: boolean;
    uploadingImage?: boolean;
    onClose: () => void;
    onConnect: () => void;
    onClearHistory: () => void;
    onUploadImage: (file: File) => void;
  } = $props();

  let dialogEl: HTMLDialogElement | undefined = $state();
  let dragOver = $state(false);

  const preset = $derived(TONE_PRESETS.find((t) => t.id === draft?.tone_preset) ?? TONE_PRESETS[0]);
  const distanceLabel = $derived(
    (draft?.distance ?? 40) <= 33 ? "ていねい" : (draft?.distance ?? 40) >= 67 ? "親しい" : "ほどよい",
  );
  const panelBusyMessage = $derived.by(() => {
    if (connecting) return "接続を確認中です。";
    if (uploadingImage) return "キャラクター画像をアップロード中です。";
    if (clearingHistory) return "会話履歴をクリア中です。";
    return "";
  });

  $effect(() => {
    if (!dialogEl) {
      return;
    }
    if (open && !dialogEl.open) {
      dialogEl.showModal();
    } else if (!open && dialogEl.open) {
      dialogEl.close();
    }
  });

  // closedby="any" 非対応ブラウザ (Safari) 向けのライトディスミス
  function onDialogClick(event: MouseEvent) {
    if ("closedBy" in HTMLDialogElement.prototype) {
      return;
    }
    if (!dialogEl || event.target !== dialogEl) {
      return;
    }
    const rect = dialogEl.getBoundingClientRect();
    const insideContent =
      rect.top <= event.clientY &&
      event.clientY <= rect.top + rect.height &&
      rect.left <= event.clientX &&
      event.clientX <= rect.left + rect.width;
    if (!insideContent) {
      dialogEl.close();
    }
  }

  function onFileChange(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    if (uploadingImage) {
      input.value = "";
      return;
    }
    const file = input.files?.[0];
    if (file) {
      onUploadImage(file);
    }
    input.value = "";
  }

  function onDrop(event: DragEvent) {
    event.preventDefault();
    dragOver = false;
    if (uploadingImage) {
      return;
    }
    const file = event.dataTransfer?.files?.[0];
    if (file) {
      onUploadImage(file);
    }
  }
</script>

<dialog
  class="panel"
  closedby="any"
  bind:this={dialogEl}
  aria-label="設定"
  onclose={() => {
    open = false;
    onClose();
  }}
  onclick={onDialogClick}
>
  <div class="panel-head">
    <span class="t">設定</span>
    <button type="button" class="x" onclick={() => (open = false)} aria-label="設定を閉じる">
      <Icon name="close" />
    </button>
  </div>

  <div class="panel-body">
    <div class="panel-status" aria-live="polite" aria-atomic="true">
      {#if panelBusyMessage}
        {panelBusyMessage}
      {/if}
    </div>

    {#if draft}
      <div class="help close-note">
        設定を変更してパネルを閉じると保存され、次の会話ターンから反映されます。保存時には会話履歴がクリアされます。
      </div>

      <!-- キャラクター -->
      <section class="sect">
        <h3 class="h">キャラクター</h3>
        <div class="field-row">
          <label for="character-name">キャラクター名</label>
          <input
            id="character-name"
            name="character_name"
            class="input"
            bind:value={draft.character_name}
            aria-describedby="character-name-help"
            required
          />
          <div id="character-name-help" class="help">会話画面と発話待機表示に使う名前です。</div>
        </div>
        <div class="field-row">
          <span class="field-label" id="character-image-label">キャラクター画像</span>
          <label
            class="dropzone"
            class:over={dragOver}
            class:disabled={uploadingImage}
            aria-disabled={uploadingImage}
            aria-describedby="character-image-help"
            ondragover={(event) => {
              event.preventDefault();
              if (!uploadingImage) {
                dragOver = true;
              }
            }}
            ondragleave={() => (dragOver = false)}
            ondrop={onDrop}
          >
            {uploadingImage ? "アップロード中…" : "画像をドラッグ、またはクリックして選択"}
            <input
              type="file"
              name="character_image"
              class="visually-hidden"
              accept="image/png,image/jpeg,image/webp,image/svg+xml"
              aria-labelledby="character-image-label"
              disabled={uploadingImage}
              onchange={onFileChange}
            />
          </label>
          <div id="character-image-help" class="help">PNG、JPEG、WebP、SVGをアップロードできます。</div>
        </div>
      </section>

      <!-- 性格・口調 -->
      <section class="sect">
        <h3 class="h">性格 ・ 口調</h3>
        <div class="field-row">
          <span class="field-label">口調プリセット</span>
          <div class="chips" role="group" aria-label="口調プリセット">
            {#each TONE_PRESETS as tone (tone.id)}
              <button
                type="button"
                class="chip"
                class:on={draft.tone_preset === tone.id}
                aria-pressed={draft.tone_preset === tone.id}
                onclick={() => (draft.tone_preset = tone.id)}
              >
                {tone.label}
              </button>
            {/each}
          </div>
        </div>

        <div class="field-row slider-row">
          <div class="top">
            <label class="l" for="distance">距離感</label>
            <span class="v">{distanceLabel}</span>
          </div>
          <input
            id="distance"
            name="distance"
            type="range"
            min="0"
            max="100"
            bind:value={draft.distance}
            aria-describedby="distance-help"
          />
          <div class="ends"><span>敬語</span><span>タメ口</span></div>
          <div id="distance-help" class="help">パネルを閉じると次の会話ターンからsystem promptに反映されます。</div>
        </div>

        <div class="field-row">
          <label for="character-prompt">キャラクター設定</label>
          <textarea
            id="character-prompt"
            name="character_prompt"
            class="area"
            rows="5"
            bind:value={draft.character_prompt}
            aria-describedby="character-prompt-help"
            required
          ></textarea>
          <div id="character-prompt-help" class="help">
            人格・背景・話し方の指針。会話サーバーへ system として送られます。
          </div>
        </div>

        <div class="preview-card">
          <div class="pl">話し方プレビュー</div>
          <div class="pt">{preset.sample}</div>
        </div>
      </section>

      <!-- 声・読み上げ -->
      <section class="sect">
        <h3 class="h">声 ・ 読み上げ</h3>
        <div class="field-row">
          <label for="voice-prompt">読み上げ設定</label>
          <textarea
            id="voice-prompt"
            name="read_aloud_prompt"
            class="area"
            rows="4"
            bind:value={draft.read_aloud_prompt}
            aria-describedby="voice-prompt-help"
            required
          ></textarea>
          <div id="voice-prompt-help" class="help">
            声・話し方の指針。読み上げ時に caption としてIrodori-TTS-Serverへ送られます（VoiceDesign対応モデルで有効）。
          </div>
        </div>

        <div class="field-row slider-row">
          <div class="top">
            <label class="l" for="speed">話す速さ</label>
            <span class="v">{draft.speech_speed.toFixed(2)}×</span>
          </div>
          <input
            id="speed"
            name="speed"
            type="range"
            min="0.7"
            max="1.4"
            step="0.05"
            bind:value={draft.speech_speed}
            aria-describedby="speed-help"
          />
          <div class="ends"><span>ゆっくり</span><span>はやい</span></div>
          <div id="speed-help" class="help">Irodori-TTS-Serverのspeech requestへ speed として送られます。</div>
        </div>

        <div class="field-row slider-row">
          <div class="top">
            <label class="l" for="volume">音量</label>
            <span class="v">{Math.round(prefs.volume * 100)}%</span>
          </div>
          <input
            id="volume"
            name="volume"
            type="range"
            min="0"
            max="1"
            step="0.05"
            bind:value={prefs.volume}
            aria-describedby="volume-help"
          />
          <div class="ends"><span>小さい</span><span>大きい</span></div>
          <div id="volume-help" class="help">読み上げの再生音量です。この端末にのみ保存されます。</div>
        </div>

        <div class="field-row toggle-row">
          <div class="tx">
            <div class="l">自動で読み上げ</div>
            <div class="d">返答が届いたら自動で再生します</div>
          </div>
          <button
            type="button"
            class="switch"
            class:on={prefs.autoplay}
            role="switch"
            aria-checked={prefs.autoplay}
            aria-label="自動で読み上げ"
            onclick={() => (prefs.autoplay = !prefs.autoplay)}
          >
            <span class="knob"></span>
          </button>
        </div>
      </section>
    {/if}

    <!-- 接続 -->
    <section class="sect">
      <h3 class="h">接続</h3>
      <form
        onsubmit={(event) => {
          event.preventDefault();
          onConnect();
        }}
      >
        <div class="field-row">
          <label for="server-url">接続先</label>
          <input
            id="server-url"
            name="server_url"
            class="input"
            type="url"
            bind:value={draftBaseUrl}
            aria-describedby="server-url-help"
            required
          />
          <div id="server-url-help" class="help">{connectionHelp}</div>
        </div>
        <div class="field-row">
          <button type="submit" class="btn block" disabled={connecting}>
            {connecting ? "接続中…" : "接続する"}
          </button>
        </div>
      </form>
      <div class="status-list">
        {#each statusItems as item (item.label)}
          <div class="status-item">
            <div>
              <div class="nm">{item.label}</div>
              <div class="ds">{item.detail}</div>
            </div>
            <span class="st">
              <StatusDot state={item.state === "ok" ? "ok" : item.state === "error" ? "err" : "unknown"} />
              {item.state === "ok" ? "接続済み" : item.state === "error" ? "要確認" : "未確認"}
            </span>
          </div>
        {/each}
      </div>
    </section>

    <!-- 履歴 -->
    <section class="sect">
      <h3 class="h">履歴</h3>
      <button type="button" class="btn danger block" disabled={clearingHistory} onclick={onClearHistory}>
        {clearingHistory ? "クリア中…" : "会話履歴をクリア"}
      </button>
    </section>
  </div>
</dialog>
