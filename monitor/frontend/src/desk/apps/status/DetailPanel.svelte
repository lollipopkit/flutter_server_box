<script lang="ts">
  import { Badge, Card, Icon } from '../../lk'
  import LineChart from '../../../components/LineChart.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { fmtBytes, fmtBytesPerSec, fmtGpuPower, fmtPercent } from '../../../lib/format'
  import type { DiskDetail, DiskIoMetrics, HistoryPoint, IfaceMetrics, SystemMetrics } from '../../../types'

  export type DetailKind = 'cpu' | 'memory' | 'disk' | 'network' | 'gpu' | 'battery' | 'sensors' | 'smart'

  interface Props {
    kind: DetailKind
    metrics: SystemMetrics | null
    history: HistoryPoint[]
  }

  const { kind, metrics: m, history }: Props = $props()

  const labels = $derived(history.map((p) => p.timestamp))
  const chartOne = 'var(--color-accent)'
  const chartTwo = 'var(--hue-blue)'

  // `adapt_cpu` resolves cumulative Linux ticks and one-shot BSD/Windows
  // counters into percentages. The first Linux sample has no baseline.
  const corePercents = $derived((m?.cpu_cores ?? []).map((c) => c.usage_percent))

  // These pages use the slower extended collection cycle and display its
  // freshness note below.
  const extendedKinds = new Set<DetailKind>(['battery', 'sensors', 'smart'])

  // Keep sort state per list because the disk page contains multiple tables.
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
          return dir * compareCounters(a.rx_bytes_exact, a.rx_bytes, b.rx_bytes_exact, b.rx_bytes)
        case 'tx':
          return dir * compareCounters(a.tx_bytes_exact, a.tx_bytes, b.tx_bytes_exact, b.tx_bytes)
      }
    }),
  )

  function compareCounters(
    aExact: string | undefined,
    aFallback: number,
    bExact: string | undefined,
    bFallback: number,
  ): number {
    const a = BigInt(aExact ?? Math.trunc(aFallback))
    const b = BigInt(bExact ?? Math.trunc(bFallback))
    return a < b ? -1 : a > b ? 1 : 0
  }

  function sectorBytes(exact: string | undefined, fallback: number): number | bigint {
    return exact === undefined ? fallback * 512 : BigInt(exact) * 512n
  }
</script>

{#snippet sortTh(label: string, active: boolean, dir: 1 | -1, align: 'left' | 'right', onclick: () => void)}
  <th class="lk-caps {align === 'left' ? 'text-left' : 'text-right'}">
    <button type="button" class="inline-flex items-center gap-[5px] py-[7px] text-(--text-secondary) hover:text-(--text-primary)" {onclick}>
      {#if active && dir === -1}<Icon name="arrow_downward" size={12} />{/if}
      {label}
      {#if active && dir === 1}<Icon name="arrow_upward" size={12} />{/if}
    </button>
  </th>
{/snippet}

{#snippet row(label: string, value: string)}
  <div class="flex justify-between gap-[9px] border-t border-(--border-hairline) py-[7px] text-[13px] first:border-0">
    <span class="text-(--text-secondary)">{label}</span>
    <span class="lk-num truncate text-right">{value}</span>
  </div>
{/snippet}

<!-- Inline progress bar; fill color follows a usage threshold -->
{#snippet progressBar(pct: number)}
  {@const clamped = Math.min(Math.max(pct, 0), 100)}
  <div class="h-[3px] w-full overflow-hidden rounded-full bg-(--surface-control)">
    <div
      class="h-full rounded-full"
      class:bg-(--color-success)={clamped < 70}
      class:bg-(--color-warning)={clamped >= 70 && clamped < 90}
      class:bg-(--color-danger)={clamped >= 90}
      style="width: {clamped}%"
    ></div>
  </div>
{/snippet}

{#snippet labeledBar(label: string, value: string, pct: number)}
  <div class="space-y-[7px]">
    <div class="flex justify-between gap-[9px] text-[13px]">
      <span class="text-(--text-secondary)">{label}</span>
      <span class="lk-num truncate text-right">{value}</span>
    </div>
    {@render progressBar(pct)}
  </div>
{/snippet}

<!-- Compact per-core tile: index + percent on top, thin bar below. Sized to
     fit many columns so high core-count machines don't produce a page-long list. -->
{#snippet coreTile(index: number, pct: number | null)}
  <div class="rounded-[9px] bg-(--surface-content) px-[9px] py-[7px] shadow-[inset_0_0_0_.5px_var(--border-hairline)]">
    <div class="mb-[5px] flex items-baseline justify-between gap-[7px]">
      <span class="text-[12px] text-(--text-tertiary)">{index}</span>
      <span class="lk-num text-[12px] text-(--text-primary)">{pct == null ? '--' : `${pct.toFixed(0)}%`}</span>
    </div>
    {@render progressBar(pct ?? 0)}
  </div>
{/snippet}

<div class="status-detail space-y-[13px]">
  {#if extendedKinds.has(kind) && m?.extended_updated_at}
    <!-- These fields only refresh on the agent's slower extended cycle
         (CLI-tool-bound: sensors/smartctl/battery queries) — carried
         forward unchanged in between, so a plain "last updated" on the
         system info card would misleadingly look live every poll -->
    <p class="text-[12px] text-(--text-tertiary)">
      {$LL.lastUpdated()}
      {new Date(m.extended_updated_at).toLocaleString()}
    </p>
  {/if}

  {#if kind === 'cpu'}
    <LineChart
      {labels}
      series={[{ label: 'CPU', color: chartOne, values: history.map((p) => p.cpu) }]}
      yMax={100}
      format={fmtPercent}
    />
    {#if m}
      <Card>
        <div class="space-y-[13px]">
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
        <h3 class="mb-[9px] text-[15px] font-semibold text-(--text-primary)">
          {$LL.cores()} ({corePercents.length})
        </h3>
        <div class="grid grid-cols-3 @2xl:grid-cols-4 @3xl:grid-cols-6 gap-[7px]">
          {#each corePercents as pct, i (i)}
            {@render coreTile(i, pct)}
          {/each}
        </div>
      </Card>
    {/if}
  {:else if kind === 'memory'}
    <LineChart
      {labels}
      series={[{ label: $LL.memory(), color: chartOne, values: history.map((p) => p.memory) }]}
      yMax={100}
      format={fmtPercent}
    />
    {#if m}
      <Card>
        <div class="space-y-[13px]">
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
    <div class="grid grid-cols-1 @5xl:grid-cols-2 gap-[9px] @2xl:gap-6">
      <LineChart
        title={$LL.usage()}
        {labels}
        series={[{ label: $LL.diskUsage(), color: chartOne, values: history.map((p) => p.disk) }]}
        yMax={100}
        format={fmtPercent}
      />
      {#if m?.diskio?.length}
        <LineChart
          title={$LL.diskIo()}
          {labels}
          series={[
            { label: $LL.read(), color: chartOne, values: history.map((p) => p.diskio_read_speed) },
            { label: $LL.write(), color: chartTwo, values: history.map((p) => p.diskio_write_speed) },
          ]}
          format={fmtBytesPerSec}
        />
      {/if}
    </div>
    {#if m}
      <Card>
        <table class="status-table w-full table-fixed">
          <thead>
            <tr class="border-b border-(--border-hairline)">
              {@render sortTh($LL.disks(), diskSort.key === 'name', diskSort.dir, 'left', () => (diskSort = toggleSort(diskSort, 'name')))}
              {@render sortTh($LL.used(), diskSort.key === 'used', diskSort.dir, 'right', () => (diskSort = toggleSort(diskSort, 'used')))}
              <th class="pl-4 w-16"></th>
            </tr>
          </thead>
          <tbody>
            {#each sortedDisks as d (`${d.path}\u0000${d.mount}`)}
              <tr>
                <td class="py-2 pr-4 align-top">
                  <div
                    class="max-w-[240px] @2xl:max-w-[340px]"
                    title={`${d.mount} (${d.path})`}
                  >
                    <span class="block text-(--text-primary) truncate">{d.mount}</span>
                    <span class="lk-mono block truncate text-[12px] text-(--text-tertiary)">
                      {d.path}{d.fs_type ? ` · ${d.fs_type}` : ''}
                    </span>
                  </div>
                </td>
                <td class="lk-num w-28 whitespace-nowrap py-[7px] text-right text-[12px] text-(--text-tertiary) @2xl:w-36">
                  {fmtBytes(d.used)} / {fmtBytes(d.total)}
                </td>
                <td class="py-2 pl-4 text-right font-medium text-(--text-primary) w-16">
                  {d.usage_percent.toFixed(1)}%
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
        <div class="status-table__status lk-num">
          {$LL.disks()} · {sortedDisks.length}
        </div>
      </Card>
    {/if}
    {#if m?.diskio?.length}
      <!-- diskio itself is a cumulative counter since boot; diskio_rate is
           the live bytes/sec derived from it each poll (empty on the
           agent's first cycle, before there's a prior sample to diff) -->
      <Card>
        <table class="status-table w-full table-fixed">
          <thead>
            <tr class="border-b border-(--border-hairline)">
              {@render sortTh($LL.diskIo(), diskioSort.key === 'name', diskioSort.dir, 'left', () => (diskioSort = toggleSort(diskioSort, 'name')))}
              {@render sortTh($LL.read(), diskioSort.key === 'read', diskioSort.dir, 'right', () => (diskioSort = toggleSort(diskioSort, 'read')))}
              {@render sortTh($LL.write(), diskioSort.key === 'write', diskioSort.dir, 'right', () => (diskioSort = toggleSort(diskioSort, 'write')))}
            </tr>
          </thead>
          <tbody>
            {#each sortedDiskio as { d, rate } (d.dev)}
              <tr>
                <td class="py-2 pr-4">
                  <span class="block truncate" title={d.dev}>{d.dev}</span>
                  <span class="lk-mono block truncate text-[12px] text-(--text-tertiary)">
                    {$LL.read()} {fmtBytes(sectorBytes(d.sectors_read_exact, d.sectors_read))} · {$LL.write()} {fmtBytes(sectorBytes(d.sectors_write_exact, d.sectors_write))}
                  </span>
                </td>
                <td class="lk-num whitespace-nowrap py-[7px] text-right text-[12px] text-(--text-tertiary)">
                  {rate ? fmtBytesPerSec(rate.read_bytes_per_sec) : '--'}
                </td>
                <td class="lk-num whitespace-nowrap py-[7px] pl-[13px] text-right text-[12px] text-(--text-tertiary)">
                  {rate ? fmtBytesPerSec(rate.write_bytes_per_sec) : '--'}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
        <div class="status-table__status lk-num">
          {$LL.diskIo()} · {sortedDiskio.length}
        </div>
      </Card>
    {/if}
  {:else if kind === 'network'}
    <LineChart
      {labels}
      series={[
        { label: $LL.down(), color: chartOne, values: history.map((p) => p.net_rx_speed) },
        { label: $LL.up(), color: chartTwo, values: history.map((p) => p.net_tx_speed) },
      ]}
      format={fmtBytesPerSec}
    />
    {#if m}
      <Card>
        <table class="status-table w-full table-fixed">
          <thead>
            <tr class="border-b border-(--border-hairline)">
              {@render sortTh($LL.interfaces(), ifaceSort.key === 'name', ifaceSort.dir, 'left', () => (ifaceSort = toggleSort(ifaceSort, 'name')))}
              {@render sortTh('RX', ifaceSort.key === 'rx', ifaceSort.dir, 'right', () => (ifaceSort = toggleSort(ifaceSort, 'rx')))}
              {@render sortTh('TX', ifaceSort.key === 'tx', ifaceSort.dir, 'right', () => (ifaceSort = toggleSort(ifaceSort, 'tx')))}
            </tr>
          </thead>
          <tbody>
            {#each sortedIfaces as iface (iface.name)}
              <tr>
                <td class="py-2 pr-4">
                  <span class="block truncate" title={iface.name}>{iface.name}</span>
                </td>
                <td class="lk-num whitespace-nowrap py-[7px] text-right text-[12px] text-(--text-tertiary)">
                  {fmtBytes(iface.rx_bytes_exact ?? iface.rx_bytes)}
                </td>
                <td class="lk-num whitespace-nowrap py-[7px] pl-[13px] text-right text-[12px] text-(--text-tertiary)">
                  {fmtBytes(iface.tx_bytes_exact ?? iface.tx_bytes)}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
        <div class="status-table__status lk-num">
          {$LL.interfaces()} · {sortedIfaces.length}
        </div>
      </Card>
    {/if}
  {:else if kind === 'gpu'}
    {#each m?.gpus ?? [] as gpu (gpu.id ?? gpu.name)}
      <Card>
        <h3 class="mb-[9px] truncate text-[15px] font-semibold text-(--text-primary)">
          {gpu.name}{gpu.id ? ` · ${gpu.id}` : ''}
        </h3>
        <div class="space-y-[13px]">
          {#if gpu.usage_percent != null}
            {@render labeledBar($LL.usage(), `${gpu.usage_percent.toFixed(0)}%`, gpu.usage_percent)}
          {/if}
          {#if gpu.memory_used != null && gpu.memory_total != null && gpu.memory_unit != null}
            {@render row($LL.memory(), `${gpu.memory_used} / ${gpu.memory_total} ${gpu.memory_unit}`)}
          {/if}
          {#if gpu.temperature != null}
            {@render row($LL.temperature(), `${gpu.temperature} °C`)}
          {/if}
          {#if gpu.power != null}
            {@render row($LL.power(), fmtGpuPower(gpu.power))}
          {/if}
          {#if gpu.fan_speed != null}
            {@render row('Fan', `${gpu.fan_speed}${gpu.vendor === 'nvidia' ? '%' : ' RPM'}`)}
          {/if}
          {#if gpu.clock_speed != null}
            {@render row('Clock', `${gpu.clock_speed} MHz`)}
          {/if}
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
        { label: $LL.battery(), color: chartOne, values: history.map((p) => p.battery_percent ?? null) },
      ]}
      yMax={100}
      format={fmtPercent}
    />
    {#each m?.batteries ?? [] as battery, i (`${battery.name ?? 'battery'}-${i}`)}
      <Card>
        <div class="flex items-center justify-between gap-[7px] mb-3">
          <h3 class="truncate text-[15px] font-semibold text-(--text-primary)">
            {battery.name ?? $LL.battery()}
          </h3>
          <Badge tone={battery.status === 'charging' || battery.status === 'full' ? 'success' : 'neutral'}>
            <span class="capitalize">{battery.status}</span>
          </Badge>
        </div>
        <div class="space-y-[13px]">
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
        <h3 class="mb-[9px] truncate text-[15px] font-semibold text-(--text-primary)">
          {sensor.device}{sensor.adapter ? ` (${sensor.adapter})` : ''}
        </h3>
        <div class="space-y-[9px]">
          {#each sensor.details as [label, value] (label)}
            {@render row(label, value)}
          {/each}
        </div>
      </Card>
    {/each}
  {:else if kind === 'smart'}
    {#each m?.disk_smart ?? [] as disk (disk.device)}
      <Card>
        <div class="flex items-center justify-between gap-[7px] mb-3">
          <h3 class="truncate text-[15px] font-semibold text-(--text-primary)">{disk.device}</h3>
          {#if disk.healthy != null}
            <Badge tone={disk.healthy ? 'success' : 'danger'}>
              {disk.healthy ? $LL.healthy() : $LL.unhealthy()}
            </Badge>
          {/if}
        </div>
        <div class="space-y-[9px]">
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

<style>
  .status-table {
    border-collapse: separate;
    border-spacing: 0 2px;
  }

  .status-table thead {
    position: sticky;
    top: 0;
    z-index: 1;
    background: var(--surface-window);
  }

  .status-table tbody tr {
    height: 28px;
  }

  .status-table tbody tr:nth-child(even) {
    background: var(--fill-hover);
  }

  .status-table tbody tr:hover {
    background: var(--fill-hover);
  }

  .status-table__status {
    display: flex;
    height: 28px;
    align-items: center;
    border-top: 0.5px solid var(--border-hairline);
    color: var(--text-tertiary);
    font-size: 12px;
  }

  .status-table tbody td:first-child {
    border-radius: 7px 0 0 7px;
  }

  .status-table tbody td:last-child {
    border-radius: 0 7px 7px 0;
  }
</style>
