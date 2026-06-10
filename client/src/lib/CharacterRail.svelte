<script lang="ts">
  import Icon from "./Icon.svelte";
  import StatusDot from "./StatusDot.svelte";

  let {
    name,
    model = null,
    mock = false,
    prompt = "",
    imageUrl,
    imageMissing = false,
    stateLabel,
    dotState,
    live = false,
    allOk = false,
    onOpenSettings,
    onImageError,
  }: {
    name: string;
    model?: string | null;
    mock?: boolean;
    prompt?: string;
    imageUrl: string;
    imageMissing?: boolean;
    stateLabel: string;
    dotState: "ok" | "warn" | "err" | "unknown";
    live?: boolean;
    allOk?: boolean;
    onOpenSettings: () => void;
    onImageError: () => void;
  } = $props();
</script>

<aside class="rail" aria-label="キャラクター">
  <div class="portrait">
    {#if imageMissing}
      <div class="ph">キャラクター画像<br />をここに</div>
    {:else}
      <img src={imageUrl} alt="{name}のキャラクター画像" onerror={onImageError} />
    {/if}
  </div>

  <div class="presence">
    <div class="identity">
      <h1 class="name" id="character-title">{name}</h1>
      <div class="meta">
        <StatusDot state={dotState} {live} />
        {stateLabel}
        {#if model}
          <span style="color: var(--ink-ghost)">·</span>
          <span class="model">{model}{mock ? " / mock" : ""}</span>
        {/if}
      </div>
    </div>
    {#if prompt}
      <p class="persona-line">{prompt}</p>
    {/if}
  </div>

  <div class="rail-foot">
    <div class="statusline">
      <StatusDot state={allOk ? "ok" : dotState} live={allOk} />
      <span>{allOk ? "すべて接続済み" : "接続を確認"}</span>
    </div>
    <button type="button" class="btn block" onclick={onOpenSettings}>
      <Icon name="gear" />
      設定
    </button>
  </div>
</aside>
