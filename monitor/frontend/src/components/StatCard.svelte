<script lang="ts">
  import type { Component } from 'svelte'

  interface Props {
    icon: Component
    iconClass: string
    label: string
    /// Primary figure, always one line (truncated if needed)
    value: string
    /// Secondary line; rendered as a fixed-height row so all cards align
    detail?: string
    valueClass?: string
    badge: string
    badgeClass: string
  }

  const {
    icon: Icon,
    iconClass,
    label,
    value,
    detail = '',
    valueClass = 'text-2xl',
    badge,
    badgeClass,
  }: Props = $props()
</script>

<div class="card">
  <div class="flex items-center justify-between mb-3">
    <div class="flex items-center min-w-0">
      <Icon class="w-5 h-5 {iconClass} mr-2 shrink-0" />
      <p class="text-sm font-medium text-muted truncate">{label}</p>
    </div>
    <span class="{badgeClass} shrink-0 ml-2">{badge}</span>
  </div>
  <p class="{valueClass} leading-9 font-bold text-strong truncate">{value}</p>
  <p class="text-xs text-muted truncate mt-1">{detail || ' '}</p>
</div>
