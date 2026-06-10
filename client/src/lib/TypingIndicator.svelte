<script lang="ts">
  let { charName }: { charName: string } = $props();
</script>

<div class="typing" aria-live="polite">
  <span class="dots" aria-hidden="true"><i></i><i></i><i></i></span>
  <span class="label">{charName}が返答中…</span>
</div>
