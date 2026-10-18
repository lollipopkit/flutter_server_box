<script lang="ts">
  import Card from '../desk/lk/Card.svelte'
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

<Card variant="raised" padding="15px 17px">
  <div class="mb-[13px] flex flex-wrap items-center gap-x-[13px] gap-y-[5px]">
    {#if title}<h3 class="text-[15px] font-semibold">{title}</h3>{/if}
    {#each series as s (s.label)}
      <span class="inline-flex items-center gap-[5px] text-[12px] text-(--text-secondary)">
        <i class="h-[7px] w-[7px] rounded-full" style:background={s.color}></i>
        {s.label}
        <span class="lk-num font-semibold text-(--text-primary)">
          {labels.length > 0 ? valueAt(s, readoutIndex) : '--'}
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
      <!-- A slider to assistive technology: its value is the point it is on,
           read out by pointText. -->
      <svg
        viewBox="0 0 {W} {H}"
        class="chart h-[220px] w-full touch-none overflow-visible"
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

        {#if point !== null}
          <line
            x1={x(point)}
            x2={x(point)}
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
      <details class="mt-[9px] text-[12px]" bind:open={tableOpen}>
        <summary class="cursor-pointer text-(--text-secondary) hover:text-(--text-primary)">{$LL.chartShowData()}</summary>
        <!-- Only while open: up to MAX_POINTS rows per chart, on every refresh -->
        {#if tableOpen}
          <div class="mt-[9px] max-h-64 overflow-auto">
            <table class="lk-num w-full">
              <caption class="sr-only">{title ?? series.map((s) => s.label).join(', ')}</caption>
              <thead class="sticky top-0 bg-(--surface-raised)">
                <tr>
                  <th scope="col" class="py-[3px] pr-[13px] text-left font-semibold text-(--text-secondary)">{$LL.chartTime()}</th>
                  {#each series as s (s.label)}
                    <th scope="col" class="py-[3px] pl-[13px] text-right font-semibold text-(--text-secondary)">{s.label}</th>
                  {/each}
                </tr>
              </thead>
              <tbody>
                {#each labels as ts, i (i)}
                  <tr class="border-t border-(--border-hairline)">
                    <th scope="row" class="py-[3px] pr-[13px] text-left font-normal">{fmtAxisTime(ts)}</th>
                    {#each series as s (s.label)}
                      <td class="py-[3px] pl-[13px] text-right">{valueAt(s, i)}</td>
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

<style>
  .chart:focus-visible {
    outline: 2px solid var(--color-accent);
    outline-offset: 2px;
    border-radius: var(--radius-xs);
  }
  .axis {
    fill: var(--text-tertiary);
    font-size: var(--text-11);
    font-variant-numeric: tabular-nums;
  }
</style>
