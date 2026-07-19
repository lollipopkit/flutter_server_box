<script lang="ts">
  import type { Component } from 'svelte'
  import { Badge, Card, type BadgeTone } from '@serverbox/webui'

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
    tone?: BadgeTone
  }

  const {
    icon: Icon,
    iconClass,
    label,
    value,
    detail = '',
    valueClass = 'text-2xl',
    badge,
    tone = 'success',
  }: Props = $props()
</script>

<Card>
  <div class="flex items-center justify-between mb-3">
    <div class="flex items-center min-w-0">
      <Icon class="w-5 h-5 {iconClass} mr-2 shrink-0" />
      <p class="text-sm font-medium text-muted-fg truncate">{label}</p>
    </div>
    <Badge {tone} class="shrink-0 ml-2">{badge}</Badge>
  </div>
  <p class="{valueClass} leading-9 font-bold text-fg-strong truncate">{value}</p>
  <p class="text-xs text-muted-fg truncate mt-1">{detail || '\u00A0'}</p>
</Card>
