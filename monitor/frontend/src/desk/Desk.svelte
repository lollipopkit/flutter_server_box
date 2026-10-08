<script lang="ts">
  import Spinner from '@lollipopkit/desk-ui/Spinner.svelte'
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
  import { themeDark, themeWallpaper } from './themeStyle'
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
    const url = prefs.value.wallpaper === 'custom' ? prefs.wallpaperUrl : null
    const drawn = wallpaperTheme
    const { id, username } = entry
    if (drawn) {
      const { ground, image } = drawn
      // An image theme is kept once its image is here.
      if (activeTheme?.background.style === 'image' && !image) return
      const keep = (blob: Blob | null) =>
        saveWallpaper(id, username, {
          theme: { ground, image: blob, opacity: image?.opacity ?? 1, blur: image?.blur ?? 0, tile: image?.tile ?? 0 },
          fit,
        })
      if (!image) void keep(null)
      else
        void fetch(image.url)
          .then((r) => r.blob())
          .then(keep)
          .catch(() => {})
    } else if (preset) {
      void saveWallpaper(id, username, { preset, fit })
    } else if (url) {
      void fetch(url)
        .then((r) => r.blob())
        .then((image) => saveWallpaper(id, username, { image, fit }))
        .catch(() => {})
    }
  })

  // ---- the installed theme the desk is drawn with ------------------------

  const activeTheme = $derived(desk.themes?.active?.theme ?? null)
  /// A theme that supports one brightness holds the desk at it.
  $effect(() => {
    const modes = activeTheme?.modes
    theme.lock(modes?.length === 1 ? modes[0] : null)
  })
  onDestroy(() => theme.lock(null))
  $effect(() => {
    // The background follows the selection, wherever it was made.
    void desk.prefs?.value.theme
    desk.themes?.preferencesChanged()
  })
  const themeStyle = $derived.by(() => {
    const vars = desk.themes?.vars(theme.dark)
    if (!vars) return undefined
    return Object.entries(vars)
      .map(([k, v]) => `${k}: ${v}`)
      .join('; ')
  })
  $effect(() => {
    // Effects run once the DOM has the new style: what reads colours from the
    // document (terminals) reads them again.
    void themeStyle
    untrack(() => theme.touch())
  })
  const wallpaperTheme = $derived(
    activeTheme && desk.prefs?.value.wallpaper === 'theme'
      ? themeWallpaper(activeTheme, themeDark(activeTheme, theme.dark), desk.themes?.backgroundUrl ?? null)
      : null,
  )

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
  style={themeStyle}
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
      preset={desk.prefs ? desk.prefs.preset : 'bloom'}
      url={desk.prefs?.value.wallpaper === 'custom' ? desk.prefs.wallpaperUrl : null}
      fit={desk.prefs?.value.wallpaper_fit ?? 'cover'}
      theme={wallpaperTheme}
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
    <!-- Under the menubar's right end, as macOS opens them. Keyed, so going
         from one panel to another opens the next one as a panel opens. -->
    {#key desk.panel}
      <div class="desk-panel" role="dialog" tabindex="-1" onpointerdown={(e) => e.stopPropagation()}>
        {#if desk.panel === 'control'}
          <ControlCenter {onlock} />
        {:else if desk.panel === 'calendar'}
          <CalendarPanel />
        {/if}
      </div>
    {/key}
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
  }
  /* On the glass itself, not on this wrapper: an ancestor whose opacity is
     below 1 is where a backdrop-filter stops looking, so the panel would be
     clear until the fade ended and only then blur the desk. */
  .desk-panel-place > :global(*) {
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
