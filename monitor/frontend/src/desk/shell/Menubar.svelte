<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { api } from '../../lib/api'
  import { fmtBytes, fmtDate, fmtPercent } from '../../lib/format'
  import { Poller } from '../../lib/poller.svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName } from '../../lib/servers.svelte'
  import { app } from '../registry.svelte'
  import { systemPrefs } from '../sys/systemPrefs.svelte'
  import { useDesk, type MenuItem } from '../deskState.svelte'
  import Icon from '../lk/Icon.svelte'

  interface Props {
    /// Lock and log out, with their shortcuts (the desk runs those).
    session: () => MenuItem[]
    /// Leaves this server's desk for the lock screen, still signed in.
    ondisconnect: () => void
  }

  const { session, ondisconnect }: Props = $props()
  const desk = useDesk()

  const serverLabel = $derived(
    serverNames.byServer[desk.entry.id] ?? (desk.entry.id === 'local' ? $LL.thisServer() : displayName(desk.entry)),
  )
  const online = $derived(!desk.storage?.remote || desk.live)
  const active = $derived(desk.windows.active)
  const activeSpec = $derived(active ? app(active.appId) : undefined)

  let now = $state(new Date())
  $effect(() => {
    const t = setInterval(() => (now = new Date()), 15_000)
    return () => clearInterval(t)
  })
  const clock = $derived(
    `${new Intl.DateTimeFormat($locale, { weekday: 'short', month: 'short', day: 'numeric' }).format(now)} ${fmtDate(now, { hour: '2-digit', minute: '2-digit' }, $locale)}`,
  )

  /// The machine's CPU in the bar, read while the desk is in sight. An
  /// account that may not read metrics simply has no reading.
  const metrics = new Poller(api.getMetrics, systemPrefs.refreshMs)
  $effect(() => {
    metrics.interval = Math.max(2000, systemPrefs.refreshMs)
  })
  $effect(() => {
    if (desk.locked || desk.hidden) return
    metrics.start()
    return () => metrics.stop()
  })
  const reading = $derived(metrics.error ? null : metrics.data)

  const chrome = $derived(desk.activeChrome)
  const appName = $derived(chrome?.appName ?? activeSpec?.title($LL) ?? '')

  /// Opens [items] under the bar item [e] came from, as [owner]; [end]
  /// aligns its right edge with the item's (the bar's right side).
  function menuUnder(e: MouseEvent, owner: string, items: MenuItem[], end = false) {
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
    const barBottom = bar?.getBoundingClientRect().bottom ?? r.bottom
    e.stopPropagation()
    desk.panel = null
    desk.spotlight = false
    // A click on the title of the menu that was open closes it (the press
    // already took it down, so ask what was open then).
    const open = e.type === 'click' ? openAtPress : desk.menu?.owner
    openAtPress = null
    desk.menu = open === owner ? null : { x: end ? r.right : r.left, y: barBottom + 2, items, owner, end }
  }

  let bar = $state<HTMLElement | null>(null)

  /// Glass under the bar once a window reaches up to it; the wallpaper
  /// through it otherwise.
  const glass = $derived(
    !desk.agentMode && desk.windows.windows.some((w) => !w.minimized && w.rect.y <= desk.windows.area.top + 1),
  )

  /// The bar menu open when the pointer went down on the bar.
  let openAtPress: string | null = null

  /// With one of the bar's menus open, pointing at another title opens it.
  function hover(e: MouseEvent, owner: string, items: () => MenuItem[], end = false) {
    if (desk.menu?.owner && desk.menu.owner !== owner) menuUnder(e, owner, items(), end)
  }

  function openable(id: string): boolean {
    return !!app(id)?.available(desk.caps)
  }

  /// The server menu: its main apps, its settings, the session.
  function serverItems(): MenuItem[] {
    const items: MenuItem[] = []
    for (const id of ['status', 'process', 'services']) {
      const spec = app(id)
      if (spec && openable(id)) items.push({ label: spec.title($LL), icon: spec.glyph, action: () => desk.open(id) })
    }
    items.push(
      { separator: true },
      { label: $LL.deskServerSettings(), icon: 'dns', action: () => desk.open('settings', { appState: { section: 'server' } }) },
      { label: $LL.deskDisconnect(), icon: 'link_off', action: ondisconnect },
      { separator: true },
      ...session(),
    )
    return items
  }

  /// The app menu: the app as a whole.
  function appItems(): MenuItem[] {
    if (!activeSpec || !active) return []
    const spec = activeSpec
    const id = active.id
    const items: MenuItem[] = []
    if (spec.instances > 1) {
      items.push(
        {
          label: $LL.deskNewWindow(),
          icon: 'add',
          disabled: desk.windows.of(spec.id).length >= spec.instances,
          action: () => desk.open(spec.id, { newWindow: true }),
        },
        { separator: true },
      )
    }
    items.push(
      { label: `${$LL.deskHide()} ${appName}`, action: () => desk.windows.minimize(id) },
      { label: `${$LL.deskQuit()} ${appName}`, icon: 'close', action: () => desk.windows.closeApp(spec.id) },
    )
    return items
  }

  /// The Window menu: the front window, then every window of its app.
  function windowItems(): MenuItem[] {
    if (!active || !activeSpec) return []
    const id = active.id
    const mine = desk.windows.of(activeSpec.id)
    const items: MenuItem[] = [
      { label: $LL.deskMinimize(), action: () => desk.windows.minimize(id) },
      { label: $LL.deskZoom(), action: () => desk.windows.toggleMaximize(id) },
      { label: $LL.deskBringAllToFront(), action: () => mine.forEach((w) => desk.windows.focus(w.id)) },
      { separator: true },
      ...mine.map((w) => ({
        label: w.title ?? activeSpec!.title($LL),
        checked: w.id === id,
        action: () => desk.windows.focus(w.id),
      })),
      { separator: true },
      { label: $LL.deskClose(), action: () => desk.windows.close(id) },
    ]
    if (mine.length > 1) items.push({ label: $LL.deskCloseAll(), action: () => desk.windows.closeApp(activeSpec!.id) })
    return items
  }

  function helpItems(): MenuItem[] {
    return [
      {
        label: $LL.deskSearch(),
        icon: 'search',
        shortcut: '⌘K',
        action: () => {
          desk.panel = null
          desk.spotlight = true
        },
      },
      { separator: true },
      {
        label: $LL.deskReportProblem(),
        icon: 'bug_report',
        action: () => window.open('https://github.com/lollipopkit/flutter_server_box/issues', '_blank', 'noopener'),
      },
    ]
  }

  /// The CPU reading's menu: the machine at a glance, and where to look closer.
  function cpuItems(): MenuItem[] {
    const m = reading
    if (!m) return []
    const cores = m.cpu_cores?.length
    const items: MenuItem[] = [
      { heading: `CPU ${fmtPercent(m.cpu_usage)}${cores ? ` · ${$LL.deskCores({ n: cores })}` : ''}` },
      {
        label: `${$LL.memory()} ${fmtPercent(m.memory.usage_percent)} · ${fmtBytes(m.memory.used)} / ${fmtBytes(m.memory.total)}`,
        disabled: true,
        action: () => {},
      },
    ]
    if (m.uptime) items.push({ label: m.uptime, disabled: true, action: () => {} })
    items.push({ separator: true })
    if (openable('process')) items.push({ label: app('process')!.title($LL), icon: 'memory', action: () => desk.open('process') })
    if (openable('status')) items.push({ label: $LL.deskOpenStatus(), icon: 'monitoring', action: () => desk.open('status') })
    return items
  }

  /// Agent → the tasks: a new one, every finished one, the open one.
  function agentTaskItems(): MenuItem[] {
    const a = desk.agent
    if (!a) return []
    const open = a.flows.find((f) => f.id === a.openId)
    const items: MenuItem[] = [
      { label: $LL.deskAgentNewTask(), icon: 'add', action: () => a.ask('new') },
      { label: $LL.deskAgentAllTasks(), icon: 'history', action: () => a.ask('history') },
    ]
    if (open && (open.status === 'running' || open.status === 'waiting' || open.status === 'queued')) {
      items.push({ separator: true }, { label: $LL.deskAgentStop(), icon: 'stop_circle', action: () => void a.stopFlow(open.id) })
    }
    return items
  }

  /// Agent → what is shown: the timeline, the open task's steps.
  function agentViewItems(): MenuItem[] {
    const a = desk.agent
    if (!a) return []
    const inFlow = !!a.openId
    return [
      { label: $LL.deskAgentTimeline(), icon: 'view_timeline', disabled: !inFlow, action: () => a.close() },
      { separator: true },
      { label: $LL.deskAgentPrevStep(), icon: 'keyboard_arrow_up', disabled: !inFlow, action: () => a.ask('step', -1) },
      { label: $LL.deskAgentNextStep(), icon: 'keyboard_arrow_down', disabled: !inFlow, action: () => a.ask('step', 1) },
    ]
  }

  type Title = { owner: string; label: string; items: () => MenuItem[] }

  /// The desk's menus left to right: the app, the app's own, Window, Help.
  const deskTitles = $derived.by(() => {
    const out: Title[] = []
    if (activeSpec) {
      out.push({ owner: 'app', label: appName, items: appItems })
      for (const [i, menu] of (chrome?.menus ?? []).entries()) {
        out.push({ owner: `menu:${i}`, label: menu.label, items: () => menu.items })
      }
      out.push({ owner: 'window', label: $LL.deskWindowMenu(), items: windowItems })
    }
    out.push({ owner: 'help', label: $LL.deskHelpMenu(), items: helpItems })
    return out
  })

  /// Agent mode's own: Tasks, View, Help.
  const agentTitles = $derived<Title[]>([
    { owner: 'agent:tasks', label: $LL.deskAgentTasksMenu(), items: agentTaskItems },
    { owner: 'agent:view', label: $LL.deskMenuView(), items: agentViewItems },
    { owner: 'agent:help', label: $LL.deskHelpMenu(), items: helpItems },
  ])

  const unread = $derived(desk.notifications?.unread ?? 0)
  const dnd = $derived(desk.notifications?.dnd ?? false)
</script>

{#snippet titleButton(t: Title)}
  <button
    class="lk-menubar__item max-w-48 truncate"
    class:hidden={t.owner !== 'app' && desk.windows.compact}
    class:lk-menubar__item--open={desk.menu?.owner === t.owner}
    aria-haspopup="menu"
    onclick={(e) => menuUnder(e, t.owner, t.items())}
    onpointerenter={(e) => hover(e, t.owner, t.items)}
  >
    {t.label}
  </button>
{/snippet}

<nav
  bind:this={bar}
  class="lk-menubar absolute inset-x-0 top-0 z-[100000]"
  class:lk-menubar--glass={glass}
  aria-label={$LL.deskMenubar()}
  onpointerdown={(e) => {
    // Its buttons toggle what they open; the desk's own dismissal would
    // close it first and the click open it again, so what was open is kept
    // for the click to compare with.
    e.stopPropagation()
    openAtPress = desk.menu?.owner ?? null
    desk.menu = null
  }}
>
  <!-- The server this desk is on, its dot saying whether the desk hears from
       it; then the front app's menus, or Agent mode's, one fading into the
       other. -->
  <div class="lk-menubar__side">
    <button
      class="lk-menubar__item lk-menubar__lead"
      class:lk-menubar__item--open={desk.menu?.owner === 'server'}
      aria-haspopup="menu"
      title={desk.storage?.remote ? (desk.live ? $LL.deskLive() : $LL.deskOffline()) : undefined}
      onclick={(e) => menuUnder(e, 'server', serverItems())}
      onpointerenter={(e) => hover(e, 'server', serverItems)}
    >
      <span class="lk-menubar__status" class:lk-menubar__status--off={!online}></span>
      <span class="max-w-40 truncate">{serverLabel}</span>
    </button>
    <div class="lk-menubar__menus">
      <div class="lk-menubar__group" class:lk-menubar__group--off={desk.agentMode} data-to="agent" inert={desk.agentMode}>
        {#each deskTitles as t (t.owner)}{@render titleButton(t)}{/each}
      </div>
      {#if desk.agentAvailable}
        <div class="lk-menubar__group" class:lk-menubar__group--off={!desk.agentMode} data-to="desk" inert={!desk.agentMode}>
          {#each agentTitles as t (t.owner)}{@render titleButton(t)}{/each}
        </div>
      {/if}
    </div>
  </div>

  <!-- Agent mode · CPU · search · Control Centre · notifications · the clock,
       the measured ones at fixed widths so a changing number moves nothing. -->
  <div class="lk-menubar__side lk-menubar__side--end">
    {#if desk.agentAvailable}
      <button
        class="lk-menubar__item lk-menubar__agent"
        class:lk-menubar__agent--on={desk.agentMode}
        aria-pressed={desk.agentMode}
        aria-label={$LL.deskAgentMode()}
        title={$LL.deskAgentMode()}
        onclick={(e) => {
          e.stopPropagation()
          desk.toggleAgent()
        }}
      >
        <Icon name="auto_awesome" size={15} fill={desk.agentMode} />
        {#if !desk.windows.compact}<span>{$LL.deskAgentMode()}</span>{/if}
      </button>
    {/if}
    {#if reading && !desk.windows.compact}
      <button
        class="lk-menubar__item lk-menubar__cpu"
        class:lk-menubar__item--open={desk.menu?.owner === 'cpu'}
        aria-haspopup="menu"
        aria-label="CPU {fmtPercent(reading.cpu_usage)}"
        onclick={(e) => menuUnder(e, 'cpu', cpuItems(), true)}
        onpointerenter={(e) => hover(e, 'cpu', cpuItems, true)}
      >
        <Icon name="data_usage" size={15} />{fmtPercent(reading.cpu_usage)}
      </button>
    {/if}
    <button
      class="lk-menubar__item lk-menubar__icon"
      class:lk-menubar__item--open={desk.spotlight}
      aria-label={$LL.deskSearch()}
      title="{$LL.deskSearch()} ⌘K"
      onclick={(e) => {
        e.stopPropagation()
        desk.panel = null
        desk.spotlight = !desk.spotlight
      }}
    >
      <Icon name="search" size={17} fill={desk.spotlight} />
    </button>
    <button
      class="lk-menubar__item lk-menubar__icon"
      class:lk-menubar__item--open={desk.panel === 'control'}
      aria-label={$LL.deskControlCenter()}
      title={$LL.deskControlCenter()}
      aria-expanded={desk.panel === 'control'}
      onclick={(e) => {
        e.stopPropagation()
        desk.togglePanel('control')
      }}
    >
      <Icon name="toggle_on" size={17} fill={desk.panel === 'control'} />
    </button>
    <button
      class="lk-menubar__item lk-menubar__icon"
      class:lk-menubar__item--open={desk.panel === 'notifications'}
      aria-label={$LL.deskNotifications()}
      title={$LL.deskNotifications()}
      aria-expanded={desk.panel === 'notifications'}
      onclick={(e) => {
        e.stopPropagation()
        desk.togglePanel('notifications')
      }}
    >
      <Icon name={dnd ? 'notifications_off' : 'notifications'} size={17} fill={desk.panel === 'notifications'} />
      {#if unread > 0 && !dnd}<span class="lk-menubar__dot"></span>{/if}
    </button>
    {#if !desk.windows.compact}
      <button
        class="lk-menubar__item lk-menubar__clock"
        class:lk-menubar__item--open={desk.panel === 'calendar'}
        aria-expanded={desk.panel === 'calendar'}
        onclick={(e) => {
          e.stopPropagation()
          desk.togglePanel('calendar')
        }}
      >
        {clock}
      </button>
    {/if}
  </div>
</nav>

<style>
  .lk-menubar__item:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
