<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A titled group of sidebar rows.

  interface Props {
    title?: string
    children: Snippet
  }

  const { title, children }: Props = $props()
</script>

<section class="mb-3">
  {#if title}
    <h3 class="px-2 pb-1 text-[0.65rem] font-bold uppercase tracking-wider text-muted-fg">{title}</h3>
  {/if}
  <div class="space-y-0.5">{@render children()}</div>
</section>
