<script lang="ts">
  import type { Component } from 'svelte'
  import { ChevronRight } from '@lucide/svelte'
  import { Card } from '@serverbox/webui'

  interface Props {
    icon: Component
    iconClass: string
    label: string
    /// Primary figure, truncated to one line if needed.
    value: string
    /// Secondary line in a fixed-height row so cards remain aligned.
    detail?: string
    valueClass?: string
    class?: string
    /// Makes the card clickable and displays its drill-down affordance.
    onclick?: (e: MouseEvent) => void
  }

  const {
    icon: Icon,
    iconClass,
    label,
    value,
    detail = '',
    valueClass = 'text-2xl',
    class: className = '',
    onclick,
  }: Props = $props()
</script>

<Card class="group rounded-2xl {className}" {onclick}>
  <div class="flex min-w-0 items-start gap-2.5">
    <span class="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-soft">
      <Icon class="h-4 w-4 {iconClass}" />
    </span>
    <div class="min-w-0 flex-1">
      <div class="flex items-center justify-between gap-2">
        <p class="truncate text-[0.78rem] font-medium text-muted-fg">{label}</p>
        {#if onclick}
          <ChevronRight class="h-3.5 w-3.5 shrink-0 text-faint-fg transition-transform group-hover:translate-x-0.5" />
        {/if}
      </div>
      <p class="{valueClass} mt-1 leading-tight font-semibold tracking-tight text-fg-strong truncate">{value}</p>
      <p class="mt-1 truncate text-[0.7rem] text-muted-fg">{detail || ' '}</p>
    </div>
  </div>
</Card>
