<script lang="ts" module>
  import type { IconTone } from './AppIcon.svelte'

  export interface CenterNotice {
    id: string | number
    title: string
    text?: string
    time: string
    glyph: string
    tone: IconTone
    /// Seen already: drawn quieter.
    read?: boolean
    onclick?: () => void
  }
</script>

<script lang="ts">
  import AppIcon from './AppIcon.svelte'
  import Icon from './Icon.svelte'

  /// The notifications panel under the menu bar: a head with do-not-disturb
  /// and clear, then one glass row per notice (its app's icon, title, time,
  /// one line of text).

  interface Props {
    title: string
    notices: CenterNotice[]
    dnd?: boolean
    ondnd?: (on: boolean) => void
    onclear?: () => void
    dndLabel: string
    clearLabel: string
    emptyText: string
    maxHeight?: string
    class?: string
  }

  const { title, notices, dnd = false, ondnd, onclear, dndLabel, clearLabel, emptyText, maxHeight, class: className = '' }: Props =
    $props()
</script>

<div class="lk-ncenter {className}" style:max-height={maxHeight}>
  <div class="lk-ncenter__head">
    <span class="lk-ncenter__title">{title}</span>
    {#if ondnd}
      <button type="button" aria-pressed={dnd} class="lk-ncenter__dnd" class:lk-ncenter__dnd--on={dnd} onclick={() => ondnd(!dnd)}>
        <Icon name="do_not_disturb_on" size={15} fill={dnd} />{dndLabel}
      </button>
    {/if}
    {#if onclear}
      <button type="button" class="lk-btn lk-btn--ghost lk-btn--sm" disabled={!notices.length} onclick={onclear}>{clearLabel}</button>
    {/if}
  </div>
  <div class="lk-ncenter__list">
    {#each notices as n (n.id)}
      <button type="button" class="lk-ncenter__item w-full border-0 text-left" class:opacity-70={n.read} onclick={n.onclick}>
        <AppIcon glyph={n.glyph} tone={n.tone} size={30} />
        <span class="lk-ncenter__body">
          <span class="lk-ncenter__row">
            <span class="lk-ncenter__name">{n.title}</span>
            <span class="lk-ncenter__time">{n.time}</span>
          </span>
          {#if n.text}<span class="lk-ncenter__text">{n.text}</span>{/if}
        </span>
      </button>
    {/each}
    {#if !notices.length}
      <div class="lk-ncenter__empty"><Icon name="notifications_off" size={34} />{emptyText}</div>
    {/if}
  </div>
</div>

<style>
  .lk-ncenter__item {
    font: inherit;
    color: inherit;
  }
  .lk-ncenter__item:focus-visible,
  .lk-ncenter__dnd:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
