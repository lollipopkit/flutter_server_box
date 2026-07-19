<script lang="ts">
  import { fmtTime } from '../lib/format'
  import { i18n } from '../lib/i18n.svelte'

  export interface ChartSeries {
    label: string
    color: string
    values: number[]
  }

  interface Props {
    title: string
    /// Timestamps aligned index-by-index with every series' values
    labels: string[]
    series: ChartSeries[]
    /// Fixed y max (e.g. 100 for percentages); auto-scaled when absent
    yMax?: number
    format: (v: number) => string
  }

  const { title, labels, series, yMax, format }: Props = $props()

  const W = 600
  const H = 220
  const PAD = { left: 46, right: 8, top: 10, bottom: 24 }
  const plotW = W - PAD.left - PAD.right
  const plotH = H - PAD.top - PAD.bottom

  const effectiveMax = $derived(
    yMax ?? Math.max(1, ...series.flatMap((s) => s.values)) * 1.1,
  )

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
    const fx = ((e.clientX - rect.left) / rect.width) * W
    const frac = (fx - PAD.left) / plotW
    hoverIndex = Math.min(
      labels.length - 1,
      Math.max(0, Math.round(frac * (labels.length - 1))),
    )
  }

  const readoutIndex = $derived(hoverIndex ?? labels.length - 1)
</script>

<div class="card">
  <div class="flex items-center justify-between mb-2">
    <h3 class="text-lg font-semibold text-strong">{title}</h3>
    {#if labels.length > 0}
      <span class="text-xs text-gray-500 dark:text-gray-400">
        {fmtTime(labels[readoutIndex])}
      </span>
    {/if}
  </div>

  <div class="flex flex-wrap gap-x-4 gap-y-1 mb-2">
    {#each series as s (s.label)}
      <span class="inline-flex items-center text-xs text-muted">
        <span class="w-2.5 h-2.5 rounded-full mr-1.5" style="background: {s.color}"></span>
        {s.label}:&nbsp;
        <span class="font-medium text-strong">
          {labels.length > 0 ? format(s.values[readoutIndex] ?? 0) : '--'}
        </span>
      </span>
    {/each}
  </div>

  {#if labels.length < 2}
    <div class="h-40 flex items-center justify-center text-sm text-muted">
      {i18n.t('collectingData')}
    </div>
  {:else}
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <svg
      viewBox="0 0 {W} {H}"
      preserveAspectRatio="none"
      class="w-full h-48 touch-none"
      role="img"
      aria-label={title}
      onpointermove={onPointerMove}
      onpointerleave={() => (hoverIndex = null)}
    >
      {#each gridFractions as f (f)}
        <line
          x1={PAD.left}
          x2={W - PAD.right}
          y1={PAD.top + plotH * f}
          y2={PAD.top + plotH * f}
          class="stroke-gray-200 dark:stroke-gray-800"
          stroke-width="1"
          vector-effect="non-scaling-stroke"
        />
        <text
          x={PAD.left - 6}
          y={PAD.top + plotH * f + 3}
          text-anchor="end"
          class="fill-gray-400 dark:fill-gray-500"
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
          class="stroke-gray-400 dark:stroke-gray-600"
          stroke-width="1"
          stroke-dasharray="3 3"
          vector-effect="non-scaling-stroke"
        />
      {/if}

      <text
        x={PAD.left}
        y={H - 6}
        class="fill-gray-400 dark:fill-gray-500"
        font-size="10"
      >
        {fmtTime(labels[0])}
      </text>
      <text
        x={W - PAD.right}
        y={H - 6}
        text-anchor="end"
        class="fill-gray-400 dark:fill-gray-500"
        font-size="10"
      >
        {fmtTime(labels[labels.length - 1])}
      </text>
    </svg>
  {/if}
</div>
