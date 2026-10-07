<script lang="ts">
  import type { Component, Snippet } from 'svelte'

  /// TODO: remove once every app uses `lk/SidebarItem` (glyph names) — a
  /// compatibility shim drawing a lucide icon in the design system's row.

  interface Props {
    label: string
    icon?: Component
    selected?: boolean
    title?: string
    trailing?: Snippet
    onclick: () => void
  }

  const { label, icon: Icon, selected = false, title, trailing, onclick }: Props = $props()
</script>

<button
  type="button"
  class="lk-side__item w-full text-left"
  class:lk-side__item--on={selected}
  aria-current={selected ? 'true' : undefined}
  {title}
  {onclick}
>
  {#if Icon}<Icon class="h-[17px] w-[17px] shrink-0 text-(--color-accent-text)" />{/if}
  <span class="lk-side__label">{label}</span>
  {#if trailing}<span class="lk-side__trail">{@render trailing()}</span>{/if}
</button>
