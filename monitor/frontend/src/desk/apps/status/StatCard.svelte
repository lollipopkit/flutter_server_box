<script lang="ts">
  import { Card, Icon } from '../../lk'

  interface Props {
    icon: string
    iconColor: string
    label: string
    /// Primary figure, truncated to one line if needed.
    value: string
    /// Secondary line in a fixed-height row so cards remain aligned.
    detail?: string
    compact?: boolean
    class?: string
    /// Makes the card clickable and displays its drill-down affordance.
    onclick?: (e: MouseEvent) => void
  }

  const {
    icon,
    iconColor,
    label,
    value,
    detail = '',
    compact = false,
    class: className = '',
    onclick,
  }: Props = $props()

  function metricWidth(value: string): string | null {
    const match = value.match(/^(\d+(?:\.\d+)?)%$/)
    return match ? `${Math.min(100, Math.max(0, Number(match[1])))}%` : null
  }
</script>

<Card class={className} padding="11px 13px" {onclick}>
  <div class="flex min-w-0 items-start gap-[13px]">
    <span class="mt-0.5 grid h-7 w-7 shrink-0 place-items-center rounded-[9px] bg-(--surface-content) shadow-[inset_0_0_0_.5px_var(--border-hairline)]">
      <Icon name={icon} size={17} color={iconColor} />
    </span>
    <div class="min-w-0 flex-1">
      <div class="flex items-center justify-between gap-[9px]">
        <p class="truncate text-[13px] text-(--text-secondary)">{label}</p>
        {#if onclick}<Icon name="chevron_right" size={15} class="shrink-0 text-(--text-tertiary)" />{/if}
      </div>
      <p class="lk-num mt-[5px] truncate font-[650] leading-none tracking-[-.02em] text-(--text-primary) {compact ? 'text-[18px]' : 'text-[27px]' }">{value}</p>
      <p class="mt-[7px] min-h-[15px] truncate text-[12px] text-(--text-tertiary)">{detail}</p>
      {#if metricWidth(value)}
        <div class="mt-[9px] h-[3px] overflow-hidden rounded-full bg-(--surface-control)">
          <div class="h-full rounded-full" style="width: {metricWidth(value)}; background: {iconColor}"></div>
        </div>
      {/if}
    </div>
  </div>
</Card>
