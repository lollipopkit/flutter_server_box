<script lang="ts" module>
  export interface ChartSeries {
    label: string
    color: string
    values: number[]
    /// The first series is filled under its line.
    fill?: boolean
  }
</script>

<script lang="ts">
  import { locale } from '../../../i18n/i18n-svelte'
  import { fmtDate } from '../../../lib/format'

  /// A history chart as the design draws it: lines over dashed gridlines, a
  /// scale on the left ([axis]), and a reading of every series under the
  /// pointer. Without [axis] it is the small chart of a card.

  interface Props {
    series: ChartSeries[]
    /// The time of each value, ISO.
    times: string[]
    /// The top of the scale; the largest value (with room) when absent.
    max?: number
    format: (v: number) => string
    height?: number
    axis?: boolean
    /// The x labels: the oldest, the middle, the newest.
    xLabels?: [string, string, string]
    label: string
  }

  const { series, times, max, format, height = 160, axis = false, xLabels, label }: Props = $props()

  const W = 600
  const n = $derived(Math.max(0, ...series.map((s) => s.values.length)))
  const top = $derived.by(() => {
    if (max != null) return max
    const peak = Math.max(0, ...series.flatMap((s) => s.values))
    return peak > 0 ? peak * 1.15 : 1
  })

  function path(values: number[]): string {
    if (values.length < 2) return ''
    return values
      .map((v, i) => `${i ? 'L' : 'M'}${((i / (values.length - 1)) * W).toFixed(1)} ${(height - Math.min(1, v / top) * height).toFixed(1)}`)
      .join(' ')
  }

  function area(values: number[]): string {
    const line = path(values)
    return line ? `${line} L${W} ${height} L0 ${height} Z` : ''
  }

  let hover = $state<number | null>(null)
  function onmove(e: PointerEvent) {
    if (n < 2) return
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
    hover = Math.round(Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)) * (n - 1))
  }
  const hoverX = $derived(hover === null || n < 2 ? 0 : (hover / (n - 1)) * 100)
  const hoverTime = $derived(
    hover === null || !times[hover]
      ? ''
      : fmtDate(new Date(times[hover]), { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }, $locale),
  )
</script>

<div class="flex gap-[7px]">
  {#if axis}
    <div class="lk-num -mt-[5px] flex w-[42px] shrink-0 flex-col justify-between text-right text-[11px] text-(--text-tertiary)" style:height="{height}px">
      <span>{format(top)}</span><span>{format(top / 2)}</span><span>{format(0)}</span>
    </div>
  {/if}
  <div
    class="relative min-w-0 flex-1"
    style:height="{height}px"
    role="img"
    aria-label={label}
    onpointermove={onmove}
    onpointerleave={() => (hover = null)}
  >
    {#if axis}
      <div class="pointer-events-none absolute inset-x-0 top-0 border-t-[0.5px] border-dashed border-(--border-strong)"></div>
      <div class="pointer-events-none absolute inset-x-0 top-1/2 border-t-[0.5px] border-dashed border-(--border-hairline)"></div>
      <div class="pointer-events-none absolute inset-x-0 bottom-0 border-t-[0.5px] border-(--border-strong)"></div>
    {/if}
    <svg viewBox="0 0 {W} {height}" preserveAspectRatio="none" class="absolute inset-0 h-full w-full overflow-visible">
      {#each series as s, i (s.label)}
        {#if s.fill && i === 0}<path d={area(s.values)} fill="color-mix(in srgb, {s.color} 10%, transparent)"></path>{/if}
      {/each}
      {#each [...series].reverse() as s (s.label)}
        <path d={path(s.values)} fill="none" stroke={s.color} stroke-width="1.5" stroke-linejoin="round" vector-effect="non-scaling-stroke"></path>
      {/each}
    </svg>
    {#if hover !== null}
      <div class="pointer-events-none absolute inset-y-0 w-0 border-l border-(--border-strong)" style:left="{hoverX}%"></div>
      <div
        class="chart-tip pointer-events-none absolute top-[7px] flex min-w-[110px] flex-col gap-[3px] text-[12px]"
        style:left="{hoverX}%"
        style:transform={hoverX > 70 ? 'translateX(calc(-100% - 9px))' : 'translateX(9px)'}
      >
        <span class="text-[11px] font-semibold text-(--text-tertiary)">{hoverTime}</span>
        {#each series as s (s.label)}
          {#if s.values[hover] !== undefined}
            <div class="flex items-center gap-[7px]">
              <span class="h-[7px] w-[7px] rounded-full" style:background={s.color}></span>
              <span class="flex-1 text-(--text-secondary)">{s.label}</span>
              <span class="lk-num font-bold">{format(s.values[hover])}</span>
            </div>
          {/if}
        {/each}
      </div>
    {/if}
  </div>
</div>
{#if axis && xLabels}
  <div class="flex justify-between pt-[5px] pl-[49px] text-[11px] text-(--text-tertiary)">
    <span>{xLabels[0]}</span><span>{xLabels[1]}</span><span>{xLabels[2]}</span>
  </div>
{/if}

<style>
  .chart-tip {
    padding: 7px 9px;
    border-radius: 9px;
    background: var(--glass-menu);
    backdrop-filter: var(--blur-menu);
    -webkit-backdrop-filter: var(--blur-menu);
    box-shadow: var(--shadow-popover);
  }
</style>
