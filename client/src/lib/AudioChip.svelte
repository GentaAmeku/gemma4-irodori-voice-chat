<script lang="ts">
  import Icon from "./Icon.svelte";

  let {
    src,
    autoplay = false,
    volume = 1,
    onautoplayfail,
  }: {
    src: string;
    autoplay?: boolean;
    volume?: number;
    onautoplayfail?: () => void;
  } = $props();

  let audioEl: HTMLAudioElement | undefined = $state();
  let playing = $state(false);
  let duration: number | null = $state(null);
  let autoplayAttempted = false;

  const bars = [0.4, 0.8, 0.55, 1, 0.65, 0.9, 0.45, 0.75, 0.5];

  // 音量変更は再生中でも即座に反映する
  $effect(() => {
    if (audioEl) {
      audioEl.volume = Math.min(1, Math.max(0, volume));
    }
  });

  $effect(() => {
    if (!autoplay || autoplayAttempted || !audioEl) {
      return;
    }
    autoplayAttempted = true;
    audioEl.play().catch(() => onautoplayfail?.());
  });

  function toggle() {
    if (!audioEl) {
      return;
    }
    if (audioEl.paused) {
      void audioEl.play().catch(() => {});
    } else {
      audioEl.pause();
    }
  }

  function onLoadedMetadata() {
    if (audioEl && Number.isFinite(audioEl.duration)) {
      duration = audioEl.duration;
    }
  }

  function formatDuration(seconds: number): string {
    const m = Math.floor(seconds / 60);
    const s = Math.round(seconds % 60);
    return `${m}:${String(s).padStart(2, "0")}`;
  }
</script>

<button
  type="button"
  class="audiochip"
  class:playing
  onclick={toggle}
  aria-label={playing ? "読み上げを一時停止" : "読み上げを再生"}
  aria-pressed={playing}
>
  <span class="play">
    {#if playing}
      <Icon name="pause" />
    {:else}
      <Icon name="play" />
    {/if}
  </span>
  <span class="wave" aria-hidden="true">
    {#each bars as height (height)}
      <i style="block-size: {height * 100}%"></i>
    {/each}
  </span>
  {#if duration !== null}
    <span class="dur">{formatDuration(duration)}</span>
  {/if}
</button>
<audio
  bind:this={audioEl}
  {src}
  preload="metadata"
  onplay={() => (playing = true)}
  onpause={() => (playing = false)}
  onended={() => (playing = false)}
  onloadedmetadata={onLoadedMetadata}
></audio>
