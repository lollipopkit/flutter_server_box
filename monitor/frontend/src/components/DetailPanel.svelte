<script lang="ts">
  import { ChevronLeft } from '@lucide/svelte'
  import { Button, Card } from '@serverbox/webui'
  import LineChart from './LineChart.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { fmtBytes, fmtBytesPerSec, fmtGpuPower, fmtPercent } from '../lib/format'
  import type { HistoryPoint, SystemMetrics } from '../types'

  export type DetailKind = 'cpu' | 'memory' | 'disk' | 'network' | 'gpu'

  interface Props {
    kind: DetailKind
    metrics: SystemMetrics | null
    history: HistoryPoint[]
    onback: () => void
  }

  const { kind, metrics: m, history, onback }: Props = $props()

  const labels = $derived(history.map((p) => p.timestamp))

  const titles = $derived({
    cpu: $LL.cpuUsage(),
    memory: $LL.memory(),
    disk: $LL.diskUsage(),
    network: $LL.network(),
    gpu: $LL.gpu(),
  })

  // used/total are cumulative busy/total ticks (CpuCoreTime); percent is
  // used/total, not the inverse (a prior review flagged the DB storage path
  // computing this backwards — this display path is independently correct)
  const corePercents = $derived(
    (m?.cpu_cores ?? []).map((c) => (c.total > 0 ? (c.used / c.total) * 100 : 0)),
  )
</script>

{#snippet row(label: string, value: string)}
  <div class="flex justify-between gap-4">
    <span class="text-sm text-muted-fg">{label}</span>
    <span class="text-sm font-medium text-fg truncate">{value}</span>
  </div>
{/snippet}

<!-- Inline progress bar; fill color follows a usage threshold -->
{#snippet progressBar(pct: number)}
  {@const clamped = Math.min(Math.max(pct, 0), 100)}
  <div class="w-full h-2 rounded-full bg-soft overflow-hidden">
    <div
      class="h-full rounded-full {clamped < 70
        ? 'bg-success'
        : clamped < 90
          ? 'bg-warning'
          : 'bg-danger'}"
      style="width: {clamped}%"
    ></div>
  </div>
{/snippet}

{#snippet labeledBar(label: string, value: string, pct: number)}
  <div class="space-y-1.5">
    <div class="flex justify-between gap-4">
      <span class="text-sm text-muted-fg">{label}</span>
      <span class="text-sm font-medium text-fg truncate">{value}</span>
    </div>
    {@render progressBar(pct)}
  </div>
{/snippet}

<!-- Compact per-core tile: index + percent on top, thin bar below. Sized to
     fit many columns so high core-count machines don't produce a page-long list. -->
{#snippet coreTile(index: number, pct: number)}
  <div class="rounded-lg border border-line px-2.5 py-2">
    <div class="flex justify-between items-baseline gap-2 mb-1">
      <span class="text-xs text-faint-fg">{index}</span>
      <span class="text-xs font-medium text-fg tabular-nums">{pct.toFixed(0)}%</span>
    </div>
    {@render progressBar(pct)}
  </div>
{/snippet}

<div class="space-y-6">
  <div class="flex items-center gap-2">
    <Button variant="ghost" size="sm" onclick={onback}>
      <ChevronLeft class="w-4 h-4 mr-1" />
      {$LL.back()}
    </Button>
    <h2 class="text-lg font-semibold font-display text-fg-strong">{titles[kind]}</h2>
  </div>

  {#if kind === 'cpu'}
    <LineChart
      title={$LL.usage()}
      {labels}
      series={[{ label: 'CPU', color: '#3b82f6', values: history.map((p) => p.cpu) }]}
      yMax={100}
      format={fmtPercent}
    />
    {#if m}
      <Card>
        <div class="space-y-4">
          {#if m.cpu_brand}
            {@render row($LL.cpuModel(), m.cpu_brand)}
          {/if}
          {@render labeledBar($LL.usage(), `${m.cpu_usage.toFixed(1)}%`, m.cpu_usage)}
          {#if !corePercents.length}
            {@render row($LL.cores(), String(m.cpu_cores?.length ?? '--'))}
          {/if}
          {#if m.temperature != null}
            {@render row($LL.temperature(), `${m.temperature.toFixed(1)} °C`)}
          {/if}
        </div>
      </Card>
    {/if}
    {#if corePercents.length > 0}
      <Card>
        <h3 class="text-sm font-semibold text-fg-strong mb-3">
          {$LL.cores()} ({corePercents.length})
        </h3>
        <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-2">
          {#each corePercents as pct, i (i)}
            {@render coreTile(i, pct)}
          {/each}
        </div>
      </Card>
    {/if}
  {:else if kind === 'memory'}
    <LineChart
      title={$LL.usage()}
      {labels}
      series={[{ label: $LL.memory(), color: '#22c55e', values: history.map((p) => p.memory) }]}
      yMax={100}
      format={fmtPercent}
    />
    {#if m}
      <Card>
        <div class="space-y-4">
          {@render labeledBar(
            $LL.memory(),
            `${fmtBytes(m.memory.used)} / ${fmtBytes(m.memory.total)} (${m.memory.usage_percent.toFixed(1)}%)`,
            m.memory.usage_percent,
          )}
          {#if m.swap.total > 0}
            {@render labeledBar(
              $LL.swap(),
              `${fmtBytes(m.swap.used)} / ${fmtBytes(m.swap.total)} (${m.swap.usage_percent.toFixed(1)}%)`,
              m.swap.usage_percent,
            )}
          {/if}
        </div>
      </Card>
    {/if}
  {:else if kind === 'disk'}
    <LineChart
      title={$LL.usage()}
      {labels}
      series={[{ label: $LL.diskUsage(), color: '#f59e0b', values: history.map((p) => p.disk) }]}
      yMax={100}
      format={fmtPercent}
    />
    {#if m}
      <Card>
        <h3 class="text-sm font-semibold text-fg-strong mb-3">{$LL.disks()}</h3>
        <table class="w-full text-sm table-fixed">
          <tbody class="divide-y divide-line">
            {#each m.disk_details ?? [] as d (d.path)}
              <tr>
                <td class="py-2 pr-4 align-top">
                  <div
                    class="max-w-[240px] sm:max-w-[340px]"
                    title={`${d.mount} (${d.path})`}
                  >
                    <span class="block text-fg truncate">{d.mount}</span>
                    <span class="block text-xs text-faint-fg truncate">
                      {d.path}{d.fs_type ? ` · ${d.fs_type}` : ''}
                    </span>
                  </div>
                </td>
                <td class="py-2 text-right whitespace-nowrap text-muted-fg w-28 sm:w-36">
                  {fmtBytes(d.used)} / {fmtBytes(d.total)}
                </td>
                <td class="py-2 pl-4 text-right font-medium text-fg w-16">
                  {d.usage_percent.toFixed(1)}%
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </Card>
    {/if}
  {:else if kind === 'network'}
    <LineChart
      title={$LL.network()}
      {labels}
      series={[
        { label: $LL.down(), color: '#8b5cf6', values: history.map((p) => p.net_rx_speed) },
        { label: $LL.up(), color: '#ec4899', values: history.map((p) => p.net_tx_speed) },
      ]}
      format={fmtBytesPerSec}
    />
    {#if m}
      <Card>
        <h3 class="text-sm font-semibold text-fg-strong mb-3">{$LL.interfaces()}</h3>
        <table class="w-full text-sm table-fixed">
          <thead>
            <tr class="border-b border-line">
              <th class="py-2 pr-4 text-left font-medium text-muted-fg">{$LL.interfaces()}</th>
              <th class="py-2 text-right font-medium text-muted-fg w-24 sm:w-32">RX</th>
              <th class="py-2 pl-4 text-right font-medium text-muted-fg w-24 sm:w-32">TX</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-line">
            {#each m.ifaces ?? [] as iface (iface.name)}
              <tr>
                <td class="py-2 pr-4">
                  <span class="block truncate" title={iface.name}>{iface.name}</span>
                </td>
                <td class="py-2 text-right whitespace-nowrap text-muted-fg">
                  {fmtBytes(iface.rx_bytes)}
                </td>
                <td class="py-2 pl-4 text-right whitespace-nowrap text-muted-fg">
                  {fmtBytes(iface.tx_bytes)}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </Card>
    {/if}
  {:else if kind === 'gpu'}
    {#each m?.gpus ?? [] as gpu (gpu.name)}
      <Card>
        <h3 class="text-sm font-semibold text-fg-strong mb-3 truncate">{gpu.name}</h3>
        <div class="space-y-4">
          {@render labeledBar($LL.usage(), `${gpu.usage_percent.toFixed(0)}%`, gpu.usage_percent)}
          {@render row($LL.memory(), `${gpu.memory_used} / ${gpu.memory_total} ${gpu.memory_unit}`)}
          {@render row($LL.temperature(), `${gpu.temperature} °C`)}
          {@render row($LL.power(), fmtGpuPower(gpu.power))}
        </div>
      </Card>
    {/each}
  {/if}
</div>
