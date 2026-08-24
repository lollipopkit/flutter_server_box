<script lang="ts">
  import { ChevronDown } from '@lucide/svelte'
  import { Badge, Card } from '@serverbox/webui'
  import LineChart from './LineChart.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { fmtBytes, fmtBytesPerSec, fmtGpuPower, fmtPercent } from '../lib/format'
  import type { DiskDetail, DiskIoMetrics, HistoryPoint, IfaceMetrics, SystemMetrics } from '../types'

  export type DetailKind = 'cpu' | 'memory' | 'disk' | 'network' | 'gpu' | 'battery' | 'sensors' | 'smart'

  interface Props {
    kind: DetailKind
    metrics: SystemMetrics | null
    history: HistoryPoint[]
  }

  const { kind, metrics: m, history }: Props = $props()

  const labels = $derived(history.map((p) => p.timestamp))

  // usage_percent is resolved server-side by adapt_cpu, which is the only place
  // that knows whether used/total are cumulative ticks (Linux, needs a delta)
  // or one-shot percentage pseudo-counters (Bsd/Windows, ratio is the value).
  // null until a baseline exists on the first Linux cycle.
  const corePercents = $derived((m?.cpu_cores ?? []).map((c) => c.usage_percent))

  // Detail pages backed by the slower extended collection cycle — see the
  // freshness note rendered for these below
  const extendedKinds = new Set<DetailKind>(['battery', 'sensors', 'smart'])

  // Click-to-sort table state — one per list, since a page (disk) can show
  // more than one sortable table at once
  type SortDir = 1 | -1
  type Sort<K extends string> = { key: K; dir: SortDir }

  function toggleSort<K extends string>(current: Sort<K>, key: K): Sort<K> {
    return current.key === key ? { key, dir: (current.dir * -1) as SortDir } : { key, dir: 1 }
  }

  type DiskSortKey = 'name' | 'used' | 'percent'
  let diskSort = $state<Sort<DiskSortKey>>({ key: 'percent', dir: -1 })
  const sortedDisks = $derived(
    [...(m?.disk_details ?? [])].sort((a: DiskDetail, b: DiskDetail) => {
      const dir = diskSort.dir
      switch (diskSort.key) {
        case 'name':
          return dir * a.mount.localeCompare(b.mount)
        case 'used':
          return dir * (a.used - b.used)
        case 'percent':
          return dir * (a.usage_percent - b.usage_percent)
      }
    }),
  )

  type DiskIoSortKey = 'name' | 'read' | 'write'
  let diskioSort = $state<Sort<DiskIoSortKey>>({ key: 'name', dir: 1 })
  const sortedDiskio = $derived(
    (m?.diskio ?? [])
      .map((d: DiskIoMetrics) => ({ d, rate: m?.diskio_rate?.find((r) => r.dev === d.dev) }))
      .sort((a, b) => {
        const dir = diskioSort.dir
        switch (diskioSort.key) {
          case 'name':
            return dir * a.d.dev.localeCompare(b.d.dev)
          case 'read':
            return dir * ((a.rate?.read_bytes_per_sec ?? 0) - (b.rate?.read_bytes_per_sec ?? 0))
          case 'write':
            return dir * ((a.rate?.write_bytes_per_sec ?? 0) - (b.rate?.write_bytes_per_sec ?? 0))
        }
      }),
  )

  type IfaceSortKey = 'name' | 'rx' | 'tx'
  let ifaceSort = $state<Sort<IfaceSortKey>>({ key: 'name', dir: 1 })
  const sortedIfaces = $derived(
    [...(m?.ifaces ?? [])].sort((a: IfaceMetrics, b: IfaceMetrics) => {
      const dir = ifaceSort.dir
      switch (ifaceSort.key) {
        case 'name':
          return dir * a.name.localeCompare(b.name)
        case 'rx':
          return dir * (a.rx_bytes - b.rx_bytes)
        case 'tx':
          return dir * (a.tx_bytes - b.tx_bytes)
      }
    }),
  )
</script>

{#snippet sortTh(label: string, active: boolean, dir: 1 | -1, align: 'left' | 'right', onclick: () => void)}
  <th class={align === 'left' ? 'pr-4 text-left' : 'pl-4 text-right'}>
    <button
      type="button"
      class="inline-flex items-center gap-1 py-2 font-medium text-muted-fg hover:text-fg cursor-pointer {align ===
      'right'
        ? 'flex-row-reverse'
        : ''}"
      {onclick}
    >
      {label}
      <ChevronDown class="w-3 h-3 shrink-0 transition-transform {active ? '' : 'opacity-0'} {active && dir === 1 ? 'rotate-180' : ''}" />
    </button>
  </th>
{/snippet}

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
{#snippet coreTile(index: number, pct: number | null)}
  <div class="rounded-lg border border-line px-2.5 py-2">
    <div class="flex justify-between items-baseline gap-2 mb-1">
      <span class="text-xs text-faint-fg">{index}</span>
      <span class="text-xs font-medium text-fg tabular-nums">{pct == null ? '--' : `${pct.toFixed(0)}%`}</span>
    </div>
    {@render progressBar(pct ?? 0)}
  </div>
{/snippet}

<div class="space-y-6">
  {#if extendedKinds.has(kind) && m?.extended_updated_at}
    <!-- These fields only refresh on the agent's slower extended cycle
         (CLI-tool-bound: sensors/smartctl/battery queries) — carried
         forward unchanged in between, so a plain "last updated" on the
         system info card would misleadingly look live every poll -->
    <p class="text-xs text-faint-fg">
      {$LL.lastUpdated()}
      {new Date(m.extended_updated_at).toLocaleString()}
    </p>
  {/if}

  {#if kind === 'cpu'}
    <LineChart
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
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 sm:gap-6">
      <LineChart
        title={$LL.usage()}
        {labels}
        series={[{ label: $LL.diskUsage(), color: '#f59e0b', values: history.map((p) => p.disk) }]}
        yMax={100}
        format={fmtPercent}
      />
      {#if m?.diskio?.length}
        <LineChart
          title={$LL.diskIo()}
          {labels}
          series={[
            { label: $LL.read(), color: '#0ea5e9', values: history.map((p) => p.diskio_read_speed) },
            { label: $LL.write(), color: '#f97316', values: history.map((p) => p.diskio_write_speed) },
          ]}
          format={fmtBytesPerSec}
        />
      {/if}
    </div>
    {#if m}
      <Card>
        <table class="w-full text-sm table-fixed">
          <thead>
            <tr class="border-b border-line">
              {@render sortTh($LL.disks(), diskSort.key === 'name', diskSort.dir, 'left', () => (diskSort = toggleSort(diskSort, 'name')))}
              {@render sortTh($LL.used(), diskSort.key === 'used', diskSort.dir, 'right', () => (diskSort = toggleSort(diskSort, 'used')))}
              <th class="pl-4 w-16"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-line">
            {#each sortedDisks as d (d.path)}
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
    {#if m?.diskio?.length}
      <!-- diskio itself is a cumulative counter since boot; diskio_rate is
           the live bytes/sec derived from it each poll (empty on the
           agent's first cycle, before there's a prior sample to diff) -->
      <Card>
        <table class="w-full text-sm table-fixed">
          <thead>
            <tr class="border-b border-line">
              {@render sortTh($LL.diskIo(), diskioSort.key === 'name', diskioSort.dir, 'left', () => (diskioSort = toggleSort(diskioSort, 'name')))}
              {@render sortTh($LL.read(), diskioSort.key === 'read', diskioSort.dir, 'right', () => (diskioSort = toggleSort(diskioSort, 'read')))}
              {@render sortTh($LL.write(), diskioSort.key === 'write', diskioSort.dir, 'right', () => (diskioSort = toggleSort(diskioSort, 'write')))}
            </tr>
          </thead>
          <tbody class="divide-y divide-line">
            {#each sortedDiskio as { d, rate } (d.dev)}
              <tr>
                <td class="py-2 pr-4">
                  <span class="block truncate" title={d.dev}>{d.dev}</span>
                  <span class="block text-xs text-faint-fg truncate">
                    {$LL.read()} {fmtBytes(d.sectors_read * 512)} · {$LL.write()} {fmtBytes(d.sectors_write * 512)}
                  </span>
                </td>
                <td class="py-2 text-right whitespace-nowrap text-muted-fg">
                  {rate ? fmtBytesPerSec(rate.read_bytes_per_sec) : '--'}
                </td>
                <td class="py-2 pl-4 text-right whitespace-nowrap text-muted-fg">
                  {rate ? fmtBytesPerSec(rate.write_bytes_per_sec) : '--'}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </Card>
    {/if}
  {:else if kind === 'network'}
    <LineChart
      {labels}
      series={[
        { label: $LL.down(), color: '#8b5cf6', values: history.map((p) => p.net_rx_speed) },
        { label: $LL.up(), color: '#ec4899', values: history.map((p) => p.net_tx_speed) },
      ]}
      format={fmtBytesPerSec}
    />
    {#if m}
      <Card>
        <table class="w-full text-sm table-fixed">
          <thead>
            <tr class="border-b border-line">
              {@render sortTh($LL.interfaces(), ifaceSort.key === 'name', ifaceSort.dir, 'left', () => (ifaceSort = toggleSort(ifaceSort, 'name')))}
              {@render sortTh('RX', ifaceSort.key === 'rx', ifaceSort.dir, 'right', () => (ifaceSort = toggleSort(ifaceSort, 'rx')))}
              {@render sortTh('TX', ifaceSort.key === 'tx', ifaceSort.dir, 'right', () => (ifaceSort = toggleSort(ifaceSort, 'tx')))}
            </tr>
          </thead>
          <tbody class="divide-y divide-line">
            {#each sortedIfaces as iface (iface.name)}
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
  {:else if kind === 'battery'}
    <!-- History only tracks the first battery (matches the home page card
         and store_metrics' single battery_percent column) — multi-battery
         machines still get per-battery current-value cards below -->
    <LineChart
      {labels}
      series={[
        { label: $LL.battery(), color: '#84cc16', values: history.map((p) => p.battery_percent ?? 0) },
      ]}
      yMax={100}
      format={fmtPercent}
    />
    {#each m?.batteries ?? [] as battery, i (battery.name ?? i)}
      <Card>
        <div class="flex items-center justify-between gap-2 mb-3">
          <h3 class="text-sm font-semibold text-fg-strong truncate">
            {battery.name ?? $LL.battery()}
          </h3>
          <Badge tone={battery.status === 'charging' || battery.status === 'full' ? 'success' : 'neutral'}>
            <span class="capitalize">{battery.status}</span>
          </Badge>
        </div>
        <div class="space-y-4">
          {@render labeledBar($LL.usage(), `${battery.percent ?? '--'}%`, battery.percent ?? 0)}
          {#if battery.tech}
            {@render row($LL.model(), battery.tech)}
          {/if}
          {#if battery.cycle != null}
            {@render row($LL.powerCycleCount(), String(battery.cycle))}
          {/if}
        </div>
      </Card>
    {/each}
  {:else if kind === 'sensors'}
    {#each m?.sensors ?? [] as sensor, i (`${sensor.device}-${i}`)}
      <Card>
        <h3 class="text-sm font-semibold text-fg-strong mb-3 truncate">
          {sensor.device}{sensor.adapter ? ` (${sensor.adapter})` : ''}
        </h3>
        <div class="space-y-3">
          {#each sensor.details as [label, value] (label)}
            {@render row(label, value)}
          {/each}
        </div>
      </Card>
    {/each}
  {:else if kind === 'smart'}
    {#each m?.disk_smart ?? [] as disk (disk.device)}
      <Card>
        <div class="flex items-center justify-between gap-2 mb-3">
          <h3 class="text-sm font-semibold text-fg-strong truncate">{disk.device}</h3>
          {#if disk.healthy != null}
            <Badge tone={disk.healthy ? 'success' : 'danger'}>
              {disk.healthy ? $LL.healthy() : $LL.unhealthy()}
            </Badge>
          {/if}
        </div>
        <div class="space-y-3">
          {#if disk.model}
            {@render row($LL.model(), disk.model)}
          {/if}
          {#if disk.serial}
            {@render row($LL.serial(), disk.serial)}
          {/if}
          {#if disk.temperature != null}
            {@render row($LL.temperature(), `${disk.temperature} °C`)}
          {/if}
          {#if disk.power_on_hours != null}
            {@render row($LL.powerOnHours(), String(disk.power_on_hours))}
          {/if}
          {#if disk.power_cycle_count != null}
            {@render row($LL.powerCycleCount(), String(disk.power_cycle_count))}
          {/if}
        </div>
      </Card>
    {/each}
  {/if}
</div>
