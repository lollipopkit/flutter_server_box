<script lang="ts">
  import { Badge, Button, Card, Dialog, Icon, IconButton, LegendChip, SegmentedControl, Spinner, StatTile, ToolbarGroup } from '../../lk'
  import { AppToolbar, PageStack, systemPrefs, useLifecycle, useMenus, useWindow, type MenuEntry } from '../../sys'
  import DetailPanel, { type DetailKind } from './DetailPanel.svelte'
  import IperfModal from './IperfModal.svelte'
  import PowerModal from '../../../components/PowerModal.svelte'
  import UsageChart from './UsageChart.svelte'
  import { enabledFeatures } from '../../../lib/features'
  import { dashboardAccess, isAdmin, machineAccess } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { health } from '../../../lib/health.svelte'
  import { displayName, servers } from '../../../lib/servers.svelte'
  import { DATE_TIME, fmtBytes, fmtBytesPerSec, fmtDate, fmtPercent } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { Poller } from '../../../lib/poller.svelte'
  import type { CustomCmdOutput, HistoryPoint, ProcessView } from '../../../types'

  const metrics = new Poller(api.getMetrics, systemPrefs.refreshMs)
  const win = useWindow()
  const life = useLifecycle()
  /// Paused by the user (or by the system setting): the figures stay as they
  /// were.
  let paused = $state(!systemPrefs.value.autoRefresh)
  $effect(() => {
    metrics.interval = systemPrefs.refreshMs
    topPoller.interval = Math.max(5000, systemPrefs.refreshMs * 2)
  })
  /// Read while drawn and not paused; hidden (minimised), nothing is drawn.
  const shown = $derived(life.state !== 'background' && !paused)

  // Capabilities are platform-specific and do not change per sample. Fetch
  // once per server (shared with the lock screen's icons), rather than on the
  // metrics poll cadence. Undefined before it loads is treated as "unknown"
  // below so cards do not flash from hidden to visible while loading.
  $effect(() => {
    if (servers.authenticated) void capabilitiesStore.ensure(servers.currentId)
  })
  const capabilities = $derived(capabilitiesStore.byServer[servers.currentId])

  /// Which entries the header offers, and whether this account can only
  /// watch — see `dashboardAccess`, which answers for an agent with roles and
  /// for one from before them.
  const access = $derived(dashboardAccess(capabilities))
  const canPower = $derived(machineAccess(capabilities, 'power'))
  /// An iperf run opens a terminal on the machine, so it needs the agent to
  /// understand the `iperf` target and the account to hold `shell`.
  const canIperf = $derived(machineAccess(capabilities, 'iperf', 'shell'))
  let powerOpen = $state(false)
  let iperfOpen = $state(false)
  /// The custom command whose full output is open in the dialog, if any.
  let cmdDetail = $state<CustomCmdOutput | null>(null)
  /// Whether the cards can be rearranged: the order is the agent's, shared by
  /// everyone who views it, so changing it is an administrator's call.
  /// Unknown is allowed — the agent refuses for itself.
  const canArrange = $derived(isAdmin(capabilities) !== false)

  /// A custom command's output as a card row shows it: one trailing line
  /// ending is dropped.
  ///
  /// The agent serves the output exactly as the command printed it, so an
  /// `echo` normally ends in a newline; counting that as a second line would
  /// make every such row open a dialog holding the line the row already
  /// shows. Leading and inner blank lines stay, and the full output is what
  /// the dialog draws.
  function displayOutput(output: string): string {
    return output.replace(/\r?\n$/, '')
  }

  /// The first line of a custom command's output, for a one-line card row.
  function firstLine(output: string): string {
    return displayOutput(output).split('\n')[0]
  }

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
    if (!canArrange) return
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
  // Hidden (minimised), nothing is drawn: polling stops and picks up again
  // when shown, the last figures staying until the new ones arrive.
  $effect(() => {
    void servers.currentId
    metrics.reset()
  })
  $effect(() => {
    const serverId = servers.currentId
    if (serverId && servers.authenticated && shown) metrics.start()
    return () => {
      metrics.stop()
    }
  })

  // History additionally depends on the selected range. Restarting aborts
  // the old request so a slow 7d response cannot overwrite a newer 1h view.
  $effect(() => {
    void servers.currentId
    requestedHistoryMinutes = rangeMinutes
    historyPoller.reset()
  })
  $effect(() => {
    const serverId = servers.currentId
    void rangeMinutes
    if (serverId && servers.authenticated && shown) historyPoller.start()
    return () => {
      historyPoller.stop()
    }
  })

  const historyLabels = $derived(history.map((p) => p.timestamp))
  /// The usage chart's series, each turned on and off by its legend chip.
  let seriesOn = $state({ cpu: true, memory: true, disk: true })
  const USAGE = $derived([
    { id: 'cpu' as const, label: 'CPU', color: 'var(--color-accent)', values: history.map((p) => p.cpu) },
    { id: 'memory' as const, label: $LL.memory(), color: 'var(--hue-blue)', values: history.map((p) => p.memory) },
    { id: 'disk' as const, label: $LL.diskUsage(), color: 'var(--hue-teal)', values: history.map((p) => p.disk) },
  ])
  const usageSeries = $derived(USAGE.filter((s) => seriesOn[s.id]).map((s) => ({ ...s, fill: s.id === 'cpu' })))
  /// A nice top for the percentages on screen: the next step above the
  /// largest, so a quiet machine's 1% is not drawn flat.
  const usageMax = $derived.by(() => {
    const peak = Math.max(1, ...usageSeries.flatMap((s) => s.values)) * 1.2
    return [5, 10, 25, 50, 100].find((v) => v >= peak) ?? 100
  })
  const networkSeries = $derived([
    { label: $LL.down(), color: 'var(--color-accent)', values: history.map((p) => p.net_rx_speed), fill: true },
    { label: $LL.up(), color: 'var(--hue-blue)', values: history.map((p) => p.net_tx_speed) },
  ])
  const xLabels = $derived.by((): [string, string, string] => {
    const fmt = (t: string | undefined) =>
      t ? fmtDate(new Date(t), rangeMinutes > 1440 ? { month: 'short', day: 'numeric' } : { hour: '2-digit', minute: '2-digit' }) : ''
    return [fmt(historyLabels[0]), fmt(historyLabels[Math.floor(historyLabels.length / 2)]), fmt(historyLabels.at(-1))]
  })

  /// The busiest processes, when this account may read them: read along with
  /// the figures, less often.
  const canProcesses = $derived(enabledFeatures(capabilities).some((f) => f.id === 'process'))
  const topPoller = new Poller(() => api.getProcess('cpu'), Math.max(5000, systemPrefs.refreshMs * 2))
  $effect(() => {
    if (canProcesses && servers.authenticated && shown) topPoller.start()
    return () => topPoller.stop()
  })
  const topProcs = $derived(
    ((topPoller.data as ProcessView | null)?.procs ?? []).filter((p) => !p.is_kernel_thread).slice(0, 4),
  )

  const error = $derived(metrics.error)
  // Agent reachability (unauthenticated /health ping, always running via
  // DeskRoot) — independent of the session's own requests, so a slow metrics
  // poll does not read as "disconnected"
  const connected = $derived(health.status[servers.currentId] ?? false)

  let detail = $state<DetailKind | null>(null)
  /// The detail last gone back from: a swipe forward reopens it.
  let leftDetail = $state<DetailKind | null>(null)
  function leaveDetail() {
    leftDetail = detail
    detail = null
  }

  /// Reads everything again now rather than at the next poll, the figures on
  /// screen staying until the new ones arrive; the capabilities too, which a
  /// reload of the old page fetched again.
  function refresh() {
    metrics.start()
    historyPoller.start()
    void capabilitiesStore.refresh(servers.currentId)
  }

  // Cards derive from numeric metrics (uniform layout: one big figure plus a
  // detail line) instead of parsing the preformatted /status strings
  const m = $derived(metrics.data)
  const latest = $derived(history.at(-1))

  // A card only shows once there's data AND the platform isn't documented as
  // never collecting the field — avoids the old "empty array = hidden" logic
  // treating "not supported here" and "no hardware detected" the same way
  const showGpu = $derived(
    (capabilities?.gpu != null
      ? capabilities.gpu !== 'not_implemented'
      : capabilities?.nvidia !== 'not_implemented' || capabilities?.amd !== 'not_implemented') &&
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

  /// The interface that carried the most, loopback aside: the one the
  /// network card is about.
  const iface = $derived(
    (m?.ifaces ?? []).filter((i) => i.name !== 'lo').reduce<{ name: string; rx_bytes: number } | null>((a, b) => (!a || b.rx_bytes > a.rx_bytes ? b : a), null)?.name,
  )

  /// What the machine runs on, in one line under its name.
  const about = $derived(
    [m?.sys, m?.cpu_brand || (m?.cpu_cores?.length ? `${m.cpu_cores.length} ${$LL.cores()}` : ''), m?.temperature != null ? `${m.temperature.toFixed(1)} °C` : '']
      .filter(Boolean)
      .join(' · '),
  )

  /// One reading's tile. CPU and memory lead to the processes in that order;
  /// the rest to their detail.
  function tile(id: CardId) {
    const procs = (sort: 'cpu' | 'mem') => (canProcesses ? () => win.open('process', { appState: { sort } }) : () => (detail = id))
    switch (id) {
      case 'cpu':
        return {
          icon: 'memory',
          color: 'var(--color-accent)',
          label: 'CPU',
          value: m ? fmtPercent(m.cpu_usage) : '--',
          sub: m?.cpu_cores?.length ? $LL.deskCores({ n: m.cpu_cores.length }) : (m?.cpu_brand ?? ''),
          percent: m?.cpu_usage,
          title: canProcesses ? $LL.statusProcessesByCpu() : undefined,
          onclick: procs('cpu'),
        }
      case 'memory':
        return {
          icon: 'memory_alt',
          color: 'var(--hue-blue)',
          label: $LL.memory(),
          value: m ? fmtPercent(m.memory.usage_percent) : '--',
          sub: m ? `${fmtBytes(m.memory.used)} / ${fmtBytes(m.memory.total)}` : '',
          percent: m?.memory.usage_percent,
          title: canProcesses ? $LL.statusProcessesByMemory() : undefined,
          onclick: procs('mem'),
        }
      case 'disk':
        return {
          icon: 'hard_drive',
          color: 'var(--hue-amber)',
          label: $LL.diskUsage(),
          value: m ? fmtPercent(m.disk.usage_percent) : '--',
          sub: m ? `${fmtBytes(m.disk.used)} / ${fmtBytes(m.disk.total)}` : '',
          percent: m?.disk.usage_percent,
          onclick: () => (detail = 'disk'),
        }
      case 'network':
        return {
          icon: 'lan',
          color: 'var(--hue-violet)',
          label: $LL.network(),
          value: latest ? fmtBytesPerSec(latest.net_rx_speed) : '--',
          sub: latest ? `↑ ${fmtBytesPerSec(latest.net_tx_speed)}` : '',
          onclick: () => (detail = 'network'),
        }
      case 'gpu':
        return m?.gpus?.length
          ? {
              icon: 'developer_board',
              color: 'var(--hue-violet)',
              label: $LL.gpu(),
              value: m.gpus[0].usage_percent != null ? fmtPercent(m.gpus[0].usage_percent) : '--',
              sub: m.gpus[0].name,
              percent: m.gpus[0].usage_percent ?? undefined,
              onclick: () => (detail = 'gpu'),
            }
          : null
      case 'battery':
        return m?.batteries?.length
          ? {
              icon: 'battery_5_bar',
              color: 'var(--hue-green)',
              label: $LL.battery(),
              value: m.batteries[0].percent != null ? `${m.batteries[0].percent}%` : '--',
              sub: m.batteries[0].name ?? '',
              percent: m.batteries[0].percent ?? undefined,
              onclick: () => (detail = 'battery'),
            }
          : null
      case 'sensors':
        return m?.sensors?.length
          ? { icon: 'thermostat', color: 'var(--hue-blue)', label: $LL.sensors(), value: String(m.sensors.length), sub: m.sensors[0].device, onclick: () => (detail = 'sensors') }
          : null
      case 'smart':
        return m?.disk_smart?.length
          ? {
              icon: 'shield_lock',
              color: m.disk_smart.every((d) => d.healthy !== false) ? 'var(--color-success)' : 'var(--color-danger)',
              label: $LL.smart(),
              value: `${m.disk_smart.filter((d) => d.healthy !== false).length} / ${m.disk_smart.length}`,
              sub: $LL.healthy(),
              onclick: () => (detail = 'smart'),
            }
          : null
    }
  }

  /// The machine's other doors and every reading's detail, in the menubar.
  useMenus(() => {
    const go: MenuEntry[] = []
    if (access.terminal) go.push({ label: $LL.terminal(), icon: 'terminal', action: () => win.open('terminal') })
    if (access.files) go.push({ label: $LL.files(), icon: 'folder_open', action: () => win.open('files') })
    if (canProcesses) go.push({ label: $LL.processes(), icon: 'list_alt', action: () => win.open('process', { appState: { sort: 'cpu' } }) })
    if (canIperf) go.push({ label: `${$LL.iperf()}…`, icon: 'speed', action: () => (iperfOpen = true) })
    if (canPower) go.push({ label: `${$LL.powerControl()}…`, icon: 'power_settings_new', action: () => (powerOpen = true) })
    go.push({ separator: true }, { label: $LL.serverSettings(), icon: 'settings', action: () => win.open('settings', { appState: { section: 'server' } }) })
    const view: MenuEntry[] = [
      { heading: $LL.history() },
      ...RANGES.map((r) => ({ label: r.label, checked: rangeMinutes === r.minutes, action: () => (rangeMinutes = r.minutes) })),
      { separator: true },
      ...visibleCardOrder.map((id) => ({ label: detailTitles[id], checked: detail === id, action: () => (detail = id) })),
      { separator: true },
      { label: paused ? $LL.deskResumeRefresh() : $LL.deskPauseRefresh(), icon: paused ? 'play_arrow' : 'pause', action: () => (paused = !paused) },
      { label: $LL.refresh(), icon: 'refresh', shortcut: '⌘R', action: refresh },
    ]
    return [
      { label: $LL.deskMenuView(), items: view },
      { label: $LL.deskMenuGo(), items: go },
    ]
  })
</script>

{#if detail}
  <AppToolbar title={detailTitles[detail]} back={leaveDetail} />
{:else}
  <AppToolbar subtitle={paused ? $LL.deskPaused() : `${$LL.deskLiveShort()} · ${$LL.deskEverySeconds({ n: systemPrefs.value.refreshSeconds })}`}>
    {#snippet actions()}
      <ToolbarGroup
        items={[
          {
            label: paused ? $LL.deskResumeRefresh() : $LL.deskPauseRefresh(),
            icon: paused ? 'play_arrow' : 'pause',
            onclick: () => (paused = !paused),
          },
          ...(canProcesses ? [{ label: $LL.processes(), icon: 'list_alt', onclick: () => win.open('process', { appState: { sort: 'cpu' } }) }] : []),
        ]}
      />
    {/snippet}
  </AppToolbar>
{/if}

<!-- A reading's detail is a page over the overview: back (or a swipe)
     returns, and a swipe the other way opens the detail left last. -->
<PageStack
  key={detail ?? 'overview'}
  depth={detail ? 1 : 0}
  back={detail ? { key: 'overview', go: leaveDetail } : null}
  forward={!detail && leftDetail ? { key: leftDetail, go: () => (detail = leftDetail) } : null}
>
<main class="status-app pane-board pb-[21px]">
  {#if metrics.loading}
    <div class="flex h-full items-center justify-center"><Spinner size={48} /></div>
  {:else}
    {#if error}
      <Card class="mb-[9px] flex items-start gap-[9px] text-[13px] text-(--color-danger)">
        <Icon name="error" size={18} />
        <p>{error}</p>
      </Card>
    {/if}

    <!-- Informational, not a warning: every switch under `[remote_access]` is
         off until someone edits the file, and the docs recommend leaving them
         that way. Most agents are in this state on purpose, so this says what
         is off and where the switches are, and stops there. -->
    {#if access.viewOnly}
      <Card class="mb-[9px] space-y-[7px]">
        <h2 class="text-[15px] font-semibold text-(--text-primary)">{$LL.remoteAccessOffTitle()}</h2>
        <!-- With roles, more is an administrator's grant away rather than a
             config file's edit. -->
        <p class="text-[13px] text-(--text-secondary)">
          {capabilities?.grants ? $LL.remoteAccessOffBodyRoles() : $LL.remoteAccessOffBody()}
        </p>
      </Card>
    {/if}

    {#if detail}
      <DetailPanel kind={detail} metrics={m} {history} />
    {:else}
      <!-- The machine: its name and state, then what it runs on. -->
      <header class="flex flex-wrap items-end gap-[17px] px-[3px] pb-[17px] pt-[9px]">
        <div class="flex min-w-0 flex-1 flex-col gap-[5px]">
          <div class="flex items-center gap-[9px]">
            <span class="truncate text-[27px] leading-none font-extrabold tracking-[-0.02em]">{headerName}</span>
            <Badge tone={connected ? 'success' : 'danger'} dot>{connected ? $LL.connected() : $LL.disconnected()}</Badge>
          </div>
          <p class="text-[12px] text-(--text-secondary) [text-wrap:pretty]">{about}</p>
        </div>
        {#if m?.uptime}
          <div class="flex flex-col items-end gap-[3px]">
            <span class="text-[11px] font-bold tracking-[.06em] text-(--text-tertiary) uppercase">{$LL.uptime()}</span>
            <span class="lk-num text-[15px] font-semibold">{m.uptime}</span>
          </div>
        {/if}
      </header>

      <!-- Card order is the agent's, shared by everyone who views it; an
           administrator rearranges it by dragging. -->
      <div class="grid grid-cols-[repeat(auto-fit,minmax(138px,1fr))] gap-[9px]" role="list">
        {#each visibleCardOrder as id (id)}
          {@const t = tile(id)}
          {#if t}
            <div
              role="listitem"
              draggable={canArrange}
              title={canArrange ? undefined : $LL.cardOrderAdminOnly()}
              ondragstart={() => onCardDragStart(id)}
              ondragover={onCardDragOver}
              ondrop={() => onCardDrop(id)}
              class="min-w-0"
            >
              <StatTile {...t} />
            </div>
          {/if}
        {/each}
      </div>

      <!-- Usage over the chosen range. -->
      <section class="mt-[9px] rounded-[13px] bg-(--surface-card) px-[13px] pt-[13px] pb-[9px]">
        <div class="mb-[9px] flex flex-wrap items-center gap-[9px]">
          <h2 class="text-[15px] font-bold">{$LL.usage()}</h2>
          <div class="flex flex-wrap gap-[3px]">
            {#each USAGE as s (s.id)}
              <LegendChip
                label={s.label}
                value={s.values.length ? fmtPercent(s.values.at(-1)!) : undefined}
                color={s.color}
                on={seriesOn[s.id]}
                onclick={() => (seriesOn = { ...seriesOn, [s.id]: !seriesOn[s.id] })}
              />
            {/each}
          </div>
          <span class="flex-1"></span>
          <SegmentedControl
            size="sm"
            label={$LL.history()}
            options={RANGES.map((r) => ({ value: String(r.minutes), label: r.label }))}
            value={String(rangeMinutes)}
            onchange={(value) => (rangeMinutes = Number(value))}
          />
        </div>
        {#if historyError}<p class="mb-[9px] text-[13px] text-(--color-danger)">{historyError}</p>{/if}
        <UsageChart label={$LL.usage()} series={usageSeries} times={historyLabels} max={usageMax} format={(v) => `${+v.toFixed(1)}%`} axis {xLabels} />
      </section>

      <div class="mt-[9px] grid grid-cols-[repeat(auto-fit,minmax(260px,1fr))] gap-[9px]">
        <!-- The network now, and over the range. -->
        <section class="flex min-w-0 flex-col gap-[9px] rounded-[13px] bg-(--surface-card) p-[13px]">
          <div class="flex flex-wrap items-baseline gap-[9px]">
            <h2 class="text-[15px] font-bold">{$LL.network()}</h2>
            {#if iface}<span class="text-[12px] text-(--text-tertiary)">{iface}</span>{/if}
            <span class="flex-1"></span>
            {#if m}
              <span class="lk-num text-[12px] text-(--text-tertiary)"
                >↓ {fmtBytes(m.network.rx_bytes_exact ?? m.network.rx_bytes)} · ↑ {fmtBytes(m.network.tx_bytes_exact ?? m.network.tx_bytes)}</span
              >
            {/if}
          </div>
          <div class="flex gap-[21px]">
            {#each [{ label: $LL.down(), color: 'var(--color-accent)', value: latest?.net_rx_speed }, { label: $LL.up(), color: 'var(--hue-blue)', value: latest?.net_tx_speed }] as r (r.label)}
              <div class="flex flex-col gap-[3px]">
                <span class="flex items-center gap-[5px] text-[12px] text-(--text-secondary)"
                  ><span class="h-[7px] w-[7px] rounded-full" style:background={r.color}></span>{r.label}</span
                >
                <span class="lk-num text-[21px] font-bold tracking-[-0.01em]">{r.value != null ? fmtBytesPerSec(r.value) : '--'}</span>
              </div>
            {/each}
          </div>
          <UsageChart label={$LL.network()} series={networkSeries} times={historyLabels} format={fmtBytesPerSec} height={55} />
        </section>

        {#if canProcesses}
          <!-- The busiest processes; the whole table is one click away. -->
          <section class="flex min-w-0 flex-col rounded-[13px] bg-(--surface-card) px-[13px] pt-[13px] pb-[7px]">
            <div class="mb-[5px] flex items-baseline gap-[9px]">
              <h2 class="text-[15px] font-bold">{$LL.statusTopProcesses()}</h2>
              <span class="flex-1"></span>
              <button type="button" class="text-[12px] font-semibold text-(--color-accent-text) hover:underline" onclick={() => win.open('process', { appState: { sort: 'cpu' } })}
                >{$LL.statusAllProcesses()}</button
              >
            </div>
            {#each topProcs as p (p.pid)}
              <button
                type="button"
                class="-mx-[5px] grid h-[30px] grid-cols-[minmax(0,1fr)_54px_54px] items-center gap-[9px] rounded-[7px] px-[5px] text-left hover:bg-(--fill-hover)"
                onclick={() => win.open('process', { appState: { sort: 'cpu' } })}
              >
                <span class="truncate font-semibold">{p.name}</span>
                <span class="lk-num text-right text-(--text-secondary)">{p.cpu === null ? '—' : fmtPercent(p.cpu)}</span>
                <span class="lk-num text-right text-(--text-secondary)">{p.mem === null ? '—' : fmtPercent(p.mem)}</span>
              </button>
            {:else}
              <div class="grid flex-1 place-items-center py-[13px]"><Spinner size="sm" /></div>
            {/each}
          </section>
        {/if}

        {#if m}
          <section class="min-w-0 rounded-[13px] bg-(--surface-card) px-[13px] pt-[13px] pb-[5px]">
            <h2 class="mb-[5px] text-[15px] font-bold">{$LL.systemInformation()}</h2>
            <dl class="divide-y divide-(--border-hairline) text-[13px]">
              <div class="flex justify-between gap-[9px] py-[7px]"><dt class="text-(--text-secondary)">{$LL.serverNameLabel()}</dt><dd class="truncate text-right">{m.server_name}</dd></div>
              {#if m.sys}<div class="flex justify-between gap-[9px] py-[7px]"><dt class="text-(--text-secondary)">{$LL.osHost()}</dt><dd class="lk-mono truncate text-right text-[12px]">{m.sys}</dd></div>{/if}
              {#if m.conn}
                <!-- Linux reports tcpMaxConn as -1 when no static connection
                     limit exists. Display that sentinel as "unlimited". -->
                <div class="flex justify-between gap-[9px] py-[7px]"><dt class="text-(--text-secondary)">{$LL.connections()}</dt><dd class="lk-num">{m.conn.max_conn === -1 ? $LL.unlimited() : m.conn.max_conn}</dd></div>
              {/if}
              {#if m.swap.total > 0}<div class="flex justify-between gap-[9px] py-[7px]"><dt class="text-(--text-secondary)">{$LL.swap()}</dt><dd class="lk-num text-right">{fmtBytes(m.swap.used)} / {fmtBytes(m.swap.total)}</dd></div>{/if}
              <div class="flex justify-between gap-[9px] py-[7px]"><dt class="text-(--text-secondary)">{$LL.lastUpdated()}</dt><dd class="lk-num text-right text-[12px]">{fmtDate(new Date(m.timestamp), DATE_TIME)}</dd></div>
            </dl>
          </section>
        {/if}

        <!-- The user's custom commands and their latest output, from the
             extended cycle. Each row is one line; a longer output opens in the
             dialog below. -->
        {#if m?.custom_cmds?.length}
          <section class="min-w-0 rounded-[13px] bg-(--surface-card) px-[13px] pt-[13px] pb-[7px]">
            <div class="mb-[5px] flex items-center gap-[9px]">
              <h2 class="min-w-0 flex-1 text-[15px] font-bold">{$LL.customCmd()}</h2>
              <IconButton icon="settings" size="sm" label={$LL.serverSettings()} onclick={() => win.open('settings', { appState: { section: 'server' } })} />
            </div>
            {#each m.custom_cmds as cmd (cmd.name)}
              {@const multi = displayOutput(cmd.output).includes('\n')}
              <!-- The text is the machine's own output, so it is drawn as text
                   and never as markup. -->
              <button
                type="button"
                class="-mx-[5px] flex h-[30px] w-[calc(100%+10px)] items-center justify-between gap-[9px] rounded-[7px] px-[5px] text-left {multi ? 'hover:bg-(--fill-hover)' : ''}"
                disabled={!multi}
                onclick={() => (cmdDetail = multi ? cmd : null)}
              >
                <span class="lk-mono shrink-0 truncate text-[12px] text-(--text-tertiary)">{cmd.name}</span>
                <span class="lk-mono truncate text-[13px] text-(--text-primary)">{firstLine(cmd.output)}</span>
              </button>
            {/each}
            <p class="pt-[3px] text-[12px] text-(--text-tertiary)">{$LL.customCmdCount({ count: m.custom_cmds.length })}</p>
          </section>
        {/if}
      </div>
    {/if}
  {/if}
</main>
</PageStack>


<PowerModal open={powerOpen} onclose={() => (powerOpen = false)} />

{#if iperfOpen}
  <IperfModal onclose={() => (iperfOpen = false)} />
{/if}

<!-- A custom command's full output. It is the machine's own text, so it is
     drawn as text in a `pre` — never as HTML or Markdown. -->
{#if cmdDetail}
  <Dialog open wide title={cmdDetail.name} onclose={() => (cmdDetail = null)}>
    <pre class="lk-mono max-h-96 overflow-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] text-[13px] whitespace-pre-wrap break-all text-(--text-primary)">{cmdDetail.output}</pre>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (cmdDetail = null)}>{$LL.close()}</Button>
    {/snippet}
  </Dialog>
{/if}
