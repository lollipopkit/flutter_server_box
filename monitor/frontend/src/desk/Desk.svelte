<script lang="ts">
  import { FolderOpen, Image, LayoutGrid, Settings, SquareTerminal } from '@lucide/svelte'
  import { Spinner } from '@serverbox/webui'
  import { onDestroy, onMount } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
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

  /// The menubar's height and gap above the windows, the dock's below.
  const TOP = 48
  const BOTTOM = 84

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

  const accent = $derived(desk.prefs?.value.accent ?? '#2563eb')

  function onkeydown(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault()
      desk.panel = null
      desk.spotlight = !desk.spotlight
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
      items.push({ label: $LL.deskNewTerminal(), icon: SquareTerminal, action: () => desk.open('terminal', { newWindow: true }) })
    }
    if (app('files')?.available(desk.caps)) {
      items.push({ label: $LL.files(), icon: FolderOpen, action: () => desk.open('files') })
    }
    items.push(
      { separator: true },
      { label: $LL.deskChangeWallpaper(), icon: Image, action: () => desk.open('settings', { appState: { section: 'appearance' } }) },
      {
        label: $LL.deskCleanUpIcons(),
        icon: LayoutGrid,
        action: () =>
          desk.prefs?.update({ icons: desk.prefs.value.icons.map((i) => ({ ...i, col: null, row: null })) }),
      },
      { separator: true },
      { label: $LL.deskAppSettings(), icon: Settings, action: () => desk.open('settings') },
    )
    desk.showMenu(e, items)
  }
</script>

<svelte:window {onkeydown} />

<div
  bind:this={root}
  class="desk-root fixed inset-0 overflow-hidden font-body text-fg"
  style:--desk-accent={accent}
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
    <div
      class="desk-glass desk-pop absolute right-2 top-[calc(var(--menubar-h)+0.75rem)] z-[100001] w-[min(22rem,calc(100%-1rem))] rounded-(--radius-panel)"
      role="dialog"
      tabindex="-1"
      onpointerdown={(e) => e.stopPropagation()}
    >
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
