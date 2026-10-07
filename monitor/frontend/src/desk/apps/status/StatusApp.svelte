<script lang="ts">
  import { Badge, Button, Card, Dialog, Icon, IconButton, SegmentedControl, Spinner } from '../../lk'
  import DetailPanel, { type DetailKind } from './DetailPanel.svelte'
  import IperfModal from './IperfModal.svelte'
  import LineChart from '../../../components/LineChart.svelte'
  import OsIcon from '../../../components/OsIcon.svelte'
  import PowerModal from './PowerModal.svelte'
  import StatCard from './StatCard.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import { useWindow } from '../../deskState.svelte'
  import { dashboardAccess, isAdmin, machineAccess } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { health } from '../../../lib/health.svelte'
  import { displayName, servers } from '../../../lib/servers.svelte'
  import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { Poller } from '../../../lib/poller.svelte'
  import { fly } from 'svelte/transition'
  import type { CustomCmdOutput, HistoryPoint } from '../../../types'

  const metrics = new Poller(api.getMetrics, 5000)
  const win = useWindow()

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
    { label: 'CPU', color: 'var(--status-chart-one)', values: history.map((p) => p.cpu) },
    { label: $LL.memory(), color: 'var(--status-chart-two)', values: history.map((p) => p.memory) },
    { label: $LL.diskUsage(), color: 'var(--status-chart-three)', values: history.map((p) => p.disk) },
  ])
  const networkSeries = $derived([
    { label: $LL.down(), color: 'var(--status-chart-one)', values: history.map((p) => p.net_rx_speed) },
    { label: $LL.up(), color: 'var(--status-chart-two)', values: history.map((p) => p.net_tx_speed) },
  ])

  const error = $derived(metrics.error)
  // Agent reachability (unauthenticated /health ping, always running via
  // DeskRoot) — independent of the session's own requests, so a slow metrics
  // poll does not read as "disconnected"
  const connected = $derived(health.status[servers.currentId] ?? false)

  let detail = $state<DetailKind | null>(null)

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
</script>

{#if detail}
  <AppToolbar title={detailTitles[detail]} back={() => (detail = null)} />
{:else}
  <AppToolbar title={headerName}>
    {#snippet leading()}
      {@const statusTitle = connected ? $LL.connected() : $LL.disconnected()}
      {#if capabilities?.platform}
        <OsIcon platform={capabilities.platform} size={20} title={statusTitle} />
      {:else}
        <Icon name="dns" size={20} color={connected ? 'var(--color-success)' : 'var(--color-danger)'} title={statusTitle} />
      {/if}
    {/snippet}
    {#snippet actions()}
      <Badge tone={connected ? 'success' : 'danger'} dot>
        {connected ? $LL.connected() : $LL.disconnected()}
      </Badge>
      {#if access.terminal}<IconButton icon="terminal" label={$LL.terminal()} onclick={() => win.open('terminal')} />{/if}
      {#if access.files}<IconButton icon="folder_open" label={$LL.files()} onclick={() => win.open('files')} />{/if}
      {#if canIperf}<IconButton icon="speed" label={$LL.iperf()} onclick={() => (iperfOpen = true)} />{/if}
      {#if canPower}<IconButton icon="power_settings_new" label={$LL.powerControl()} onclick={() => (powerOpen = true)} />{/if}
      <IconButton icon="settings" label={$LL.serverSettings()} onclick={() => win.open('settings', { appState: { section: 'server' } })} />
      <IconButton icon="refresh" label={$LL.refresh()} onclick={refresh} />
    {/snippet}
  </AppToolbar>
{/if}

<main class="status-app mx-auto w-full max-w-7xl px-[17px] pb-[17px] pt-[4px]">
  {#if metrics.loading}
    <div class="flex h-full items-center justify-center"><Spinner size={48} /></div>
  {:else}
    {#if error}
      <Card class="mb-[13px] flex items-start gap-[9px] text-[13px] text-(--color-danger)">
        <Icon name="error" size={18} />
        <p>{error}</p>
      </Card>
    {/if}

    <!-- Informational, not a warning: every switch under `[remote_access]` is
         off until someone edits the file, and the docs recommend leaving them
         that way. Most agents are in this state on purpose, so this says what
         is off and where the switches are, and stops there. -->
    {#if access.viewOnly}
      <Card class="mb-[13px] space-y-[7px]">
        <h2 class="text-[15px] font-semibold text-(--text-primary)">{$LL.remoteAccessOffTitle()}</h2>
        <!-- With roles, more is an administrator's grant away rather than a
             config file's edit. -->
        <p class="text-[13px] text-(--text-secondary)">
          {capabilities?.grants ? $LL.remoteAccessOffBodyRoles() : $LL.remoteAccessOffBody()}
        </p>
      </Card>
    {/if}

    {#key detail}
      <div in:fly={{ x: detail ? 16 : -16, duration: 200, delay: 150 }} out:fly={{ x: detail ? -16 : 16, duration: 150 }}>
    {#if detail}
      <DetailPanel kind={detail} metrics={m} {history} />
    {:else}
    <div class="grid grid-cols-1 @5xl:grid-cols-[minmax(0,1fr)_18rem] items-start gap-4 @5xl:gap-5">
      <section class="min-w-0 space-y-4">
    {#snippet card(id: CardId)}
      {#if id === 'cpu'}
        <StatCard
          icon="memory"
          iconColor="var(--hue-blue)"
          label={$LL.cpuUsage()}
          value={m ? `${m.cpu_usage.toFixed(1)}%` : '--'}
          detail={m
            ? [
                // `cpu_brand` already includes the logical core count, e.g.
                // "Apple M5 Pro (x18)". Older agents use a bare core count.
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
          icon="memory"
          iconColor="var(--hue-teal)"
          label={$LL.memory()}
          value={m ? `${m.memory.usage_percent.toFixed(1)}%` : '--'}
          detail={m ? `${fmtBytes(m.memory.used)} / ${fmtBytes(m.memory.total)}` : ''}
          onclick={() => (detail = 'memory')}
        />
      {:else if id === 'disk'}
        <StatCard
          icon="hard_drive"
          iconColor="var(--hue-amber)"
          label={$LL.diskUsage()}
          value={m ? `${m.disk.usage_percent.toFixed(1)}%` : '--'}
          detail={m ? `${fmtBytes(m.disk.used)} / ${fmtBytes(m.disk.total)}` : ''}
          onclick={() => (detail = 'disk')}
        />
      {:else if id === 'network'}
        <StatCard
          icon="lan"
          iconColor="var(--hue-violet)"
          label={$LL.network()}
          compact
          value={latest
            ? `\u2193 ${fmtBytesPerSec(latest.net_rx_speed)}  \u2191 ${fmtBytesPerSec(latest.net_tx_speed)}`
            : '--'}
          detail={m
            ? `RX ${fmtBytes(m.network.rx_bytes_exact ?? m.network.rx_bytes)} \u00B7 TX ${fmtBytes(m.network.tx_bytes_exact ?? m.network.tx_bytes)}`
            : ''}
          onclick={() => (detail = 'network')}
        />
      {:else if id === 'gpu' && m?.gpus?.length}
        <StatCard
          icon="speed"
          iconColor="var(--hue-red)"
          label={$LL.gpu()}
          value={m.gpus[0].usage_percent != null ? `${m.gpus[0].usage_percent.toFixed(0)}%` : '--'}
          detail={m.gpus[0].name}
          onclick={() => (detail = 'gpu')}
        />
      {:else if id === 'battery' && m?.batteries?.length}
        <StatCard
          icon="battery_5_bar"
          iconColor="var(--hue-green)"
          label={$LL.battery()}
          value={m.batteries[0].percent != null ? `${m.batteries[0].percent}%` : '--'}
          detail={m.batteries[0].name ?? ''}
          onclick={() => (detail = 'battery')}
        />
      {:else if id === 'sensors' && m?.sensors?.length}
        <StatCard
          icon="thermostat"
          iconColor="var(--hue-blue)"
          label={$LL.sensors()}
          value={String(m.sensors.length)}
          detail={m.sensors[0].device}
          onclick={() => (detail = 'sensors')}
        />
      {:else if id === 'smart' && m?.disk_smart?.length}
        <StatCard
          icon="shield_lock"
          iconColor={m.disk_smart.every((d) => d.healthy !== false) ? 'var(--color-success)' : 'var(--color-danger)'}
          label={$LL.smart()}
          value={`${m.disk_smart.filter((d) => d.healthy !== false).length} / ${m.disk_smart.length}`}
          detail={$LL.healthy()}
          onclick={() => (detail = 'smart')}
        />
      {/if}
    {/snippet}

    <!-- Three columns prevent the optional cards from crowding tablet-width
         viewports before the layout expands to four columns. Card order is
         synced through cardOrder; HTML5 drag-and-drop is pointer-only. -->
    <div class="grid grid-cols-[repeat(auto-fill,minmax(160px,1fr))] gap-[9px] mb-[17px]">
      {#each visibleCardOrder as id (id)}
        <div
          role="listitem"
          draggable={canArrange}
          title={canArrange ? undefined : $LL.cardOrderAdminOnly()}
          ondragstart={() => onCardDragStart(id)}
          ondragover={onCardDragOver}
          ondrop={() => onCardDrop(id)}
          class={canArrange ? 'cursor-grab active:cursor-grabbing' : undefined}
        >
          {@render card(id)}
        </div>
      {/each}
    </div>

    <div class="mb-[9px] flex items-center justify-between">
      <h2 class="text-[15px] font-semibold text-(--text-primary)">{$LL.history()}</h2>
      <SegmentedControl
        size="sm"
        label={$LL.history()}
        options={RANGES.map((r) => ({ value: String(r.minutes), label: r.label }))}
        value={String(rangeMinutes)}
        onchange={(value) => (rangeMinutes = Number(value))}
      />
    </div>

    {#if historyError}
      <p class="mb-[9px] text-[13px] text-(--color-danger)">{historyError}</p>
    {/if}

    <div class="grid grid-cols-1 gap-3 @2xl:gap-4">
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

      </section>
      <aside class="min-w-0 space-y-4">
    {#if metrics.data}
      {@const m = metrics.data}
      <Card title={$LL.systemInformation()}>
        <div class="divide-y divide-(--border-hairline)">
          <div class="flex justify-between gap-[9px] py-[7px] text-[13px]">
            <span class="text-(--text-secondary)">{$LL.serverNameLabel()}</span>
            <span class="lk-num text-right">{m.server_name}</span>
          </div>
          {#if m.sys}
            <div class="flex justify-between gap-[9px] py-[7px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.osHost()}</span>
              <span class="lk-mono truncate text-right text-[12px]">{m.sys}</span>
            </div>
          {/if}
          {#if m.uptime}
            <div class="flex justify-between gap-[9px] py-[7px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.uptime()}</span>
              <span class="lk-num">{m.uptime}</span>
            </div>
          {/if}
          {#if m.conn}
            <div class="flex justify-between gap-[9px] py-[7px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.connections()}</span>
              <!-- Linux reports tcpMaxConn as -1 when no static connection
                   limit exists. Display that sentinel as "unlimited". -->
              <span class="lk-num">
                {m.conn.max_conn === -1 ? $LL.unlimited() : m.conn.max_conn}
              </span>
            </div>
          {/if}
          <div class="flex justify-between gap-[9px] py-[7px] text-[13px]">
            <span class="text-(--text-secondary)">{$LL.lastUpdated()}</span>
            <span class="lk-num text-right text-[12px]">{new Date(m.timestamp).toLocaleString()}</span>
          </div>
          {#if m.swap.total > 0}
            <div class="flex justify-between gap-[9px] py-[7px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.swap()}</span>
              <span class="lk-num text-right">{fmtBytes(m.swap.used)} / {fmtBytes(m.swap.total)}</span>
            </div>
          {/if}
        </div>
      </Card>
    {/if}

    <!-- The user's custom commands and their latest output, from the extended
         cycle. Absent when there are none, like the app's card; each row is
         one line, and a longer output opens in the dialog below. -->
    {#if m?.custom_cmds?.length}
      <Card>
        <div class="mb-[9px] flex items-center gap-[9px]">
          <h3 class="min-w-0 flex-1 text-[15px] font-semibold text-(--text-primary)">{$LL.customCmd()}</h3>
          <IconButton icon="settings" label={$LL.serverSettings()} onclick={() => win.open('settings', { appState: { section: 'server' } })} />
        </div>
        <div class="divide-y divide-(--border-hairline)">
          {#each m.custom_cmds as cmd (cmd.name)}
            {@const multi = displayOutput(cmd.output).includes('\n')}
            <!-- A row is one line; a multi-line output is what the dialog is
                 for. The text is the machine's own output, so it is drawn as
                 text and never as markup. -->
            <button
              type="button"
              class="flex w-full items-center justify-between gap-[9px] rounded-[7px] px-[13px] py-[7px] text-left even:bg-(--fill-hover) {multi ? 'cursor-pointer hover:bg-(--fill-hover)' : 'cursor-default'}"
              disabled={!multi}
              onclick={() => (cmdDetail = multi ? cmd : null)}
            >
              <span class="lk-mono shrink-0 truncate text-[12px] text-(--text-tertiary)">{cmd.name}</span>
              <span class="lk-mono truncate text-[13px] text-(--text-primary)">{firstLine(cmd.output)}</span>
            </button>
          {/each}
        </div>
        <p class="mt-[9px] text-[12px] text-(--text-tertiary)">{$LL.customCmdCount({ count: m.custom_cmds.length })}</p>
      </Card>
    {/if}
      </aside>
    </div>
    {/if}
      </div>
    {/key}
  {/if}
</main>

<style>
  .status-app {
    --status-chart-one: var(--color-accent);
    --status-chart-two: var(--hue-blue);
    --status-chart-three: var(--hue-teal);
    --status-chart-four: var(--hue-violet);
    --status-chart-five: var(--hue-amber);
    --status-chart-six: var(--hue-green);
    --status-chart-seven: var(--hue-teal);
    --status-chart-eight: var(--hue-red);
  }
</style>

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
