<script lang="ts">
  import { ChevronLeft } from '@lucide/svelte'
  import { Button, Card } from '@serverbox/webui'
  import LineChart from './LineChart.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../lib/format'
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
</script>

{#snippet row(label: string, value: string)}
  <div class="flex justify-between gap-4">
    <span class="text-sm text-muted-fg">{label}</span>
    <span class="text-sm font-medium text-fg truncate">{value}</span>
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
    <Card>
      <div class="space-y-3">
        {@render row($LL.cores(), String(m?.cpu_cores.length ?? '--'))}
        {#if m?.temperature != null}
          {@render row($LL.temperature(), `${m.temperature.toFixed(1)} °C`)}
        {/if}
      </div>
    </Card>
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
        <div class="space-y-3">
          {@render row($LL.memory(), `${fmtBytes(m.memory.used)} / ${fmtBytes(m.memory.total)} (${m.memory.usage_percent.toFixed(1)}%)`)}
          {@render row($LL.swap(), m.swap.total > 0 ? `${fmtBytes(m.swap.used)} / ${fmtBytes(m.swap.total)} (${m.swap.usage_percent.toFixed(1)}%)` : '--')}
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
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <tbody class="divide-y divide-line">
              {#each m.disk_details as d (d.path)}
                <tr>
                  <td class="py-2 pr-4">
                    <span class="block text-fg truncate">{d.mount}</span>
                    <span class="block text-xs text-faint-fg truncate">
                      {d.path}{d.fs_type ? ` · ${d.fs_type}` : ''}
                    </span>
                  </td>
                  <td class="py-2 text-right whitespace-nowrap text-muted-fg">
                    {fmtBytes(d.used)} / {fmtBytes(d.total)}
                  </td>
                  <td class="py-2 pl-4 text-right font-medium text-fg">
                    {d.usage_percent.toFixed(1)}%
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
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
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <tbody class="divide-y divide-line">
              {#each m.ifaces as iface (iface.name)}
                <tr>
                  <td class="py-2 pr-4 text-fg truncate">{iface.name}</td>
                  <td class="py-2 text-right whitespace-nowrap text-muted-fg">
                    RX {fmtBytes(iface.rx_bytes)}
                  </td>
                  <td class="py-2 pl-4 text-right whitespace-nowrap text-muted-fg">
                    TX {fmtBytes(iface.tx_bytes)}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </Card>
    {/if}
  {:else if kind === 'gpu'}
    {#each m?.gpus ?? [] as gpu (gpu.name)}
      <Card>
        <h3 class="text-sm font-semibold text-fg-strong mb-3 truncate">{gpu.name}</h3>
        <div class="space-y-3">
          {@render row($LL.usage(), `${gpu.usage_percent.toFixed(0)}%`)}
          {@render row($LL.memory(), `${gpu.memory_used} / ${gpu.memory_total} ${gpu.memory_unit}`)}
          {@render row($LL.temperature(), `${gpu.temperature} °C`)}
          {@render row($LL.power(), gpu.power)}
        </div>
      </Card>
    {/each}
  {/if}
</div>
