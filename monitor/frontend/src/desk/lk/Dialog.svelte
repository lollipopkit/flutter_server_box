<script lang="ts" module>
  /// Open dialogs, innermost last.
  const stack: HTMLElement[] = []

  const FOCUSABLE =
    'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"]), [contenteditable="true"]'

  function focusables(root: HTMLElement): HTMLElement[] {
    return [...root.querySelectorAll<HTMLElement>(FOCUSABLE)].filter((el) => el.checkVisibility?.() ?? true)
  }
</script>

<script lang="ts">
  import type { Snippet } from 'svelte'

  /// An alert or a sheet over a scrim. The title is the question (`Reboot
  /// t10-ubuntu?`), the message the consequence in one sentence. Narrow and
  /// centred with stacked actions; [wide] for a form, actions in a row.
  /// Inside a window it covers that window (the window is its containing
  /// block); [contained] keeps it inside the nearest positioned element.

  interface Props {
    open?: boolean
    /// Above the title (an AppIcon).
    icon?: Snippet
    title?: string
    message?: string
    actions?: Snippet
    wide?: boolean
    contained?: boolean
    /// Clicking the scrim or Escape; absent, the dialog must be answered.
    onclose?: () => void
    class?: string
    children?: Snippet
  }

  const {
    open = true,
    icon,
    title,
    message,
    actions,
    wide = false,
    contained = false,
    onclose,
    class: className = '',
    children,
  }: Props = $props()

  let dialog = $state<HTMLDivElement | null>(null)
  /// What had focus before the dialog opened, to give it back on close.
  let opener: HTMLElement | null = null

  // Before the dialog is drawn, while focus is still on whatever opened it
  $effect.pre(() => {
    if (open) opener = document.activeElement instanceof HTMLElement ? document.activeElement : null
  })

  $effect(() => {
    if (!open || !dialog) return
    const self = dialog
    stack.push(self)
    // The dialog itself unless the content asks otherwise: its first control
    // is often an action that runs on Enter with no confirmation.
    if (!self.contains(document.activeElement)) {
      ;(self.querySelector<HTMLElement>('[data-autofocus], [autofocus]') ?? self).focus()
    }
    return () => {
      stack.splice(stack.indexOf(self), 1)
      if (opener?.isConnected) opener.focus()
      opener = null
    }
  })

  const topmost = () => dialog !== null && stack[stack.length - 1] === dialog

  /// What the dialog covers: its window in the desk (the sheet is modal to
  /// that window, never to the others), else the page.
  const covered = () => dialog?.closest<HTMLElement>('.desk-window') ?? document.body

  /// Escape closes (when the dialog may be dismissed), and Tab cycles inside
  /// the dialog. Answered while focus is in what the dialog covers or has
  /// fallen to the body (a focused button that became disabled), and only by
  /// the innermost dialog, so one opened from another closes alone.
  function onkeydown(e: KeyboardEvent) {
    if (!topmost() || !dialog) return
    // Content that handled the key itself (an editor, a terminal) keeps it
    if (e.defaultPrevented) return
    const active = document.activeElement
    if (active && active !== document.body && !covered().contains(active)) return
    if (e.key === 'Escape') {
      if (!onclose) return
      e.preventDefault()
      e.stopPropagation()
      onclose()
      return
    }
    if (e.key !== 'Tab') return
    const items = focusables(dialog)
    if (items.length === 0) {
      e.preventDefault()
      dialog.focus()
      return
    }
    const first = items[0]
    const last = items[items.length - 1]
    if (!dialog.contains(active)) {
      e.preventDefault()
      ;(e.shiftKey ? last : first).focus()
    } else if (e.shiftKey && (active === first || active === dialog)) {
      e.preventDefault()
      last.focus()
    } else if (!e.shiftKey && active === last) {
      e.preventDefault()
      first.focus()
    }
  }

  /// Focus that reached what the dialog covers (a script, the browser) comes
  /// back; another window of the desk keeps it.
  function onfocusin(e: FocusEvent) {
    if (!topmost() || !dialog) return
    const target = e.target
    if (target instanceof Node && covered().contains(target) && !dialog.contains(target)) dialog.focus()
  }
</script>

<svelte:document {onkeydown} {onfocusin} />

{#if open}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="lk-scrim"
    class:lk-scrim--contained={contained}
    onmousedown={(e) => {
      if (e.target === e.currentTarget) onclose?.()
    }}
  >
    <div bind:this={dialog} role="dialog" aria-modal="true" aria-label={title} tabindex="-1" class="lk-dialog {wide ? 'lk-dialog--wide' : ''} {className}">
      {#if icon}<div class="lk-dialog__icon">{@render icon()}</div>{/if}
      {#if title}<div class="lk-dialog__title">{title}</div>{/if}
      {#if message}<div class="lk-dialog__msg">{message}</div>{/if}
      {#if children}<div class="lk-dialog__body">{@render children()}</div>{/if}
      {#if actions}<div class="lk-dialog__actions">{@render actions()}</div>{/if}
    </div>
  </div>
{/if}
