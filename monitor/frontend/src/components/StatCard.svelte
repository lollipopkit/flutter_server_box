<script lang="ts">
  import type { Component } from 'svelte'

  interface Props {
    icon: Component
    iconClass: string
    label: string
    value: string
    valueClass?: string
    badge: string
    badgeClass: string
  }

  const {
    icon: Icon,
    iconClass,
    label,
    value,
    valueClass = 'text-2xl',
    badge,
    badgeClass,
  }: Props = $props()
</script>

<div class="card">
  <div class="flex items-center justify-between">
    <div class="flex items-center">
      <Icon class="w-8 h-8 {iconClass} mr-3" />
      <div>
        <p class="text-sm font-medium text-muted">{label}</p>
        <p class="{valueClass} font-bold text-strong whitespace-pre-line">{value}</p>
      </div>
    </div>
    <span class={badgeClass}>{badge}</span>
  </div>
</div>
