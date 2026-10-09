<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A titled group in a window's inset sidebar; the title is set in caps by
  /// style, written in sentence case.

  interface Props {
    title?: string
    class?: string
    children: Snippet
  }

  const { title, class: className = '', children }: Props = $props()
</script>

<div class="lk-side__section {className}">
  {#if title}<div class="lk-side__head">{title}</div>{/if}
  {@render children()}
</div>
