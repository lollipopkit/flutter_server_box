<script lang="ts">
  import type { Snippet } from 'svelte'
  import { cn } from './utils.js'

  interface Props {
    open: boolean
    title: string
    onclose: () => void
    class?: string
    children: Snippet
  }

  const { open, title, onclose, class: className, children }: Props = $props()

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose()
  }
</script>

<svelte:window {onkeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
  <div
    class="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-black/40"
    onclick={onclose}
  >
    <div
      role="dialog"
      aria-modal="true"
      aria-label={title}
      tabindex="-1"
      class={cn(
        // Never taller than what it sits over (the screen, or a window in the
        // panel's desk): the body scrolls, the title and its close stay.
        'flex max-h-full w-full max-w-sm flex-col bg-surface rounded-(--radius-container) border border-line shadow-lg',
        className,
      )}
      onclick={(e) => e.stopPropagation()}
    >
      <div class="flex shrink-0 items-center justify-between px-5 py-4 border-b border-line">
        <h2 class="text-base font-semibold font-display text-fg-strong">{title}</h2>
        <button
          type="button"
          aria-label="Close"
          onclick={onclose}
          class="text-muted-fg hover:text-fg cursor-pointer text-xl leading-none px-1"
        >
          &times;
        </button>
      </div>
      <div class="min-h-0 overflow-y-auto p-5">
        {@render children()}
      </div>
    </div>
  </div>
{/if}
