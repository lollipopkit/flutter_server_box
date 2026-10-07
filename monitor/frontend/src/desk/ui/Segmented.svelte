<script lang="ts" generics="T extends string">
  import type { Component } from 'svelte'

  /// TODO: remove once every app uses `lk/SegmentedControl` (glyph names) —
  /// a compatibility shim drawing lucide icons on the design system's thumb.

  interface Option {
    value: T
    label: string
    icon?: Component
    iconOnly?: boolean
  }

  interface Props {
    options: Option[]
    value: T
    onchange: (value: T) => void
    block?: boolean
    label?: string
  }

  const { options, value, onchange, block = false, label }: Props = $props()
  const at = $derived(Math.max(0, options.findIndex((o) => o.value === value)))
</script>

<div role="group" aria-label={label} class="lk-seg" class:lk-seg--block={block}>
  <span class="lk-seg__thumb" style:width="calc((100% - 4px) / {options.length})" style:transform="translateX({at * 100}%)"></span>
  {#each options as opt (opt.value)}
    <button
      type="button"
      class="lk-seg__item"
      class:lk-seg__item--on={opt.value === value}
      aria-pressed={opt.value === value}
      aria-label={opt.iconOnly ? opt.label : undefined}
      title={opt.iconOnly ? opt.label : undefined}
      onclick={() => onchange(opt.value)}
    >
      {#if opt.icon}<opt.icon class="h-4 w-4 shrink-0" />{/if}
      {#if !opt.iconOnly}<span class="truncate">{opt.label}</span>{/if}
    </button>
  {/each}
</div>
