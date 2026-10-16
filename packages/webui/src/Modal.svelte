<script lang="ts">
  import type { Snippet } from 'svelte'
  import { webuiLabels } from './labels.js'
  import { cn } from './utils.js'

  interface Props {
    open: boolean
    title: string
    onclose: () => void
    class?: string
    children: Snippet
  }

  const { open, title, onclose, class: className, children }: Props = $props()
  const labels = webuiLabels()

  let dialog = $state<HTMLDivElement | null>(null)
  let body = $state<HTMLDivElement | null>(null)
  /// What had focus before the dialog opened, to give it back on close.
  let opener: HTMLElement | null = null

  const FOCUSABLE =
    'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"]), [contenteditable="true"]'

  function focusables(root: HTMLElement): HTMLElement[] {
    return [...root.querySelectorAll<HTMLElement>(FOCUSABLE)].filter((el) => el.checkVisibility?.() ?? true)
  }

  // Before the dialog is drawn, while focus is still on whatever opened it
  $effect.pre(() => {
    if (open) opener = document.activeElement instanceof HTMLElement ? document.activeElement : null
  })

  $effect(() => {
    if (!open || !dialog) return
    // Content that placed focus itself keeps it
    if (!dialog.contains(document.activeElement)) {
      const initial =
        dialog.querySelector<HTMLElement>('[autofocus]') ?? (body && focusables(body)[0]) ?? dialog
      initial.focus()
    }
    return () => {
      if (opener?.isConnected) opener.focus()
      opener = null
    }
  })

  /// Escape closes, and Tab cycles inside the dialog. Handled here rather than
  /// on the window so a closed dialog ignores keys, and stopped so a dialog
  /// opened from another closes alone.
  function onkeydown(e: KeyboardEvent) {
    // Content that handled the key itself (an editor, a terminal) keeps it
    if (e.defaultPrevented) return
    if (e.key === 'Escape') {
      e.stopPropagation()
      onclose()
      return
    }
    if (e.key !== 'Tab' || !dialog) return
    const items = focusables(dialog)
    e.stopPropagation()
    if (items.length === 0) {
      e.preventDefault()
      dialog.focus()
      return
    }
    const first = items[0]
    const last = items[items.length - 1]
    const active = document.activeElement
    if (e.shiftKey && (active === first || active === dialog)) {
      e.preventDefault()
      last.focus()
    } else if (!e.shiftKey && active === last) {
      e.preventDefault()
      first.focus()
    }
  }
</script>

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
  <div
    class="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-black/40"
    onclick={onclose}
  >
    <div
      bind:this={dialog}
      role="dialog"
      aria-modal="true"
      aria-label={title}
      tabindex="-1"
      class={cn(
        'w-full max-w-sm bg-surface rounded-(--radius-container) border border-line shadow-lg focus:outline-hidden',
        className,
      )}
      onclick={(e) => e.stopPropagation()}
      {onkeydown}
    >
      <div class="flex items-center justify-between px-5 py-4 border-b border-line">
        <h2 class="text-base font-semibold font-display text-fg-strong">{title}</h2>
        <button
          type="button"
          aria-label={labels.close()}
          title={labels.close()}
          onclick={onclose}
          class="text-muted-fg hover:text-fg cursor-pointer text-xl leading-none px-1"
        >
          &times;
        </button>
      </div>
      <div class="p-5" bind:this={body}>
        {@render children()}
      </div>
    </div>
  </div>
{/if}
