<script lang="ts">
  import type { Snippet } from 'svelte'
  import { cn } from './utils.js'

  interface Props {
    class?: string
    children: Snippet
  }

  const { class: className, children }: Props = $props()
</script>

<div class={cn('bg-surface rounded-(--radius-container) border border-line p-6 shadow-xs', className)}>
  {@render children()}
</div>
