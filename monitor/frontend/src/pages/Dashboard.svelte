<script lang="ts">
  import {
    BatteryMedium,
    Cpu,
    Gauge,
    Gpu,
    HardDrive,
    MemoryStick,
    Server,
    Settings as SettingsIcon,
    SquareTerminal,
    ShieldCheck,
    Network,
    CircleAlert,
    RefreshCw,
  } from '@lucide/svelte'
  import { Badge, Button, Card, IconButton, Spinner } from '@serverbox/webui'
  import DetailPanel, { type DetailKind } from '../components/DetailPanel.svelte'
  import LineChart from '../components/LineChart.svelte'
  import LoginForm from '../components/LoginForm.svelte'
  import OsIcon from '../components/OsIcon.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import StatCard from '../components/StatCard.svelte'
  import { api } from '../lib/api'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { health } from '../lib/health.svelte'
  import { layout } from '../lib/layout.svelte'
  import { displayName, servers } from '../lib/servers.svelte'
  import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'
  import { Poller } from '../lib/poller.svelte'
  import { fly } from 'svelte/transition'
  import type { HistoryPoint } from '../types'

  const metrics = new Poller(api.getMetrics, 5000)

  // Platform-only, doesn't change per-sample — fetched once per server
  // (shared with the sidebar's OS icons via capabilitiesStore), not on the
  // metrics poll cadence. Undefined before it loads is treated as "unknown"
  // (permissive) below so cards don't flash hidden-then-shown while in flight.
  $effect(() => {
    if (servers.authenticated) void capabilitiesStore.ensure(servers.currentId)
  })
  const capabilities = $derived(capabilitiesStore.byServer[servers.currentId])

  // Home-grid card order, synced server-side (not localStorage) so every
  // client viewing this agent sees the same arrangement — see card-order.ts
  const ALL_CARD_IDS = ['cpu', 'memory', 'disk', 'network', 'gpu', 'battery', 'sensors', 'smart'] as const
  type CardId = (typeof ALL_CARD_IDS)[number]
  let cardOrder = $state<CardId[]>([...ALL_CARD_IDS])

  async function loadCardOrder() {
    try {
      const { card_order } = await api.getCardOrder()
      const known = card_order.filter((id): id is CardId => (ALL_CARD_IDS as readonly string[]).includes(id))
      // Append any ids missing from the saved order (new card added later,
      // or first-ever save) so nothing silently disappears
      const missing = ALL_CARD_IDS.filter((id) => !known.includes(id))
      cardOrder = known.length ? [...known, ...missing] : [...ALL_CARD_IDS]
    } catch {
      // Keep the default order; a failed fetch shouldn't block the dashboard
    }
  }

  $effect(() => {
    if (servers.authenticated) void loadCardOrder()
  })

  let dragId = $state<CardId | null>(null)

  function onCardDragStart(id: CardId) {
    dragId = id
  }
  function onCardDragOver(e: DragEvent) {
    e.preventDefault()
  }
  function onCardDrop(targetId: CardId) {
    if (!dragId || dragId === targetId) return
    const from = cardOrder.indexOf(dragId)
    const to = cardOrder.indexOf(targetId)
    if (from === -1 || to === -1) return
    const next = [...cardOrder]
    next.splice(from, 1)
    next.splice(to, 0, dragId)
    cardOrder = next
    dragId = null
    void api.updateCardOrder(cardOrder).catch(() => {})
  }

  const RANGES = [
    { label: '1h', minutes: 60 },
    { label: '24h', minutes: 1440 },
    { label: '7d', minutes: 7 * 24 * 60 },
  ]
  let rangeMinutes = $state(60)
  let requestedHistoryMinutes = 60
  const historyPoller = new Poller(
    (signal) => api.getHistory(requestedHistoryMinutes, signal),
    60_000,
  )
  const history = $derived(historyPoller.data ?? ([] as HistoryPoint[]))
  const historyError = $derived(historyPoller.error)

  // Polling (and the 401 it'd draw) only makes sense once this server has a
  // session; toggling auth state starts/stops it instead of an unconditional
  // onMount, so a freshly-added, not-yet-logged-in server stays quiet
  $effect(() => {
    const serverId = servers.currentId
    if (serverId && servers.authenticated) {
      metrics.reset()
      metrics.start()
    }
    return () => {
      metrics.stop()
    }
  })

  // History additionally depends on the selected range. Restarting aborts
  // the old request so a slow 7d response cannot overwrite a newer 1h view.
  $effect(() => {
    const serverId = servers.currentId
    const minutes = rangeMinutes
    requestedHistoryMinutes = minutes
    if (serverId && servers.authenticated) {
      historyPoller.reset()
      historyPoller.start()
    }
    return () => {
      historyPoller.stop()
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

  const error = $derived(metrics.error)
  // Agent reachability (unauthenticated /health ping, always running via
  // Sidebar) — independent of whether this browser is logged in yet, so an
  // address-only entry with no credentials doesn't read as "disconnected"
  const connected = $derived(health.status[servers.currentId] ?? false)

  let detail = $state<DetailKind | null>(null)

  // Cards derive from numeric metrics (uniform layout: one big figure plus a
  // detail line) instead of parsing the preformatted /status strings
  const m = $derived(metrics.data)
  const latest = $derived(history.at(-1))

  // A card only shows once there's data AND the platform isn't documented as
  // never collecting the field — avoids the old "empty array = hidden" logic
  // treating "not supported here" and "no hardware detected" the same way
  const showGpu = $derived(
    (capabilities?.nvidia !== 'not_implemented' || capabilities?.amd !== 'not_implemented') &&
      !!m?.gpus?.length,
  )
  const showBattery = $derived(capabilities?.batteries !== 'not_implemented' && !!m?.batteries?.length)
  const showSensors = $derived(capabilities?.sensors !== 'not_implemented' && !!m?.sensors?.length)
  const showSmart = $derived(capabilities?.disk_smart !== 'not_implemented' && !!m?.disk_smart?.length)

  // Always the server's own live-reported name (config.toml's `name`, or its
  // hostname fallback) — never a locally cached/editable one. Before the
  // first successful poll: "This server" for the built-in same-origin entry,
  // otherwise the address/id.
  const headerName = $derived(
    m?.server_name ??
      (servers.current?.id === 'local'
        ? $LL.thisServer()
        : servers.current
          ? displayName(servers.current)
          : ''),
  )

  function isCardVisible(id: CardId): boolean {
    switch (id) {
      case 'cpu':
      case 'memory':
      case 'disk':
      case 'network':
        return true
      case 'gpu':
        return showGpu && !!m?.gpus?.length
      case 'battery':
        return showBattery && !!m?.batteries?.length
      case 'sensors':
        return showSensors && !!m?.sensors?.length
      case 'smart':
        return showSmart && !!m?.disk_smart?.length
    }
  }
  const visibleCardOrder = $derived(cardOrder.filter(isCardVisible))

  // Detail drill-down reuses this same header (back button + section title)
  // instead of stacking a second header bar under it — see DetailPanel
  const detailTitles = $derived({
    cpu: $LL.cpuUsage(),
    memory: $LL.memory(),
    disk: $LL.diskUsage(),
    network: $LL.network(),
    gpu: $LL.gpu(),
    battery: $LL.battery(),
    sensors: $LL.sensors(),
    smart: $LL.smart(),
  })
</script>

{#if servers.authenticated && metrics.loading}
  <div class="min-h-screen flex items-center justify-center">
    <Spinner size="lg" />
  </div>
{:else}
  {#if detail}
    <PageHeader title={detailTitles[detail]} onback={() => (detail = null)} />
  {:else}
    <PageHeader title={headerName}>
      {#snippet titleIcon()}
        {@const statusCls = connected ? 'text-green-500' : 'text-red-500'}
        {@const statusTitle = connected ? $LL.connected() : $LL.disconnected()}
        {#if capabilities?.platform}
          <OsIcon platform={capabilities.platform} class="w-5 h-5 shrink-0 {statusCls}" title={statusTitle} />
        {:else}
          <Server class="w-5 h-5 shrink-0 {statusCls}" title={statusTitle} />
        {/if}
      {/snippet}
      {#snippet actions()}
        <Badge tone={connected ? 'success' : 'danger'}>
          {connected ? $LL.connected() : $LL.disconnected()}
        </Badge>
        {#if capabilities?.remote_access?.terminal}
          <IconButton label={$LL.terminal()} onclick={() => layout.navigate('terminal')}>
            <SquareTerminal class="w-4 h-4" />
          </IconButton>
        {/if}
        <IconButton label={$LL.serverSettings()} onclick={() => layout.navigate('server-settings')}>
          <SettingsIcon class="w-4 h-4" />
        </IconButton>
        <IconButton label={$LL.refresh()} onclick={() => window.location.reload()}>
          <RefreshCw class="w-4 h-4" />
        </IconButton>
      {/snippet}
    </PageHeader>
  {/if}

  <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    {#if servers.empty}
      <!-- Nothing to sign in to. Reached when the panel is hosted apart from
           any agent — the origin it came from is a static host, so the entry
           assumed at startup has been dropped. -->
      <div class="py-12 flex flex-col items-center gap-4 text-center">
        <Server class="w-10 h-10 text-faint-fg" />
        <p class="text-sm text-muted-fg">{$LL.noServersTip()}</p>
        <Button onclick={() => (layout.addServerOpen = true)}>{$LL.addServer()}</Button>
      </div>
    {:else if !servers.authenticated}
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

    {#key detail}
      <div in:fly={{ x: detail ? 16 : -16, duration: 200, delay: 150 }} out:fly={{ x: detail ? -16 : 16, duration: 150 }}>
    {#if detail}
      <DetailPanel kind={detail} metrics={m} {history} />
    {:else}
    {#snippet card(id: CardId)}
      {#if id === 'cpu'}
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
      {:else if id === 'memory'}
        <StatCard
          class="p-4 sm:p-6"
          icon={MemoryStick}
          iconClass="text-green-500"
          label={$LL.memory()}
          value={m ? `${m.memory.usage_percent.toFixed(1)}%` : '--'}
          detail={m ? `${fmtBytes(m.memory.used)} / ${fmtBytes(m.memory.total)}` : ''}
          onclick={() => (detail = 'memory')}
        />
      {:else if id === 'disk'}
        <StatCard
          class="p-4 sm:p-6"
          icon={HardDrive}
          iconClass="text-yellow-500"
          label={$LL.diskUsage()}
          value={m ? `${m.disk.usage_percent.toFixed(1)}%` : '--'}
          detail={m ? `${fmtBytes(m.disk.used)} / ${fmtBytes(m.disk.total)}` : ''}
          onclick={() => (detail = 'disk')}
        />
      {:else if id === 'network'}
        <StatCard
          class="p-4 sm:p-6"
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
      {:else if id === 'gpu' && m?.gpus?.length}
        <StatCard
          class="p-4 sm:p-6"
          icon={Gpu}
          iconClass="text-rose-500"
          label={$LL.gpu()}
          value={`${m.gpus[0].usage_percent.toFixed(0)}%`}
          detail={m.gpus[0].name}
          onclick={() => (detail = 'gpu')}
        />
      {:else if id === 'battery' && m?.batteries?.length}
        <StatCard
          class="p-4 sm:p-6"
          icon={BatteryMedium}
          iconClass="text-lime-500"
          label={$LL.battery()}
          value={m.batteries[0].percent != null ? `${m.batteries[0].percent}%` : '--'}
          detail={m.batteries[0].name ?? ''}
          onclick={() => (detail = 'battery')}
        />
      {:else if id === 'sensors' && m?.sensors?.length}
        <StatCard
          class="p-4 sm:p-6"
          icon={Gauge}
          iconClass="text-orange-500"
          label={$LL.sensors()}
          value={String(m.sensors.length)}
          detail={m.sensors[0].device}
          onclick={() => (detail = 'sensors')}
        />
      {:else if id === 'smart' && m?.disk_smart?.length}
        <StatCard
          class="p-4 sm:p-6"
          icon={ShieldCheck}
          iconClass={m.disk_smart.every((d) => d.healthy !== false) ? 'text-success' : 'text-danger'}
          label={$LL.smart()}
          value={`${m.disk_smart.filter((d) => d.healthy !== false).length} / ${m.disk_smart.length}`}
          detail={$LL.healthy()}
          onclick={() => (detail = 'smart')}
        />
      {/if}
    {/snippet}

    <!-- Up to 8 cards now that battery/sensors/smart are gated on real
         capabilities (see showBattery et al.) rather than always reserved
         slots — a 2-col jump straight to 4-col leaves tablet-width viewports
         (~640-1023px) as cramped as phones; md:grid-cols-3 smooths the ramp.
         Order is drag-to-reorder (desktop pointer only — HTML5 DnD has no
         built-in touch support) and synced server-side via cardOrder. -->
    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3 sm:gap-6 mb-8">
      {#each visibleCardOrder as id (id)}
        <div
          role="listitem"
          draggable="true"
          ondragstart={() => onCardDragStart(id)}
          ondragover={onCardDragOver}
          ondrop={() => onCardDrop(id)}
          class="cursor-grab active:cursor-grabbing"
        >
          {@render card(id)}
        </div>
      {/each}
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
          {#if m.uptime}
            <div class="flex justify-between">
              <span class="text-sm text-muted-fg">{$LL.uptime()}</span>
              <span class="text-sm font-medium">{m.uptime}</span>
            </div>
          {/if}
          {#if m.conn}
            <div class="flex justify-between">
              <span class="text-sm text-muted-fg">{$LL.connections()}</span>
              <!-- Linux's /proc/net/snmp reports the SNMP MIB-II tcpMaxConn
                   counter, which is -1 by convention when the kernel has no
                   static connection cap (i.e. always, on Linux) — not an
                   error, so show it as "unlimited" rather than a raw -1 -->
              <span class="text-sm font-medium">
                {m.conn.max_conn === -1 ? $LL.unlimited() : m.conn.max_conn}
              </span>
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
        </div>
      </Card>
    {/if}
    {/if}
      </div>
    {/key}
    {/if}
  </main>
{/if}
