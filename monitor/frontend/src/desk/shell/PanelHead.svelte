<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A panel's heading: a small capitalised line, a bold title, an optional
  /// line under it and something at the right; a rule under all of it.

  interface Props {
    eyebrow: string
    title: string
    subtitle?: string
    aside?: Snippet
  }

  const { eyebrow, title, subtitle, aside }: Props = $props()
</script>

<header class="mb-4 flex items-start justify-between gap-3 border-b border-line pb-4">
  <div class="min-w-0">
    <p class="desk-eyebrow truncate">{eyebrow}</p>
    <h2 class="mt-1 truncate text-xl font-bold leading-tight">{title}</h2>
    {#if subtitle}<p class="desk-muted mt-1 truncate text-[0.8rem]">{subtitle}</p>{/if}
  </div>
  {#if aside}<div class="shrink-0">{@render aside()}</div>{/if}
</header>
