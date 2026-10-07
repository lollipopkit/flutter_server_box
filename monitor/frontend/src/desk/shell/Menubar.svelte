<script lang="ts">
  import { Bell, Box, LockKeyhole, LogOut, Search, Settings, SlidersHorizontal } from '@lucide/svelte'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName, servers } from '../../lib/servers.svelte'
  import { app } from '../apps'
  import { useDesk, type MenuItem } from '../deskState.svelte'

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
    new Intl.DateTimeFormat($locale, { weekday: 'short', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(now),
  )

  function menuUnder(e: MouseEvent, items: MenuItem[]) {
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
    e.stopPropagation()
    desk.panel = null
    desk.menu = { x: r.left, y: r.bottom + 6, items }
  }

  function serverMenu(e: MouseEvent) {
    menuUnder(e, [
      { label: $LL.deskAboutServer(), action: () => desk.open('status') },
      { label: $LL.deskAppSettings(), icon: Settings, action: () => desk.open('settings') },
      { separator: true },
      { label: $LL.deskLock(), icon: LockKeyhole, action: onlock },
      {
        label: $LL.logout(),
        icon: LogOut,
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
  class="desk-bar absolute inset-x-3 top-2 z-[100000] flex h-(--menubar-h) select-none items-center gap-0.5 rounded-(--radius-bar) px-1.5 text-[0.76rem] tracking-[0.2px]"
  aria-label={$LL.deskMenubar()}
  onpointerdown={(e) => {
    // Its buttons toggle what they open; the desk's own dismissal would
    // close it first and the click open it again.
    e.stopPropagation()
    desk.menu = null
  }}
>
  <button class="desk-hover flex h-6 items-center gap-1.5 px-2 font-semibold" onclick={serverMenu} title={serverLabel}>
    <Box class="h-3.5 w-3.5" strokeWidth={2.2} />
    <span class="max-w-40 truncate">{serverLabel}</span>
  </button>
  {#if activeSpec}
    <button class="desk-hover hidden h-6 items-center px-2 font-medium sm:flex" onclick={appMenu}>
      {activeSpec.title($LL)}
    </button>
  {/if}

  <div class="flex-1"></div>

  {#if desk.storage?.remote}
    <span
      class="mx-1 h-1.5 w-1.5 rounded-full {desk.live ? 'bg-success' : 'bg-warning'}"
      title={desk.live ? $LL.deskLive() : $LL.deskOffline()}
    ></span>
  {/if}
  <button
    class="desk-hover grid h-6 w-7 place-items-center"
    aria-label={$LL.deskSearch()}
    title="{$LL.deskSearch()} (⌘K)"
    onclick={(e) => {
      e.stopPropagation()
      desk.panel = null
      desk.spotlight = !desk.spotlight
    }}
  >
    <Search class="h-3.5 w-3.5" />
  </button>
  <button
    class="desk-hover grid h-6 w-7 place-items-center"
    aria-label={$LL.deskControlCenter()}
    aria-expanded={desk.panel === 'control'}
    onclick={(e) => {
      e.stopPropagation()
      desk.togglePanel('control')
    }}
  >
    <SlidersHorizontal class="h-3.5 w-3.5" />
  </button>
  {#if desk.storage?.remote}
    <button
      class="desk-hover relative grid h-6 w-7 place-items-center"
      aria-label={$LL.deskNotifications()}
      aria-expanded={desk.panel === 'notifications'}
      onclick={(e) => {
        e.stopPropagation()
        desk.togglePanel('notifications')
      }}
    >
      <Bell class="h-3.5 w-3.5" />
      {#if unread > 0}
        <span
          class="absolute right-0.5 top-0.5 min-w-3.5 rounded-full bg-danger px-1 text-center text-[0.6rem] font-bold leading-3.5 text-white"
        >
          {unread > 99 ? '99+' : unread}
        </span>
      {/if}
    </button>
  {/if}
  <button
    class="desk-hover h-6 whitespace-nowrap px-2 font-medium tabular-nums"
    aria-expanded={desk.panel === 'calendar'}
    onclick={(e) => {
      e.stopPropagation()
      desk.togglePanel('calendar')
    }}
  >
    {clock}
  </button>
</nav>
