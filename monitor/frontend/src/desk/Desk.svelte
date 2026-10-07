<script lang="ts">
  import Spinner from './lk/Spinner.svelte'
  import { onDestroy, onMount, untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { theme } from '../lib/theme.svelte'
  import type { ServerEntry } from '../lib/servers.svelte'
  import { app } from './registry.svelte'
  import { COMPACT_WIDTH } from './geometry'
  import { shellPrefs } from './shellPrefs.svelte'
  import { systemPrefs } from './sys/systemPrefs.svelte'
  import { menuItemFor } from './shortcuts'
  import { Desk, provideDesk, type MenuItem } from './deskState.svelte'
  import Banner from './shell/Banner.svelte'
  import CalendarPanel from './shell/CalendarPanel.svelte'
  import ContextMenu from './shell/ContextMenu.svelte'
  import ControlCenter from './shell/ControlCenter.svelte'
  import DeskIcons from './shell/DeskIcons.svelte'
  import Dock from './shell/Dock.svelte'
  import Launchpad from './shell/Launchpad.svelte'
  import Menubar from './shell/Menubar.svelte'
  import NotificationCenter from './shell/NotificationCenter.svelte'
  import Spotlight from './shell/Spotlight.svelte'
  import Wallpaper from './shell/Wallpaper.svelte'
  import { saveWallpaper } from './lock/wallpapers'
  import WindowLayer from './window/WindowLayer.svelte'

  interface Props {
    entry: ServerEntry
    /// The lock screen is over this desk: its apps are hidden.
    locked?: boolean
    /// Locks this desk: the lock screen, where another server can be chosen.
    onlock: () => void
    /// Switches to another server's desk.
    onswitch: (serverId: string) => void
  }

  const { entry, locked = false, onlock, onswitch }: Props = $props()
  // svelte-ignore state_referenced_locally
  const desk = new Desk(entry)
  provideDesk(desk)

  $effect.pre(() => {
    desk.locked = locked
  })

  /// The login screen shows each account's wallpaper before it signs in, from
  /// a copy kept in this browser (`lock/wallpapers.ts`).
  $effect(() => {
    const prefs = desk.prefs
    if (!prefs?.loaded || entry.username === null) return
    const fit = prefs.value.wallpaper_fit
    const preset = prefs.preset
    const url = prefs.wallpaperUrl
    const { id, username } = entry
    if (preset) {
      void saveWallpaper(id, username, { preset, fit })
    } else if (url) {
      void fetch(url)
        .then((r) => r.blob())
        .then((image) => saveWallpaper(id, username, { image, fit }))
        .catch(() => {})
    }
  })

  let root = $state<HTMLDivElement | null>(null)

  /// The menubar's height and the gap under it, above the windows; the gap
  /// a window keeps from the bottom, besides the dock's room.
  const TOP = 37
  const EDGE = 7

  let size = $state({ width: 0, height: 0 })
  function measure() {
    if (root) size = { width: root.clientWidth, height: root.clientHeight }
  }
  $effect(() => {
    if (!size.width) return
    const dock = shellPrefs.dockReserve(size.width < COMPACT_WIDTH)
    const area = { ...size, top: TOP, bottom: EDGE + dock.bottom, left: dock.left, right: dock.right }
    // Only the size and the dock lead here; the windows it moves do not.
    untrack(() => desk.windows.resizeArea(area))
  })

  onMount(() => {
    measure()
    const observer = new ResizeObserver(measure)
    if (root) observer.observe(root)
    void desk.start()
    return () => observer.disconnect()
  })

  onDestroy(() => {
    void desk.stop()
  })

  // Every change worth keeping is saved after a pause.
  $effect(() => {
    void desk.windows.changes
    desk.session?.schedule()
  })

  function onkeydown(e: KeyboardEvent) {
    if (e.defaultPrevented) return
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault()
      desk.panel = null
      desk.spotlight = !desk.spotlight
    } else if ((e.metaKey || e.ctrlKey) && e.key === ',') {
      e.preventDefault()
      desk.open('settings')
    } else if (e.altKey && e.code === 'Backquote') {
      // Alt+` brings the window at the back to the front, round and round.
      e.preventDefault()
      desk.windows.cycle()
    } else if (e.key === 'Escape' && (desk.spotlight || desk.panel || desk.menu)) {
      desk.spotlight = false
      desk.panel = null
      desk.menu = null
    } else if (!locked) {
      // The front app's menus, by their shortcuts.
      const item = menuItemFor(e, desk.activeChrome?.menus ?? [])
      if (item) {
        e.preventDefault()
        item.action()
      }
    }
  }

  function dismiss() {
    desk.menu = null
    desk.panel = null
    desk.spotlight = false
  }

  function deskMenu(e: MouseEvent) {
    const items: MenuItem[] = []
    if (app('terminal')?.available(desk.caps)) {
      items.push({ label: $LL.deskNewTerminal(), icon: 'terminal', action: () => desk.open('terminal', { newWindow: true }) })
    }
    if (app('files')?.available(desk.caps)) {
      items.push({ label: $LL.files(), icon: 'folder', action: () => desk.open('files') })
    }
    items.push(
      { separator: true },
      { label: $LL.deskUseDark(), checked: theme.dark, action: () => theme.set(theme.dark ? 'light' : 'dark') },
      {
        label: $LL.deskCleanUpIcons(),
        icon: 'grid_view',
        action: () =>
          desk.prefs?.update({ icons: desk.prefs.value.icons.map((i) => ({ ...i, col: null, row: null })) }),
      },
      { separator: true },
      { label: $LL.deskChangeWallpaper(), icon: 'wallpaper', action: () => desk.open('settings', { appState: { section: 'appearance' } }) },
    )
    desk.showMenu(e, items)
  }
</script>

<svelte:window {onkeydown} />
<svelte:document onvisibilitychange={() => (desk.hidden = document.visibilityState === 'hidden')} />

<div
  bind:this={root}
  class="lk desk-root fixed inset-0 overflow-hidden bg-(--surface-desktop)"
  data-reduce-motion={systemPrefs.value.reduceMotion || undefined}
  role="application"
  aria-label={$LL.deskTitle()}
  onpointerdown={dismiss}
  oncontextmenu={(e) => {
    // Only the bare desk: a window, an icon or a bar has its own menu or none.
    if ((e.target as HTMLElement).closest('[data-desk-background]')) deskMenu(e)
  }}
>
  <div class="absolute inset-0" data-desk-background>
    <Wallpaper
      preset={desk.prefs?.preset ?? 'bloom'}
      url={desk.prefs?.wallpaperUrl ?? null}
      fit={desk.prefs?.value.wallpaper_fit ?? 'cover'}
    />
  </div>
  {#if desk.ready && !desk.windows.compact}
    <DeskIcons />
  {/if}
  {#if desk.ready}
    <WindowLayer />
  {:else}
    <div class="absolute inset-0 grid place-items-center"><Spinner size="lg" /></div>
  {/if}

  <Menubar {onlock} />
  <Dock />

  {#if desk.panel === 'launchpad'}
    <Launchpad />
  {:else if desk.panel === 'notifications'}
    <!-- Its own glass panel, under the menubar's right end. -->
    <div class="desk-panel-place" role="dialog" tabindex="-1" aria-label={$LL.deskNotifications()} onpointerdown={(e) => e.stopPropagation()}>
      <NotificationCenter />
    </div>
  {:else if desk.panel}
    <!-- Under the menubar's right end, as macOS opens them. -->
    <div class="desk-panel" role="dialog" tabindex="-1" onpointerdown={(e) => e.stopPropagation()}>
      {#if desk.panel === 'control'}
        <ControlCenter {onlock} />
      {:else if desk.panel === 'calendar'}
        <CalendarPanel />
      {/if}
    </div>
  {/if}

  {#if desk.spotlight}
    <Spotlight {onswitch} />
  {/if}
  <Banner />
  <ContextMenu />
</div>

<style>
  .desk-panel-place {
    position: absolute;
    top: 37px;
    right: 9px;
    z-index: 100001;
    max-width: calc(100% - 18px);
    transform-origin: top right;
    animation: lk-menu-in var(--dur-base) var(--ease-spring);
  }
  .desk-panel {
    position: absolute;
    top: 36px;
    right: 9px;
    z-index: 100001;
    width: min(330px, calc(100% - 18px));
    max-height: calc(100% - 36px - var(--dock-icon) - 40px);
    overflow-y: auto;
    padding: var(--space-11);
    border-radius: var(--radius-panel);
    background: var(--glass-panel);
    backdrop-filter: var(--blur-menu);
    -webkit-backdrop-filter: var(--blur-menu);
    box-shadow:
      var(--shadow-menu),
      inset 0 0 0 0.5px var(--border-glass);
    transform-origin: top right;
    animation: lk-menu-in var(--dur-slow) var(--ease-spring);
  }
</style>
