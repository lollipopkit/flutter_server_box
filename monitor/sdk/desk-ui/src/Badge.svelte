<script lang="ts" module>
  export type BadgeTone = 'neutral' | 'accent' | 'success' | 'warning' | 'danger' | 'count'
</script>

<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A small state or count. Sentence case (`Running`), a dot for a live state.

  interface Props {
    tone?: BadgeTone
    dot?: boolean
    class?: string
    children: Snippet
  }

  const { tone = 'neutral', dot = false, class: className = '', children }: Props = $props()
</script>

<span class="lk-badge lk-badge--{tone} {className}">
  {#if dot}<span class="lk-badge__dot"></span>{/if}
  {@render children()}
</span>
