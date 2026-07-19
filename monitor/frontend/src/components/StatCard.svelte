<script lang="ts">
  import type { Component } from 'svelte'
  import { ChevronRight } from '@lucide/svelte'
  import { Card } from '@serverbox/webui'

  interface Props {
    icon: Component
    iconClass: string
    label: string
    /// Primary figure, always one line (truncated if needed)
    value: string
    /// Secondary line; rendered as a fixed-height row so all cards align
    detail?: string
    valueClass?: string
    class?: string
    /// Makes the card clickable (drill-down affordance)
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

<Card class={className} {onclick}>
  <div class="flex items-center justify-between mb-3">
    <div class="flex items-center min-w-0">
      <Icon class="w-5 h-5 {iconClass} mr-2 shrink-0" />
      <p class="text-sm font-medium text-muted-fg truncate">{label}</p>
    </div>
    {#if onclick}
      <ChevronRight class="w-4 h-4 text-faint-fg shrink-0 ml-2" />
    {/if}
  </div>
  <p class="{valueClass} leading-9 font-bold text-fg-strong truncate">{value}</p>
  <p class="text-xs text-muted-fg truncate mt-1">{detail || ' '}</p>
</Card>
