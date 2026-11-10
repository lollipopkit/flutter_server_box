<script lang="ts" module>
  export interface ToolbarItem {
    /// The accessible name and tooltip.
    label: string
    icon?: string
    /// Shown beside the glyph (a toggle that needs words).
    text?: string
    /// On: soft accent, filled glyph.
    active?: boolean
    disabled?: boolean
    onclick: () => void
  }
</script>

<script lang="ts">
  import Icon from './Icon.svelte'

  /// A raised capsule of title-bar buttons that belong together (back and
  /// forward; pause and the list).

  interface Props {
    items: ToolbarItem[]
    class?: string
  }

  const { items, class: className = '' }: Props = $props()
</script>

<div class="lk-tbgroup {className}" role="group">
  {#each items as it (it.label)}
    <button
      type="button"
      title={it.label}
      aria-label={it.label}
      aria-pressed={it.active ?? undefined}
      disabled={it.disabled}
      class="lk-tbgroup__btn"
      class:lk-tbgroup__btn--text={!!it.text}
      class:lk-tbgroup__btn--on={it.active}
      onclick={it.onclick}
    >
      {#if it.icon}<Icon name={it.icon} size={it.text ? 16 : 18} fill={it.active} />{/if}{it.text ?? ''}
    </button>
  {/each}
</div>

<style>
  .lk-tbgroup__btn:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
