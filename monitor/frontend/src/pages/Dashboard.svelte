<script lang="ts">
  import {
    Cpu,
    Gpu,
    HardDrive,
    Menu,
    MemoryStick,
    Thermometer,
    Network,
    CircleAlert,
    RefreshCw,
  } from '@lucide/svelte'
  import { Badge, Card, IconButton, Spinner } from '@serverbox/webui'
  import DetailPanel, { type DetailKind } from '../components/DetailPanel.svelte'
  import LineChart from '../components/LineChart.svelte'
  import LoginForm from '../components/LoginForm.svelte'
  import StatCard from '../components/StatCard.svelte'
  import { api } from '../lib/api'
  import { displayName, servers } from '../lib/servers.svelte'
  import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'
  import { layout } from '../lib/layout.svelte'
  import { Poller } from '../lib/poller.svelte'
  import type { HistoryPoint } from '../types'

  const status = new Poller(api.getStatus, 5000)
  const metrics = new Poller(api.getMetrics, 5000)

  const RANGES = [
    { label: '1h', minutes: 60 },
    { label: '24h', minutes: 1440 },
    { label: '7d', minutes: 7 * 24 * 60 },
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

  // Refetches on range change (and once authenticated)
  $effect(() => {
    if (servers.authenticated) void loadHistory(rangeMinutes)
  })

  let historyTimer: ReturnType<typeof setInterval> | undefined

  // Polling (and the 401 it'd draw) only makes sense once this server has a
  // session; toggling auth state starts/stops it instead of an unconditional
  // onMount, so a freshly-added, not-yet-logged-in server stays quiet
  $effect(() => {
    if (servers.authenticated) {
      status.start()
      metrics.start()
      historyTimer = setInterval(() => void loadHistory(rangeMinutes), 60_000)
    }
    return () => {
      status.stop()
      metrics.stop()
      clearInterval(historyTimer)
    }
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

  const error = $derived(status.error ?? metrics.error)
  const connected = $derived(error === null && (status.data !== null || metrics.data !== null))

  let detail = $state<DetailKind | null>(null)

  // Cards derive from numeric metrics (uniform layout: one big figure plus a
  // detail line) instead of parsing the preformatted /status strings
  const m = $derived(metrics.data)
  const latest = $derived(history.at(-1))

  // Backfills a blank entry name (server added without one) from the data the
  // server itself reports; applyReportedName() no-ops once a name is set
  $effect(() => {
    const reported = m?.server_name || status.data?.name
    if (reported) servers.applyReportedName(servers.currentId, reported)
  })
</script>

{#if servers.authenticated && status.loading && metrics.loading}
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
            {servers.current?.id === 'local' ? $LL.thisServer() : displayName(servers.current)}
          </h1>
          <p class="text-xs leading-tight text-muted-fg truncate">
            {status.data?.name || $LL.unknownServer()}
          </p>
        </div>
        <span class="flex-1"></span>
        <Badge tone={connected ? 'success' : 'danger'}>
          <span
            class="w-1.5 h-1.5 rounded-full mr-1.5 {connected ? 'bg-success' : 'bg-danger'}"
          ></span>
          {connected ? $LL.connected() : $LL.disconnected()}
        </Badge>
        <IconButton label={$LL.refresh()} onclick={() => window.location.reload()}>
          <RefreshCw class="w-4 h-4" />
        </IconButton>
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    {#if !servers.authenticated}
      <div class="py-12">
        <p class="mb-6 text-center text-sm text-muted-fg">{$LL.signInSubtitle()}</p>
        <LoginForm />
      </div>
    {:else}
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

    {#if detail}
      <DetailPanel kind={detail} metrics={m} {history} onback={() => (detail = null)} />
    {:else}
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-6 mb-8">
      <StatCard
        class="p-4 sm:p-6"
        icon={Cpu}
        iconClass="text-blue-500"
        label={$LL.cpuUsage()}
        value={m ? `${m.cpu_usage.toFixed(1)}%` : '--'}
        detail={m
          ? [
              // cpu_brand already reads e.g. "Apple M5 Pro (x18)"; older
              // agents without it fall back to a bare core count
              m.cpu_brand || (m.cpu_cores?.length ? `${m.cpu_cores.length} ${$LL.cores()}` : ''),
              m.temperature != null ? `${m.temperature.toFixed(1)} \u00B0C` : '',
            ]
              .filter(Boolean)
              .join(' \u00B7 ')
          : ''}
        onclick={() => (detail = 'cpu')}
      />
      <StatCard
        class="p-4 sm:p-6"
        icon={MemoryStick}
        iconClass="text-green-500"
        label={$LL.memory()}
        value={m ? `${m.memory.usage_percent.toFixed(1)}%` : '--'}
        detail={m ? `${fmtBytes(m.memory.used)} / ${fmtBytes(m.memory.total)}` : ''}
        onclick={() => (detail = 'memory')}
      />
      <StatCard
        class="p-4 sm:p-6"
        icon={HardDrive}
        iconClass="text-yellow-500"
        label={$LL.diskUsage()}
        value={m ? `${m.disk.usage_percent.toFixed(1)}%` : '--'}
        detail={m ? `${fmtBytes(m.disk.used)} / ${fmtBytes(m.disk.total)}` : ''}
        onclick={() => (detail = 'disk')}
      />
      <StatCard
        class="p-4 sm:p-6 {m?.gpus?.length ? '' : 'col-span-2 lg:col-span-1'}"
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
        onclick={() => (detail = 'network')}
      />
      {#if m?.gpus?.length}
        <StatCard
          class="p-4 sm:p-6"
          icon={Gpu}
          iconClass="text-rose-500"
          label={$LL.gpu()}
          value={`${m.gpus[0].usage_percent.toFixed(0)}%`}
          detail={m.gpus[0].name}
          onclick={() => (detail = 'gpu')}
        />
      {/if}
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
      <Card>
        <h3 class="text-lg font-semibold font-display text-fg-strong mb-4">{$LL.systemInformation()}</h3>
        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-sm text-muted-fg">{$LL.serverNameLabel()}</span>
            <span class="text-sm font-medium">{m.server_name}</span>
          </div>
          {#if m.sys}
            <div class="flex justify-between gap-4">
              <span class="text-sm text-muted-fg">{$LL.osHost()}</span>
              <span class="text-sm font-medium text-right truncate">{m.sys}</span>
            </div>
          {/if}
          <div class="flex justify-between">
            <span class="text-sm text-muted-fg">{$LL.lastUpdated()}</span>
            <span class="text-sm font-medium">
              {new Date(m.timestamp).toLocaleString()}
            </span>
          </div>
          {#if m.swap.total > 0}
            <div class="flex justify-between">
              <span class="text-sm text-muted-fg">{$LL.swap()}</span>
              <span class="text-sm font-medium">
                {fmtBytes(m.swap.used)} / {fmtBytes(m.swap.total)}
              </span>
            </div>
          {/if}
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
    {/if}
    {/if}
    {/if}
  </main>
{/if}
