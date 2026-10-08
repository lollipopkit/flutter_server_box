<script lang="ts">
  import Card from '@lollipopkit/desk-ui/Card.svelte'
  import { fmtTime, parseTimestamp } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'

  export interface ChartSeries {
    label: string
    color: string
    values: (number | null)[]
  }

  interface Props {
    /// Omit when the surrounding page already says what this chart is (e.g.
    /// a detail page with its own header).
    title?: string
    /// Timestamps aligned index-by-index with every series' values.
    labels: string[]
    series: ChartSeries[]
    /// Fixed y-axis maximum (e.g. 100 for percentages); auto-scaled when absent.
    yMax?: number
    format: (v: number) => string
  }

  const { title, labels, series, yMax, format }: Props = $props()

  // Render at the measured width rather than scaling the SVG, which distorts
  // axis labels on wide viewports.
  let chartWidth = $state(0)
  const W = $derived(Math.max(chartWidth, 320))
  const H = 220
  const PAD = { left: 46, right: 8, top: 10, bottom: 24 }
  const plotW = $derived(W - PAD.left - PAD.right)
  const plotH = H - PAD.top - PAD.bottom

  const effectiveMax = $derived(
    yMax ??
      Math.max(
        1,
        ...series.flatMap((s) => s.values.filter((v): v is number => v !== null)),
      ) *
        1.1,
  )

  // Whether this range's endpoints fall on different calendar days — once
  // true, every timestamp rendered for this chart includes the date, not
  // just "08:00 AM" repeated with no way to tell which day it's from
  const spansMultipleDays = $derived(
    labels.length > 1 &&
      parseTimestamp(labels[0]).toDateString() !==
        parseTimestamp(labels[labels.length - 1]).toDateString(),
  )

  function fmtAxisTime(ts: string): string {
    return fmtTime(ts, { withDate: spansMultipleDays })
  }

  function x(i: number): number {
    const n = Math.max(labels.length - 1, 1)
    return PAD.left + (i / n) * plotW
  }

  function y(v: number): number {
    return PAD.top + plotH - (Math.min(Math.max(v, 0), effectiveMax) / effectiveMax) * plotH
  }

  /// Each unbroken run of values: its line, and the area under it down to
  /// the axis (the design system shades it at 8%).
  function segments(values: (number | null)[]): { line: string; area: string }[] {
    const result: { line: string; area: string }[] = []
    let current: { x: number; y: number }[] = []
    const flush = () => {
      if (current.length === 0) return
      const line = current.map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ')
      const base = (PAD.top + plotH).toFixed(1)
      const area = `${current[0].x.toFixed(1)},${base} ${line} ${current[current.length - 1].x.toFixed(1)},${base}`
      result.push({ line, area })
      current = []
    }
    values.forEach((v, i) => {
      if (v === null) flush()
      else current.push({ x: x(i), y: y(v) })
    })
    flush()
    return result
  }

  const gridFractions = [0, 0.25, 0.5, 0.75, 1]

  let hoverIndex = $state<number | null>(null)

  function onPointerMove(e: PointerEvent) {
    if (labels.length === 0) return
    const rect = (e.currentTarget as SVGSVGElement).getBoundingClientRect()
    const frac = (e.clientX - rect.left - PAD.left) / plotW
    hoverIndex = Math.min(
      labels.length - 1,
      Math.max(0, Math.round(frac * (labels.length - 1))),
    )
  }

  const readoutIndex = $derived(hoverIndex ?? labels.length - 1)
</script>

<Card variant="raised" padding="15px 17px">
  <div class="mb-[13px] flex flex-wrap items-center gap-x-[13px] gap-y-[5px]">
    {#if title}<h3 class="text-[15px] font-semibold">{title}</h3>{/if}
    {#each series as s (s.label)}
      <span class="inline-flex items-center gap-[5px] text-[12px] text-(--text-secondary)">
        <i class="h-[7px] w-[7px] rounded-full" style:background={s.color}></i>
        {s.label}
        <span class="lk-num font-semibold text-(--text-primary)">
          {labels.length > 0 && s.values[readoutIndex] != null ? format(s.values[readoutIndex]) : '--'}
        </span>
      </span>
    {/each}
    <span class="flex-1"></span>
    {#if labels.length > 0}
      <span class="lk-num text-[12px] text-(--text-tertiary)">{fmtAxisTime(labels[readoutIndex])}</span>
    {/if}
  </div>

  <div bind:clientWidth={chartWidth}>
    {#if labels.length < 2}
      <div class="flex h-40 items-center justify-center text-[13px] text-(--text-tertiary)">
        {$LL.collectingData()}
      </div>
    {:else}
      <svg
        viewBox="0 0 {W} {H}"
        class="h-[220px] w-full touch-none overflow-visible"
        role="img"
        aria-label={title ?? series.map((s) => s.label).join(', ')}
        onpointermove={onPointerMove}
        onpointerleave={() => (hoverIndex = null)}
      >
        {#each gridFractions as f (f)}
          <line
            x1={PAD.left}
            x2={W - PAD.right}
            y1={PAD.top + plotH * f}
            y2={PAD.top + plotH * f}
            stroke="var(--border-hairline)"
            stroke-width="1"
            vector-effect="non-scaling-stroke"
          />
          <text x={PAD.left - 7} y={PAD.top + plotH * f + 3} text-anchor="end" class="axis">
            {format(effectiveMax * (1 - f))}
          </text>
        {/each}

        {#each series as s (s.label)}
          {#each segments(s.values) as segment, i (`${s.label}-${i}`)}
            <polygon points={segment.area} fill={s.color} opacity="0.08" />
            <polyline
              points={segment.line}
              fill="none"
              stroke={s.color}
              stroke-width="2"
              stroke-linejoin="round"
              vector-effect="non-scaling-stroke"
            />
          {/each}
        {/each}

        {#if hoverIndex !== null}
          <line
            x1={x(hoverIndex)}
            x2={x(hoverIndex)}
            y1={PAD.top}
            y2={PAD.top + plotH}
            stroke="var(--border-strong)"
            stroke-width="1"
            stroke-dasharray="3 3"
            vector-effect="non-scaling-stroke"
          />
        {/if}

        <text x={PAD.left} y={H - 6} class="axis">{fmtAxisTime(labels[0])}</text>
        <text x={W - PAD.right} y={H - 6} text-anchor="end" class="axis">
          {fmtAxisTime(labels[labels.length - 1])}
        </text>
      </svg>
    {/if}
  </div>
</Card>

<style>
  .axis {
    fill: var(--text-tertiary);
    font-size: var(--text-11);
    font-variant-numeric: tabular-nums;
  }
</style>
