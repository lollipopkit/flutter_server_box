<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
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

  const chrome = $derived(desk.activeChrome)
  const appName = $derived(chrome?.appName ?? activeSpec?.title($LL) ?? '')
  const appIcon = $derived(chrome?.icon ?? (activeSpec ? { glyph: activeSpec.glyph, tone: activeSpec.tone } : null))

  /// Opens [items] under the bar title [e] came from, as [owner].
  function menuUnder(e: MouseEvent, owner: string, items: MenuItem[]) {
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
    e.stopPropagation()
    desk.panel = null
    desk.menu = desk.menu?.owner === owner && e.type === 'click' ? null : { x: r.left, y: r.bottom + 3, items, owner }
  }

  /// With one of the bar's menus open, pointing at another title opens it.
  function hover(e: MouseEvent, owner: string, items: () => MenuItem[]) {
    if (desk.menu?.owner && desk.menu.owner !== owner) menuUnder(e, owner, items())
  }

  function serverItems(): MenuItem[] {
    return [
      { label: $LL.deskAboutServer(), icon: 'info', action: () => desk.open('status') },
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
    ]
  }

  /// The app menu: the app as a whole.
  function appItems(): MenuItem[] {
    if (!activeSpec) return []
    const spec = activeSpec
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
    items.push({ label: `${$LL.deskQuit()} ${appName}`, icon: 'close', action: () => desk.windows.closeApp(spec.id) })
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

  /// The bar's menus left to right: the server, the app, the app's own, Window.
  const titles = $derived.by(() => {
    const out: { owner: string; label: string; items: () => MenuItem[] }[] = []
    if (!activeSpec) return out
    out.push({ owner: 'app', label: appName, items: appItems })
    for (const [i, menu] of (chrome?.menus ?? []).entries()) {
      out.push({ owner: `menu:${i}`, label: menu.label, items: () => menu.items })
    }
    out.push({ owner: 'window', label: $LL.deskWindowMenu(), items: windowItems })
    return out
  })

  const unread = $derived(desk.notifications?.unread ?? 0)
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
  <button
    class="lk-menubar__item lk-menubar__brand"
    class:lk-menubar__item--open={desk.menu?.owner === 'server'}
    aria-haspopup="menu"
    onclick={(e) => menuUnder(e, 'server', serverItems())}
    onpointerenter={(e) => hover(e, 'server', serverItems)}>lollipopkit</button
  >
  {#if appIcon}
    <span class="inline-flex" aria-hidden="true"><AppIcon glyph={appIcon.glyph} tone={appIcon.tone} size={17} /></span>
  {/if}
  {#each titles as t (t.owner)}
    <button
      class="lk-menubar__item max-w-48 truncate"
      class:lk-menubar__app={t.owner === 'app'}
      class:hidden={t.owner !== 'app' && desk.windows.compact}
      class:lk-menubar__item--open={desk.menu?.owner === t.owner}
      aria-haspopup="menu"
      onclick={(e) => menuUnder(e, t.owner, t.items())}
      onpointerenter={(e) => hover(e, t.owner, t.items)}>{t.label}</button
    >
  {/each}
  <div class="lk-menubar__spacer"></div>

  <button class="lk-menubar__item" title={serverLabel} onclick={(e) => menuUnder(e, 'server', serverItems())}>
    {#if desk.storage?.remote}
      <span
        class="h-[7px] w-[7px] rounded-full"
        style:background={desk.live ? 'var(--hue-green)' : 'var(--hue-amber)'}
        style:box-shadow="0 0 0 3px color-mix(in srgb, {desk.live ? 'var(--hue-green)' : 'var(--hue-amber)'} 25%, transparent)"
        title={desk.live ? $LL.deskLive() : $LL.deskOffline()}
      ></span>
    {/if}
    <span class="max-w-40 truncate">{serverLabel}</span>
  </button>
  <button
    class="lk-menubar__item"
    class:lk-menubar__item--open={desk.spotlight}
    aria-label={$LL.deskSearch()}
    title="{$LL.deskSearch()} (⌘K)"
    onclick={(e) => {
      e.stopPropagation()
      desk.panel = null
      desk.spotlight = !desk.spotlight
    }}
  >
    <Icon name="search" size={17} />
  </button>
  <button
    class="lk-menubar__item"
    class:lk-menubar__item--open={desk.panel === 'control'}
    aria-label={$LL.deskControlCenter()}
    aria-expanded={desk.panel === 'control'}
    onclick={(e) => {
      e.stopPropagation()
      desk.togglePanel('control')
    }}
  >
    <Icon name="toggle_on" size={17} fill={desk.panel === 'control'} />
  </button>
  {#if desk.storage?.remote}
    <button
      class="lk-menubar__item"
      class:lk-menubar__item--open={desk.panel === 'notifications'}
      aria-label={$LL.deskNotifications()}
      aria-expanded={desk.panel === 'notifications'}
      onclick={(e) => {
        e.stopPropagation()
        desk.togglePanel('notifications')
      }}
    >
      <Icon name={desk.notifications?.dnd ? 'notifications_off' : 'notifications'} size={17} fill={desk.panel === 'notifications'} />
      {#if unread > 0}<span class="lk-badge lk-badge--count" style:height="16px" style:min-width="16px">{unread > 99 ? '99+' : unread}</span>{/if}
    </button>
  {/if}
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
</nav>
