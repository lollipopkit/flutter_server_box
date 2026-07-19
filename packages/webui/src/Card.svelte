<script lang="ts">
  import type { Snippet } from 'svelte'
  import { cn } from './utils.js'

  interface Props {
    class?: string
    /// When given, the card renders as a button with hover affordance
    onclick?: (e: MouseEvent) => void
    children: Snippet
  }

  const { class: className, onclick, children }: Props = $props()

  const base = 'bg-surface rounded-(--radius-container) border border-line p-6 shadow-xs'
</script>

{#if onclick}
  <button
    type="button"
    {onclick}
    class={cn(
      base,
      'block w-full text-left cursor-pointer transition-colors hover:border-accent/60 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring',
      className,
    )}
  >
    {@render children()}
  </button>
{:else}
  <div class={cn(base, className)}>
    {@render children()}
  </div>
{/if}
