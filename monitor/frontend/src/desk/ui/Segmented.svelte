<script lang="ts" generics="T extends string">
  import type { Component } from 'svelte'

  /// A choice of a few views or values, side by side: a bordered strip, the
  /// chosen one tinted with the accent.

  interface Option {
    value: T
    label: string
    icon?: Component
    /// Shows only the icon, the label as its tooltip.
    iconOnly?: boolean
  }

  interface Props {
    options: Option[]
    value: T
    onchange: (value: T) => void
    /// Stretches to the width it is given, each option an equal share.
    block?: boolean
    /// Names the group for a screen reader.
    label?: string
  }

  const { options, value, onchange, block = false, label }: Props = $props()
</script>

<div
  class="{block ? 'flex w-full' : 'inline-flex'} gap-0.5 rounded-[0.625rem] border border-line p-0.5"
  role="group"
  aria-label={label}
>
  {#each options as opt (opt.value)}
    {@const chosen = opt.value === value}
    <button
      type="button"
      class="flex items-center justify-center gap-1.5 rounded-[0.5rem] px-2.5 py-1 text-[0.8rem] transition-colors {chosen
        ? 'desk-chosen font-semibold text-fg-strong'
        : 'text-muted-fg hover:bg-soft hover:text-fg'}"
      class:flex-1={block}
      aria-pressed={chosen}
      aria-label={opt.iconOnly ? opt.label : undefined}
      title={opt.iconOnly ? opt.label : undefined}
      onclick={() => onchange(opt.value)}
    >
      {#if opt.icon}<opt.icon class="h-4 w-4 shrink-0" />{/if}
      {#if !opt.iconOnly}<span class="truncate">{opt.label}</span>{/if}
    </button>
  {/each}
</div>
