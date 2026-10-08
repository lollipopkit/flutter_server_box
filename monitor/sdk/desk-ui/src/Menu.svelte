<script lang="ts" module>
  export type MenuEntry =
    | { separator: true }
    | { heading: string }
    | {
        label: string
        /// A glyph name.
        icon?: string
        shortcut?: string
        checked?: boolean
        danger?: boolean
        disabled?: boolean
        action: () => void
      }
</script>

<script lang="ts">
  import Icon from './Icon.svelte'

  /// A menu's body (context menu, menu bar drop-down). A hovered row turns
  /// solid accent with white text. Arrow keys move between rows; [onselect]
  /// runs after a row's action, to close the menu.

  interface Props {
    items: MenuEntry[]
    onselect?: () => void
    /// Escape.
    onclose?: () => void
    class?: string
    /// The menu element, to place or focus it.
    ref?: HTMLDivElement | null
  }

  let { items, onselect, onclose, class: className = '', ref = $bindable(null) }: Props = $props()

  function onkeydown(e: KeyboardEvent) {
    if (!ref) return
    const rows = [...ref.querySelectorAll<HTMLButtonElement>('button:not(:disabled)')]
    const at = rows.indexOf(document.activeElement as HTMLButtonElement)
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      const next = e.key === 'ArrowDown' ? (at + 1) % rows.length : (at - 1 + rows.length) % rows.length
      rows[next]?.focus()
    } else if (e.key === 'Escape') {
      e.preventDefault()
      onclose?.()
    }
  }
</script>

<div
  bind:this={ref}
  role="menu"
  tabindex="-1"
  class="lk-menu {className}"
  {onkeydown}
  oncontextmenu={(e) => e.preventDefault()}
>
  {#each items as it, i (i)}
    {#if 'separator' in it}
      <div class="lk-menu__sep"></div>
    {:else if 'heading' in it}
      <div class="lk-menu__head">{it.heading}</div>
    {:else}
      <button
        type="button"
        role="menuitem"
        class="lk-menu__item w-full text-left"
        class:lk-menu__item--danger={it.danger}
        class:lk-menu__item--disabled={it.disabled}
        disabled={it.disabled}
        onclick={() => {
          it.action()
          onselect?.()
        }}
      >
        <span class="lk-menu__lead">
          {#if it.checked}<Icon name="check" size={15} weight={600} />{:else if it.icon}<Icon name={it.icon} size={16} />{/if}
        </span>
        <span class="lk-menu__label">{it.label}</span>
        {#if it.shortcut}<span class="lk-menu__short">{it.shortcut}</span>{/if}
      </button>
    {/if}
  {/each}
</div>

<style>
  /* A row is a button: the keyboard reaches it; focus looks like hover. */
  .lk-menu__item:focus-visible {
    outline: none;
    background: var(--color-accent);
    color: var(--text-on-accent);
  }
</style>
