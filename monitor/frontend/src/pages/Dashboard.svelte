<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import {
    Cpu,
    HardDrive,
    Menu,
    MemoryStick,
    Thermometer,
    Network,
    CircleAlert,
    RefreshCw,
  } from '@lucide/svelte'
  import { Button, Card, IconButton, Spinner } from '@serverbox/webui'
  import LineChart from '../components/LineChart.svelte'
  import StatCard from '../components/StatCard.svelte'
  import { api } from '../lib/api'
  import { servers } from '../lib/servers.svelte'
  import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'
  import { layout } from '../lib/layout.svelte'
  import { Poller } from '../lib/poller.svelte'
  import type { HistoryPoint } from '../types'

  const status = new Poller(api.getStatus, 5000)
  const metrics = new Poller(api.getMetrics, 5000)

  const RANGES = [
    { label: '1h', minutes: 60 },
    { label: '6h', minutes: 360 },
    { label: '24h', minutes: 1440 },
  ]
  let rangeMinutes = $state(60)
  let history = $state<HistoryPoint[]>([])
  let historyError = $state<string | null>(null)

  async function loadHistory(minutes: number) {
    try {
      history = await api.getHistory(minutes)
      historyError = null
    } catch (e) {
      historyError = e instanceof Error ? e.message : String(e)
    }
  }

  // Refetches on range change (and on mount)
  $effect(() => {
    void loadHistory(rangeMinutes)
  })

  let historyTimer: ReturnType<typeof setInterval> | undefined

  onMount(() => {
    status.start()
    metrics.start()
    historyTimer = setInterval(() => void loadHistory(rangeMinutes), 60_000)
  })
  onDestroy(() => {
    status.stop()
    metrics.stop()
    clearInterval(historyTimer)
  })

  const historyLabels = $derived(history.map((p) => p.timestamp))
  const usageSeries = $derived([
    { label: 'CPU', color: '#3b82f6', values: history.map((p) => p.cpu) },
    { label: $LL.memory(), color: '#22c55e', values: history.map((p) => p.memory) },
    { label: $LL.diskUsage(), color: '#f59e0b', values: history.map((p) => p.disk) },
  ])
  const networkSeries = $derived([
    { label: $LL.down(), color: '#8b5cf6', values: history.map((p) => p.net_rx_speed) },
    { label: $LL.up(), color: '#ec4899', values: history.map((p) => p.net_tx_speed) },
  ])

  const thresholds = {
    cpu: { warning: 70, danger: 85 },
    memory: { warning: 80, danger: 90 },
    disk: { warning: 85, danger: 95 },
  }

  function statusTone(
    pct: number | undefined,
    type: keyof typeof thresholds,
  ): 'success' | 'warning' | 'danger' {
    if (pct === undefined || isNaN(pct)) return 'success'
    const t = thresholds[type]
    if (pct >= t.danger) return 'danger'
    if (pct >= t.warning) return 'warning'
    return 'success'
  }

  const error = $derived(status.error ?? metrics.error)

  // Cards derive from numeric metrics (uniform layout: one big figure plus a
  // detail line) instead of parsing the preformatted /status strings
  const m = $derived(metrics.data)
  const latest = $derived(history.at(-1))
</script>

{#if status.loading && metrics.loading}
  <div class="min-h-screen flex items-center justify-center">
    <Spinner size="lg" />
  </div>
{:else}
  <!-- h-16 with the border inside (border-box), matching the sidebar header
       exactly so the two dividers sit on the same line -->
  <header class="bg-surface shadow-xs border-b border-line h-16 flex items-center">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
      <div class="flex items-center gap-2">
        <IconButton
          class="lg:hidden -ml-2"
          label={$LL.menu()}
          onclick={() => (layout.mobileOpen = true)}
        >
          <Menu class="w-5 h-5" />
        </IconButton>
        <div class="min-w-0">
          <h1 class="text-lg leading-tight font-semibold font-display text-fg-strong truncate">
            {servers.current?.id === 'local' ? $LL.thisServer() : servers.current?.name}
          </h1>
          <p class="text-xs leading-tight text-muted-fg truncate">
            {status.data?.name || $LL.unknownServer()}
          </p>
        </div>
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    {#if error}
      <div class="mb-6 bg-danger/10 border border-danger/30 rounded-(--radius-container) p-4">
        <div class="flex">
          <CircleAlert class="w-5 h-5 text-danger" />
          <div class="ml-3">
            <p class="text-sm text-danger">{error}</p>
          </div>
        </div>
      </div>
    {/if}

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-6 mb-8">
      <StatCard
        class="p-4 sm:p-6"
        icon={Cpu}
        iconClass="text-blue-500"
        label={$LL.cpuUsage()}
        value={m ? `${m.cpu_usage.toFixed(1)}%` : '--'}
        detail={m?.temperature != null ? `${m.temperature.toFixed(1)} \u00B0C` : ''}
        badge={m ? $LL.active() : $LL.na()}
        tone={statusTone(m?.cpu_usage, 'cpu')}
      />
      <StatCard
        class="p-4 sm:p-6"
        icon={MemoryStick}
        iconClass="text-green-500"
        label={$LL.memory()}
        value={m ? `${m.memory.usage_percent.toFixed(1)}%` : '--'}
        detail={m ? `${fmtBytes(m.memory.used)} / ${fmtBytes(m.memory.total)}` : ''}
        badge={m ? $LL.active() : $LL.na()}
        tone={statusTone(m?.memory.usage_percent, 'memory')}
      />
      <StatCard
        class="p-4 sm:p-6"
        icon={HardDrive}
        iconClass="text-yellow-500"
        label={$LL.diskUsage()}
        value={m ? `${m.disk.usage_percent.toFixed(1)}%` : '--'}
        detail={m ? `${fmtBytes(m.disk.used)} / ${fmtBytes(m.disk.total)}` : ''}
        badge={m ? $LL.active() : $LL.na()}
        tone={statusTone(m?.disk.usage_percent, 'disk')}
      />
      <StatCard
        class="p-4 sm:p-6 col-span-2 lg:col-span-1"
        icon={Network}
        iconClass="text-purple-500"
        label={$LL.network()}
        value={latest
          ? `\u2193 ${fmtBytesPerSec(latest.net_rx_speed)}  \u2191 ${fmtBytesPerSec(latest.net_tx_speed)}`
          : '--'}
        valueClass="text-lg"
        detail={m
          ? `RX ${fmtBytes(m.network.rx_bytes)} \u00B7 TX ${fmtBytes(m.network.tx_bytes)}`
          : ''}
        badge={$LL.active()}
        tone="success"
      />
    </div>

    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold font-display text-fg-strong">{$LL.history()}</h2>
      <div class="flex rounded-full border border-line overflow-hidden">
        {#each RANGES as r (r.minutes)}
          <button
            class="px-3 py-1 text-sm cursor-pointer transition-colors {rangeMinutes === r.minutes
              ? 'bg-fg-strong text-surface'
              : 'bg-surface text-muted-fg hover:bg-soft'}"
            onclick={() => (rangeMinutes = r.minutes)}
          >
            {r.label}
          </button>
        {/each}
      </div>
    </div>

    {#if historyError}
      <p class="mb-4 text-sm text-danger">{historyError}</p>
    {/if}

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 sm:gap-6 mb-8">
      <LineChart
        title={$LL.usage()}
        labels={historyLabels}
        series={usageSeries}
        yMax={100}
        format={fmtPercent}
      />
      <LineChart
        title={$LL.network()}
        labels={historyLabels}
        series={networkSeries}
        format={fmtBytesPerSec}
      />
    </div>

    {#if metrics.data}
      {@const m = metrics.data}
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 sm:gap-6">
        <Card>
          <h3 class="text-lg font-semibold font-display text-fg-strong mb-4">{$LL.systemInformation()}</h3>
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="text-sm text-muted-fg">{$LL.serverNameLabel()}</span>
              <span class="text-sm font-medium">{m.server_name}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted-fg">{$LL.lastUpdated()}</span>
              <span class="text-sm font-medium">
                {new Date(m.timestamp).toLocaleString()}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted-fg">{$LL.cpuUsageLabel()}</span>
              <span class="text-sm font-medium">{m.cpu_usage.toFixed(1)}%</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted-fg">{$LL.memoryUsageLabel()}</span>
              <span class="text-sm font-medium">{m.memory.usage_percent.toFixed(1)}%</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted-fg">{$LL.diskUsageLabel()}</span>
              <span class="text-sm font-medium">{m.disk.usage_percent.toFixed(1)}%</span>
            </div>
            {#if m.temperature != null}
              <div class="flex justify-between">
                <span class="text-sm text-muted-fg">{$LL.temperature()}</span>
                <span class="text-sm font-medium flex items-center">
                  <Thermometer class="w-4 h-4 mr-1" />
                  {m.temperature.toFixed(1)}°C
                </span>
              </div>
            {/if}
          </div>
        </Card>

        <Card>
          <h3 class="text-lg font-semibold font-display text-fg-strong mb-4">{$LL.quickActions()}</h3>
          <div class="space-y-3">
            <Button block onclick={() => window.location.reload()}>
              <RefreshCw class="w-4 h-4 mr-2" />
              {$LL.refreshData()}
            </Button>
            <div class="text-xs text-muted-fg text-center mt-4">
              {$LL.autoRefreshNote()}
            </div>
          </div>
        </Card>
      </div>
    {/if}
  </main>
{/if}
