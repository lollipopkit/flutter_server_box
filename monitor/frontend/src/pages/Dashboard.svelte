<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import {
    Monitor,
    LogOut,
    Cpu,
    HardDrive,
    MemoryStick,
    Thermometer,
    Network,
    CircleAlert,
    RefreshCw,
  } from '@lucide/svelte'
  import LineChart from '../components/LineChart.svelte'
  import LocaleToggle from '../components/LocaleToggle.svelte'
  import ServerPicker from '../components/ServerPicker.svelte'
  import Spinner from '../components/Spinner.svelte'
  import StatCard from '../components/StatCard.svelte'
  import ThemeToggle from '../components/ThemeToggle.svelte'
  import { api } from '../lib/api'
  import { servers } from '../lib/servers.svelte'
  import { fmtBytesPerSec, fmtPercent } from '../lib/format'
  import { i18n } from '../lib/i18n.svelte'
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
    { label: i18n.t('memory'), color: '#22c55e', values: history.map((p) => p.memory) },
    { label: i18n.t('diskUsage'), color: '#f59e0b', values: history.map((p) => p.disk) },
  ])
  const networkSeries = $derived([
    { label: i18n.t('down'), color: '#8b5cf6', values: history.map((p) => p.net_rx_speed) },
    { label: i18n.t('up'), color: '#ec4899', values: history.map((p) => p.net_tx_speed) },
  ])

  const thresholds = {
    cpu: { warning: 70, danger: 85 },
    memory: { warning: 80, danger: 90 },
    disk: { warning: 85, danger: 95 },
  }

  function statusBadge(value: string | undefined, type: keyof typeof thresholds): string {
    const percentage = parseFloat(value ?? '0')
    if (isNaN(percentage)) return 'status-success'
    const t = thresholds[type]
    if (percentage >= t.danger) return 'status-danger'
    if (percentage >= t.warning) return 'status-warning'
    return 'status-success'
  }

  const error = $derived(status.error ?? metrics.error)
</script>

{#if status.loading && metrics.loading}
  <div class="min-h-screen flex items-center justify-center">
    <Spinner size="lg" />
  </div>
{:else}
  <header class="bg-white shadow-sm border-b border-gray-200 dark:bg-gray-900 dark:border-gray-800">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center py-4">
        <div class="flex items-center">
          <Monitor class="w-8 h-8 text-primary-600 mr-3" />
          <div>
            <h1 class="text-xl font-semibold text-strong">ServerBox Monitor</h1>
            <p class="text-sm text-gray-500 dark:text-gray-400">
              {status.data?.name || i18n.t('unknownServer')}
            </p>
          </div>
        </div>

        <div class="flex items-center space-x-4">
          <ServerPicker />
          <div class="text-sm text-muted">
            {i18n.t('welcome')} <span class="font-medium">{servers.current?.username}</span>
          </div>
          <LocaleToggle />
          <ThemeToggle />
          <button onclick={() => servers.logout()} class="btn btn-secondary flex items-center">
            <LogOut class="w-4 h-4 mr-2" />
            {i18n.t('logout')}
          </button>
        </div>
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    {#if error}
      <div
        class="mb-6 bg-danger-50 border border-danger-200 rounded-md p-4 dark:bg-danger-600/10 dark:border-danger-600/30"
      >
        <div class="flex">
          <CircleAlert class="w-5 h-5 text-danger-400" />
          <div class="ml-3">
            <p class="text-sm text-danger-700 dark:text-danger-400">{error}</p>
          </div>
        </div>
      </div>
    {/if}

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      <StatCard
        icon={Cpu}
        iconClass="text-blue-500"
        label={i18n.t('cpuUsage')}
        value={status.data?.cpu || '--'}
        badge={status.data?.cpu ? i18n.t('active') : i18n.t('na')}
        badgeClass={statusBadge(status.data?.cpu, 'cpu')}
      />
      <StatCard
        icon={MemoryStick}
        iconClass="text-green-500"
        label={i18n.t('memory')}
        value={status.data?.memory || '--'}
        valueClass="text-lg"
        badge={status.data?.memory ? i18n.t('active') : i18n.t('na')}
        badgeClass={statusBadge(status.data?.memory, 'memory')}
      />
      <StatCard
        icon={HardDrive}
        iconClass="text-yellow-500"
        label={i18n.t('diskUsage')}
        value={status.data?.disk || '--'}
        valueClass="text-lg"
        badge={status.data?.disk ? i18n.t('active') : i18n.t('na')}
        badgeClass={statusBadge(status.data?.disk, 'disk')}
      />
      <StatCard
        icon={Network}
        iconClass="text-purple-500"
        label={i18n.t('network')}
        value={status.data?.network?.replace(' / ', '\n') || '--'}
        valueClass="text-sm"
        badge={i18n.t('active')}
        badgeClass="status-success"
      />
    </div>

    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold text-strong">{i18n.t('history')}</h2>
      <div class="flex rounded-md border border-gray-200 dark:border-gray-800 overflow-hidden">
        {#each RANGES as r (r.minutes)}
          <button
            class="px-3 py-1 text-sm transition-colors {rangeMinutes === r.minutes
              ? 'bg-primary-600 text-white'
              : 'bg-white text-gray-600 hover:bg-gray-100 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-gray-800'}"
            onclick={() => (rangeMinutes = r.minutes)}
          >
            {r.label}
          </button>
        {/each}
      </div>
    </div>

    {#if historyError}
      <p class="mb-4 text-sm text-danger-600 dark:text-danger-400">{historyError}</p>
    {/if}

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
      <LineChart
        title={i18n.t('usage')}
        labels={historyLabels}
        series={usageSeries}
        yMax={100}
        format={fmtPercent}
      />
      <LineChart
        title={i18n.t('network')}
        labels={historyLabels}
        series={networkSeries}
        format={fmtBytesPerSec}
      />
    </div>

    {#if metrics.data}
      {@const m = metrics.data}
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="card">
          <h3 class="text-lg font-semibold text-strong mb-4">{i18n.t('systemInformation')}</h3>
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="text-sm text-muted">{i18n.t('serverNameLabel')}</span>
              <span class="text-sm font-medium">{m.server_name}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted">{i18n.t('lastUpdated')}</span>
              <span class="text-sm font-medium">
                {new Date(m.timestamp).toLocaleString()}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted">{i18n.t('cpuUsageLabel')}</span>
              <span class="text-sm font-medium">{m.cpu_usage.toFixed(1)}%</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted">{i18n.t('memoryUsageLabel')}</span>
              <span class="text-sm font-medium">{m.memory.usage_percent.toFixed(1)}%</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted">{i18n.t('diskUsageLabel')}</span>
              <span class="text-sm font-medium">{m.disk.usage_percent.toFixed(1)}%</span>
            </div>
            {#if m.temperature != null}
              <div class="flex justify-between">
                <span class="text-sm text-muted">{i18n.t('temperature')}</span>
                <span class="text-sm font-medium flex items-center">
                  <Thermometer class="w-4 h-4 mr-1" />
                  {m.temperature.toFixed(1)}°C
                </span>
              </div>
            {/if}
          </div>
        </div>

        <div class="card">
          <h3 class="text-lg font-semibold text-strong mb-4">{i18n.t('quickActions')}</h3>
          <div class="space-y-3">
            <button
              onclick={() => window.location.reload()}
              class="btn-primary w-full flex items-center justify-center"
            >
              <RefreshCw class="w-4 h-4 mr-2" />
              {i18n.t('refreshData')}
            </button>
            <div class="text-xs text-gray-500 dark:text-gray-400 text-center mt-4">
              {i18n.t('autoRefreshNote')}
            </div>
          </div>
        </div>
      </div>
    {/if}
  </main>
{/if}
