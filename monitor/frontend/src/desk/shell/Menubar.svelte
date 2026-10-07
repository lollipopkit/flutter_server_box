<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName, servers } from '../../lib/servers.svelte'
  import { app } from '../apps'
  import { useDesk, type MenuItem } from '../deskState.svelte'
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

  function menuUnder(e: MouseEvent, items: MenuItem[]) {
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
    e.stopPropagation()
    desk.panel = null
    desk.menu = { x: r.left, y: r.bottom + 3, items }
  }

  function serverMenu(e: MouseEvent) {
    menuUnder(e, [
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
    ])
  }

  function appMenu(e: MouseEvent) {
    if (!active || !activeSpec) return
    const id = active.id
    const items: MenuItem[] = []
    if (activeSpec.instances > 1) {
      items.push({
        label: $LL.deskNewWindow(),
        disabled: desk.windows.of(activeSpec.id).length >= activeSpec.instances,
        action: () => desk.open(activeSpec.id, { newWindow: true }),
      })
    }
    items.push(
      { label: $LL.deskMinimize(), action: () => desk.windows.minimize(id) },
      { label: $LL.deskZoom(), action: () => desk.windows.toggleMaximize(id) },
      { separator: true },
      { label: $LL.deskClose(), action: () => desk.windows.close(id) },
    )
    if (desk.windows.of(activeSpec.id).length > 1) {
      items.push({ label: $LL.deskCloseAll(), action: () => desk.windows.closeApp(activeSpec.id) })
    }
    menuUnder(e, items)
  }

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
  <button class="lk-menubar__item lk-menubar__brand" onclick={serverMenu}>lollipopkit</button>
  {#if activeSpec}
    <button class="lk-menubar__item lk-menubar__app" onclick={appMenu}>{activeSpec.title($LL)}</button>
  {/if}
  <div class="lk-menubar__spacer"></div>

  <button class="lk-menubar__item" title={serverLabel} onclick={serverMenu}>
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
