<script lang="ts">
  import type { Component, Snippet } from 'svelte'

  /// One row of a sidebar: an icon, a label, an optional count or badge.

  interface Props {
    label: string
    icon?: Component
    selected?: boolean
    /// A tooltip, for a label that had to be shortened.
    title?: string
    trailing?: Snippet
    onclick: () => void
  }

  const { label, icon: Icon, selected = false, title, trailing, onclick }: Props = $props()
</script>

<button
  class="desk-app-source flex w-full items-center gap-2 rounded-[0.625rem] px-2.5 py-1.5 text-left text-[0.8rem]"
  aria-current={selected ? 'true' : undefined}
  {title}
  {onclick}
>
  {#if Icon}<Icon class="h-4 w-4 shrink-0 opacity-75" />{/if}
  <span class="min-w-0 flex-1 truncate">{label}</span>
  {#if trailing}{@render trailing()}{/if}
</button>
