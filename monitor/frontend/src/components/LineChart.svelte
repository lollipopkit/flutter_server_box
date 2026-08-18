<script lang="ts">
  import { Card } from '@serverbox/webui'
  import { fmtTime, parseTimestamp } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'

  export interface ChartSeries {
    label: string
    color: string
    values: number[]
  }

  interface Props {
    /// Omit when the surrounding page already says what this chart is (e.g.
    /// a detail page's own header) — repeating it as a card title too is
    /// just noise
    title?: string
    /// Timestamps aligned index-by-index with every series' values
    labels: string[]
    series: ChartSeries[]
    /// Fixed y max (e.g. 100 for percentages); auto-scaled when absent
    yMax?: number
    format: (v: number) => string
  }

  const { title, labels, series, yMax, format }: Props = $props()

  // Rendered 1:1 at the measured container width (no preserveAspectRatio
  // scaling, which stretched axis text on wide viewports)
  let chartWidth = $state(0)
  const W = $derived(Math.max(chartWidth, 320))
  const H = 220
  const PAD = { left: 46, right: 8, top: 10, bottom: 24 }
  const plotW = $derived(W - PAD.left - PAD.right)
  const plotH = H - PAD.top - PAD.bottom

  const effectiveMax = $derived(
    yMax ?? Math.max(1, ...series.flatMap((s) => s.values)) * 1.1,
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

  function points(values: number[]): string {
    return values.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ')
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

<Card>
  <div class="flex items-center justify-between mb-2">
    {#if title}
      <h3 class="text-lg font-semibold text-fg-strong">{title}</h3>
    {:else}
      <span></span>
    {/if}
    {#if labels.length > 0}
      <span class="text-xs text-muted-fg">
        {fmtAxisTime(labels[readoutIndex])}
      </span>
    {/if}
  </div>

  <div class="flex flex-wrap gap-x-4 gap-y-1 mb-2">
    {#each series as s (s.label)}
      <span class="inline-flex items-center text-xs text-muted-fg">
        <span class="w-2.5 h-2.5 rounded-full mr-1.5" style="background: {s.color}"></span>
        {s.label}:&nbsp;
        <span class="font-medium text-fg-strong">
          {labels.length > 0 ? format(s.values[readoutIndex] ?? 0) : '--'}
        </span>
      </span>
    {/each}
  </div>

  <div bind:clientWidth={chartWidth}>
  {#if labels.length < 2}
    <div class="h-40 flex items-center justify-center text-sm text-muted-fg">
      {$LL.collectingData()}
    </div>
  {:else}
    <svg
      viewBox="0 0 {W} {H}"
      class="w-full h-[220px] touch-none"
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
          class="stroke-soft"
          stroke-width="1"
          vector-effect="non-scaling-stroke"
        />
        <text
          x={PAD.left - 6}
          y={PAD.top + plotH * f + 3}
          text-anchor="end"
          class="fill-faint-fg"
          font-size="10"
        >
          {format(effectiveMax * (1 - f))}
        </text>
      {/each}

      {#each series as s (s.label)}
        <polyline
          points={points(s.values)}
          fill="none"
          stroke={s.color}
          stroke-width="1.5"
          stroke-linejoin="round"
          vector-effect="non-scaling-stroke"
        />
      {/each}

      {#if hoverIndex !== null}
        <line
          x1={x(hoverIndex)}
          x2={x(hoverIndex)}
          y1={PAD.top}
          y2={PAD.top + plotH}
          class="stroke-faint-fg"
          stroke-width="1"
          stroke-dasharray="3 3"
          vector-effect="non-scaling-stroke"
        />
      {/if}

      <text
        x={PAD.left}
        y={H - 6}
        class="fill-faint-fg"
        font-size="10"
      >
        {fmtAxisTime(labels[0])}
      </text>
      <text
        x={W - PAD.right}
        y={H - 6}
        text-anchor="end"
        class="fill-faint-fg"
        font-size="10"
      >
        {fmtAxisTime(labels[labels.length - 1])}
      </text>
    </svg>
  {/if}
  </div>
</Card>
