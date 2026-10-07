<script lang="ts">
  import { Spinner } from '@serverbox/webui'
  import { onDestroy, onMount } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { theme } from '../lib/theme.svelte'
  import type { ServerEntry } from '../lib/servers.svelte'
  import { app } from './apps'
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
  import WindowLayer from './window/WindowLayer.svelte'

  interface Props {
    entry: ServerEntry
    /// Locks this desk: the lock screen, where another server can be chosen.
    onlock: () => void
    /// Switches to another server's desk.
    onswitch: (serverId: string) => void
  }

  const { entry, onlock, onswitch }: Props = $props()
  // svelte-ignore state_referenced_locally
  const desk = new Desk(entry)
  provideDesk(desk)

  let root = $state<HTMLDivElement | null>(null)

  /// The menubar's height and the gap under it, above the windows; the
  /// dock's below (its icons, padding and distance from the edge).
  const TOP = 37
  const BOTTOM = 74

  function measure() {
    if (!root) return
    desk.windows.resizeArea({ width: root.clientWidth, height: root.clientHeight, top: TOP, bottom: BOTTOM })
  }

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

<div
  bind:this={root}
  class="lk desk-root fixed inset-0 overflow-hidden bg-(--surface-desktop)"
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
  {:else if desk.panel}
    <!-- Under the menubar's right end, as macOS opens them. -->
    <div class="desk-panel" role="dialog" tabindex="-1" onpointerdown={(e) => e.stopPropagation()}>
      {#if desk.panel === 'control'}
        <ControlCenter {onlock} />
      {:else if desk.panel === 'notifications'}
        <NotificationCenter />
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
