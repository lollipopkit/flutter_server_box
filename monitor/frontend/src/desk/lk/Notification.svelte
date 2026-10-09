<script lang="ts">
  import type { Snippet } from 'svelte'
  import Icon from './Icon.svelte'

  interface Props {
    /// Before the text (an AppIcon at 34).
    icon?: Snippet
    app: string
    time: string
    title?: string
    actions?: Snippet
    onclose?: () => void
    onclick?: () => void
    /// The close button's accessible name.
    closeLabel?: string
    class?: string
    children?: Snippet
  }

  const {
    icon,
    app,
    time,
    title,
    actions,
    onclose,
    onclick,
    closeLabel = 'Dismiss',
    class: className = '',
    children,
  }: Props = $props()
</script>

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
<div role="status" class="lk-notif {className}" {onclick}>
  {#if onclose}
    <button
      type="button"
      aria-label={closeLabel}
      class="lk-notif__close"
      onclick={(e) => {
        e.stopPropagation()
        onclose()
      }}
    >
      <Icon name="close" size={13} weight={600} />
    </button>
  {/if}
  {@render icon?.()}
  <div class="lk-notif__body">
    <div class="lk-notif__meta"><span>{app}</span><span>{time}</span></div>
    {#if title}<div class="lk-notif__title">{title}</div>{/if}
    {#if children}<div class="lk-notif__text">{@render children()}</div>{/if}
    {#if actions}<div class="lk-notif__actions">{@render actions()}</div>{/if}
  </div>
</div>
