<script lang="ts">
  import type { Snippet } from 'svelte'
  import Icon from './Icon.svelte'

  /// One row of a sidebar: an accent glyph (filled when chosen), a label, an
  /// optional count or state at the right.

  interface Props {
    label: string
    icon?: string
    active?: boolean
    /// A count or short value at the right.
    trailing?: string | number
    /// Instead of [trailing], anything (a badge).
    trail?: Snippet
    /// A tooltip, for a label that had to be shortened.
    title?: string
    onclick: () => void
    class?: string
  }

  const { label, icon, active = false, trailing, trail, title, onclick, class: className = '' }: Props = $props()
</script>

<button
  type="button"
  class="lk-side__item w-full text-left {className}"
  class:lk-side__item--on={active}
  aria-current={active ? 'true' : undefined}
  {title}
  {onclick}
>
  {#if icon}<Icon name={icon} size={17} fill={active} />{/if}
  <span class="lk-side__label">{label}</span>
  {#if trail}{@render trail()}{:else if trailing != null}<span class="lk-side__trail">{trailing}</span>{/if}
</button>

<style>
  .lk-side__item:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
