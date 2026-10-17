<script lang="ts">
  import { Card } from '@serverbox/webui'
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

  function segments(values: (number | null)[]): string[] {
    const result: string[] = []
    let current: string[] = []
    values.forEach((v, i) => {
      if (v === null) {
        if (current.length > 0) result.push(current.join(' '))
        current = []
      } else {
        current.push(`${x(i).toFixed(1)},${y(v).toFixed(1)}`)
      }
    })
    if (current.length > 0) result.push(current.join(' '))
    return result
  }

  const gridFractions = [0, 0.25, 0.5, 0.75, 1]

  let hoverIndex = $state<number | null>(null)
  let tableOpen = $state(false)

  function onPointerMove(e: PointerEvent) {
    if (labels.length === 0) return
    const rect = (e.currentTarget as SVGSVGElement).getBoundingClientRect()
    if (rect.width <= 0) return
    // CSS pixels to viewBox units: below the 320 minimum the SVG is scaled down
    const vx = ((e.clientX - rect.left) * W) / rect.width
    const frac = (vx - PAD.left) / plotW
    hoverIndex = Math.min(
      labels.length - 1,
      Math.max(0, Math.round(frac * (labels.length - 1))),
    )
  }

  /// The hovered point, within the data as it is now: a refresh can bring
  /// fewer points than the one the pointer or the keyboard was on.
  const point = $derived(
    hoverIndex === null || labels.length === 0 ? null : Math.min(hoverIndex, labels.length - 1),
  )
  const readoutIndex = $derived(point ?? labels.length - 1)

  function valueAt(s: ChartSeries, i: number): string {
    const v = s.values[i]
    return v != null ? format(v) : '--'
  }

  /// One point in words: the time and every series' reading.
  function pointText(i: number): string {
    return [fmtAxisTime(labels[i]), ...series.map((s) => `${s.label}: ${valueAt(s, i)}`)].join(', ')
  }

  /// The keyboard counterpart of hovering: the arrows step through the points,
  /// Page Up/Down by a tenth, Home/End to either end.
  function onKeyDown(e: KeyboardEvent) {
    const last = labels.length - 1
    const step = Math.max(1, Math.round(labels.length / 10))
    const current = point ?? last
    let next: number
    switch (e.key) {
      case 'ArrowLeft':
      case 'ArrowDown':
        next = current - 1
        break
      case 'ArrowRight':
      case 'ArrowUp':
        next = current + 1
        break
      case 'PageDown':
        next = current - step
        break
      case 'PageUp':
        next = current + step
        break
      case 'Home':
        next = 0
        break
      case 'End':
        next = last
        break
      default:
        return
    }
    e.preventDefault()
    hoverIndex = Math.min(last, Math.max(0, next))
  }
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
          {labels.length > 0 ? valueAt(s, readoutIndex) : '--'}
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
    <!-- A slider to assistive technology: its value is the point it is on,
         read out by pointText. -->
    <svg
      viewBox="0 0 {W} {H}"
      class="w-full h-[220px] touch-none rounded-md focus-visible:outline-2 focus-visible:outline-ring"
      role="slider"
      tabindex="0"
      aria-label={title ?? series.map((s) => s.label).join(', ')}
      aria-valuemin={0}
      aria-valuemax={labels.length - 1}
      aria-valuenow={readoutIndex}
      aria-valuetext={pointText(readoutIndex)}
      onpointermove={onPointerMove}
      onpointerleave={() => (hoverIndex = null)}
      onkeydown={onKeyDown}
      onblur={() => (hoverIndex = null)}
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
        {#each segments(s.values) as segment, i (`${s.label}-${i}`)}
          <polyline
            points={segment}
            fill="none"
            stroke={s.color}
            stroke-width="1.5"
            stroke-linejoin="round"
            vector-effect="non-scaling-stroke"
          />
        {/each}
      {/each}

      {#if point !== null}
        <line
          x1={x(point)}
          x2={x(point)}
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
    <details class="mt-2 text-xs" bind:open={tableOpen}>
      <summary class="cursor-pointer text-muted-fg hover:text-fg">{$LL.chartShowData()}</summary>
      <!-- Only while open: up to MAX_POINTS rows per chart, on every refresh -->
      {#if tableOpen}
      <div class="mt-2 max-h-64 overflow-auto">
        <table class="w-full tabular-nums">
          <caption class="sr-only">{title ?? series.map((s) => s.label).join(', ')}</caption>
          <thead class="sticky top-0 bg-surface">
            <tr>
              <th scope="col" class="py-1 pr-4 text-left font-medium text-muted-fg">{$LL.chartTime()}</th>
              {#each series as s (s.label)}
                <th scope="col" class="py-1 pl-4 text-right font-medium text-muted-fg">{s.label}</th>
              {/each}
            </tr>
          </thead>
          <tbody>
            {#each labels as ts, i (i)}
              <tr class="border-t border-line">
                <th scope="row" class="py-1 pr-4 text-left font-normal text-fg">{fmtAxisTime(ts)}</th>
                {#each series as s (s.label)}
                  <td class="py-1 pl-4 text-right text-fg">{valueAt(s, i)}</td>
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      {/if}
    </details>
  {/if}
  </div>
</Card>
