<script lang="ts">
  let {
    state = "unknown",
    live = false,
  }: {
    state?: "ok" | "warn" | "err" | "unknown";
    live?: boolean;
  } = $props();
</script>

<span class="dot {state === 'unknown' ? '' : state}" class:live aria-hidden="true"></span>
