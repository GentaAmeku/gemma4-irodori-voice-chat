<script lang="ts">
  import type { AppSettings, SpeakerOption } from "../api";
  import type { StatusItem } from "./status";
  import { TONE_PRESETS, type LocalPrefs } from "./prefs";
  import Icon from "./Icon.svelte";
  import StatusDot from "./StatusDot.svelte";

  let {
    open = $bindable(false),
    draft = $bindable(null),
    draftBaseUrl = $bindable(""),
    prefs = $bindable(),
    speakers,
    statusItems,
    connectionHelp,
    onSave,
    onConnect,
    onClearHistory,
    onUploadImage,
  }: {
    open?: boolean;
    draft?: AppSettings | null;
    draftBaseUrl?: string;
    prefs: LocalPrefs;
    speakers: SpeakerOption[];
    statusItems: StatusItem[];
    connectionHelp: string;
    onSave: () => void;
    onConnect: () => void;
    onClearHistory: () => void;
    onUploadImage: (file: File) => void;
  } = $props();

  let dialogEl: HTMLDialogElement | undefined = $state();
  let dragOver = $state(false);

  const preset = $derived(TONE_PRESETS.find((t) => t.id === prefs.tone) ?? TONE_PRESETS[0]);
  const distanceLabel = $derived(prefs.distance <= 33 ? "ていねい" : prefs.distance >= 67 ? "親しい" : "ほどよい");

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
    const file = input.files?.[0];
    if (file) {
      onUploadImage(file);
    }
    input.value = "";
  }

  function onDrop(event: DragEvent) {
    event.preventDefault();
    dragOver = false;
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
  onclose={() => (open = false)}
  onclick={onDialogClick}
>
  <div class="panel-head">
    <span class="t">設定</span>
    <button type="button" class="x" onclick={() => (open = false)} aria-label="設定を閉じる">
      <Icon name="close" />
    </button>
  </div>

  <div class="panel-body">
    {#if draft}
      <form
        onsubmit={(event) => {
          event.preventDefault();
          onSave();
        }}
      >
        <!-- キャラクター -->
        <section class="sect">
          <h3 class="h">キャラクター</h3>
          <div class="field-row">
            <label for="character-name">キャラクター名</label>
            <input id="character-name" class="input" bind:value={draft.character_name} required />
          </div>
          <div class="field-row">
            <span class="field-label" id="character-image-label">キャラクター画像</span>
            <label
              class="dropzone"
              class:over={dragOver}
              ondragover={(event) => {
                event.preventDefault();
                dragOver = true;
              }}
              ondragleave={() => (dragOver = false)}
              ondrop={onDrop}
            >
              画像をドラッグ、またはクリックして選択
              <input
                type="file"
                class="visually-hidden"
                accept="image/png,image/jpeg,image/webp,image/svg+xml"
                aria-labelledby="character-image-label"
                onchange={onFileChange}
              />
            </label>
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
                  class:on={prefs.tone === tone.id}
                  aria-pressed={prefs.tone === tone.id}
                  onclick={() => (prefs.tone = tone.id)}
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
            <input id="distance" type="range" min="0" max="100" bind:value={prefs.distance} />
            <div class="ends"><span>敬語</span><span>タメ口</span></div>
            <div class="help">口調プリセットと距離感は将来機能のプレビューです。まだ会話には反映されません。</div>
          </div>

          <div class="field-row">
            <label for="character-prompt">キャラクター設定</label>
            <textarea id="character-prompt" class="area" rows="5" bind:value={draft.character_prompt} required
            ></textarea>
            <div class="help">人格・背景・話し方の指針。会話サーバーへ system として送られます。</div>
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
            <label for="speaker">話者</label>
            <select id="speaker" class="select" bind:value={draft.speaker_id}>
              {#each speakers as speaker (speaker.id)}
                <option value={speaker.id}>{speaker.label}</option>
              {/each}
            </select>
          </div>

          <div class="field-row">
            <label for="voice-prompt">読み上げ設定</label>
            <textarea id="voice-prompt" class="area" rows="4" bind:value={draft.read_aloud_prompt} required></textarea>
            <div class="help">声・話し方の指針。将来のための設定で、現在の読み上げには直接使われません。</div>
          </div>

          <div class="field-row slider-row">
            <div class="top">
              <label class="l" for="speed">話す速さ</label>
              <span class="v">{prefs.speed.toFixed(2)}×</span>
            </div>
            <input id="speed" type="range" min="0.7" max="1.4" step="0.05" bind:value={prefs.speed} />
            <div class="ends"><span>ゆっくり</span><span>はやい</span></div>
            <div class="help">将来機能のプレビューです。現在はサーバー側の既定値で読み上げます。</div>
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

        <!-- 設定保存 -->
        <section class="sect">
          <button type="submit" class="btn primary block">保存する</button>
          <div class="help">保存すると次の会話ターンから反映され、会話履歴はクリアされます。</div>
        </section>
      </form>
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
          <input id="server-url" class="input" type="url" bind:value={draftBaseUrl} required />
          <div class="help">{connectionHelp}</div>
        </div>
        <div class="field-row">
          <button type="submit" class="btn block">接続する</button>
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
      <button type="button" class="btn danger block" onclick={onClearHistory}>会話履歴をクリア</button>
    </section>
  </div>
</dialog>
