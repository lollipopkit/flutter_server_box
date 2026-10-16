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
</script>

{#if open}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="lk-scrim"
    class:lk-scrim--contained={contained}
    onmousedown={(e) => {
      if (e.target === e.currentTarget) onclose?.()
    }}
    onkeydown={(e) => {
      if (e.key === 'Escape' && onclose) {
        e.stopPropagation()
        onclose()
      }
    }}
  >
    <div role="dialog" aria-modal="true" aria-label={title} class="lk-dialog {wide ? 'lk-dialog--wide' : ''} {className}">
      {#if icon}<div class="lk-dialog__icon">{@render icon()}</div>{/if}
      {#if title}<div class="lk-dialog__title">{title}</div>{/if}
      {#if message}<div class="lk-dialog__msg">{message}</div>{/if}
      {#if children}<div class="lk-dialog__body">{@render children()}</div>{/if}
      {#if actions}<div class="lk-dialog__actions">{@render actions()}</div>{/if}
    </div>
  </div>
{/if}
