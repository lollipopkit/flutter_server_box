<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { api } from '../../lib/api'
  import { fmtBytes, fmtPercent } from '../../lib/format'
  import { Poller } from '../../lib/poller.svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName, servers } from '../../lib/servers.svelte'
  import { app } from '../registry.svelte'
  import { useDesk, type MenuItem } from '../deskState.svelte'
  import AppIcon from '../lk/AppIcon.svelte'
  import Icon from '../lk/Icon.svelte'

  interface Props {
    onlock: () => void
  }

  const { onlock }: Props = $props()
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
    `${new Intl.DateTimeFormat($locale, { weekday: 'short', month: 'short', day: 'numeric' }).format(now)}  ${new Intl.DateTimeFormat($locale, { hour: '2-digit', minute: '2-digit' }).format(now)}`,
  )

  /// The machine's CPU in the bar, read while the desk is in sight. An
  /// account that may not read metrics simply has no reading.
  const metrics = new Poller(api.getMetrics, 5000)
  $effect(() => {
    if (desk.locked || desk.hidden) return
    metrics.start()
    return () => metrics.stop()
  })
  const reading = $derived(metrics.error ? null : metrics.data)

  const chrome = $derived(desk.activeChrome)
  const appName = $derived(chrome?.appName ?? activeSpec?.title($LL) ?? '')
  const appIcon = $derived(chrome?.icon ?? (activeSpec ? { glyph: activeSpec.glyph, tone: activeSpec.tone } : null))

  /// Opens [items] under the bar item [e] came from, as [owner]; [end]
  /// aligns its right edge with the item's (the bar's right side).
  function menuUnder(e: MouseEvent, owner: string, items: MenuItem[], end = false) {
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
    e.stopPropagation()
    desk.panel = null
    desk.spotlight = false
    desk.menu = desk.menu?.owner === owner && e.type === 'click' ? null : { x: end ? r.right : r.left, y: r.bottom + 3, items, owner, end }
  }

  /// With one of the bar's menus open, pointing at another title opens it.
  function hover(e: MouseEvent, owner: string, items: () => MenuItem[], end = false) {
    if (desk.menu?.owner && desk.menu.owner !== owner) menuUnder(e, owner, items(), end)
  }

  function openable(id: string): boolean {
    return !!app(id)?.available(desk.caps)
  }

  /// The server menu: where the desk is, its main apps, the session.
  function serverItems(): MenuItem[] {
    const items: MenuItem[] = [{ heading: `${serverLabel} · ${online ? $LL.deskLiveShort() : $LL.deskOfflineShort()}` }]
    for (const id of ['status', 'process', 'services']) {
      const spec = app(id)
      if (spec && openable(id)) items.push({ label: spec.title($LL), icon: spec.glyph, action: () => desk.open(id) })
    }
    items.push(
      { separator: true },
      { label: $LL.deskAppSettings(), icon: 'settings', shortcut: '⌘,', action: () => desk.open('settings') },
      { separator: true },
      { label: $LL.deskLock(), icon: 'lock', action: onlock },
      {
        label: $LL.logout(),
        icon: 'logout',
        danger: true,
        action: () => {
          servers.logout(desk.entry.id)
          onlock()
        },
      },
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
      { label: `${$LL.deskHide()} ${appName}`, shortcut: '⌘H', action: () => desk.windows.minimize(id) },
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
      { label: $LL.deskMinimize(), shortcut: '⌘M', action: () => desk.windows.minimize(id) },
      { label: $LL.deskZoom(), action: () => desk.windows.toggleMaximize(id) },
      { label: $LL.deskBringAllToFront(), action: () => mine.forEach((w) => desk.windows.focus(w.id)) },
      { separator: true },
      ...mine.map((w) => ({
        label: w.title ?? activeSpec!.title($LL),
        checked: w.id === id,
        action: () => desk.windows.focus(w.id),
      })),
      { separator: true },
      { label: $LL.deskClose(), shortcut: '⌘W', action: () => desk.windows.close(id) },
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

  /// The bar's menus left to right: the app, the app's own, Window, Help.
  const titles = $derived.by(() => {
    const out: { owner: string; label: string; items: () => MenuItem[] }[] = []
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

  const unread = $derived(desk.notifications?.unread ?? 0)
  const dnd = $derived(desk.notifications?.dnd ?? false)
</script>

<nav
  class="lk-menubar absolute inset-x-0 top-0 z-[100000]"
  aria-label={$LL.deskMenubar()}
  onpointerdown={(e) => {
    // Its buttons toggle what they open; the desk's own dismissal would
    // close it first and the click open it again.
    e.stopPropagation()
    desk.menu = null
  }}
>
  <!-- The server this desk is on leads the bar, its dot saying whether the
       desk hears from it. -->
  <button
    class="lk-menubar__item lk-menubar__lead"
    class:lk-menubar__item--open={desk.menu?.owner === 'server'}
    aria-haspopup="menu"
    title={desk.storage?.remote ? (desk.live ? $LL.deskLive() : $LL.deskOffline()) : undefined}
    onclick={(e) => menuUnder(e, 'server', serverItems())}
    onpointerenter={(e) => hover(e, 'server', serverItems)}
  >
    <span
      class="h-[7px] w-[7px] shrink-0 rounded-full"
      style:background={online ? 'var(--hue-green)' : 'var(--hue-amber)'}
      style:box-shadow="0 0 0 3px color-mix(in srgb, {online ? 'var(--hue-green)' : 'var(--hue-amber)'} 22%, transparent)"
    ></span>
    <span class="max-w-40 truncate font-bold tracking-[-0.01em]">{serverLabel}</span>
  </button>
  {#each titles as t (t.owner)}
    <button
      class="lk-menubar__item max-w-48 truncate"
      class:lk-menubar__app={t.owner === 'app'}
      class:hidden={t.owner !== 'app' && desk.windows.compact}
      class:lk-menubar__item--open={desk.menu?.owner === t.owner}
      aria-haspopup="menu"
      onclick={(e) => menuUnder(e, t.owner, t.items())}
      onpointerenter={(e) => hover(e, t.owner, t.items)}
    >
      {#if t.owner === 'app' && appIcon}
        <span class="inline-flex" aria-hidden="true"><AppIcon glyph={appIcon.glyph} tone={appIcon.tone} size={17} /></span>
      {/if}
      {t.label}
    </button>
  {/each}
  <div class="lk-menubar__spacer"></div>

  {#if reading && !desk.windows.compact}
    <button
      class="lk-menubar__item"
      class:lk-menubar__item--open={desk.menu?.owner === 'cpu'}
      aria-haspopup="menu"
      aria-label="CPU"
      title="CPU"
      onclick={(e) => menuUnder(e, 'cpu', cpuItems(), true)}
      onpointerenter={(e) => hover(e, 'cpu', cpuItems, true)}
    >
      <Icon name="memory" size={15} color="var(--text-secondary)" />
      <span class="lk-num min-w-[34px] text-right">{fmtPercent(reading.cpu_usage)}</span>
    </button>
  {/if}
  <button
    class="lk-menubar__item"
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
    class="lk-menubar__item"
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
    class="lk-menubar__item"
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
  <button
    class="lk-menubar__item lk-menubar__clock font-medium"
    class:lk-menubar__item--open={desk.panel === 'calendar'}
    aria-expanded={desk.panel === 'calendar'}
    onclick={(e) => {
      e.stopPropagation()
      desk.togglePanel('calendar')
    }}
  >
    {clock}
  </button>
</nav>

<style>
  .lk-menubar__item:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
