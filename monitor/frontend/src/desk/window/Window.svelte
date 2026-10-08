<script lang="ts">
  import Spinner from '../lk/Spinner.svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { app } from '../registry.svelte'
  import { onDestroy, onMount } from 'svelte'
  import { viewEnter, viewIn } from '../lk/motion'
  import { provideWindow, useDesk } from '../deskState.svelte'
  import type { LifecycleState } from '../sys/window.svelte'
  import IconButton from '../lk/IconButton.svelte'
  import WindowControls from '../lk/WindowControls.svelte'
  import { WindowChrome } from './chrome.svelte'
  import PaneHost from './PaneHost.svelte'
  import { sideAt } from '../panes'
  import type { PaneDrop } from '../deskState.svelte'
  import { shellPrefs } from '../shellPrefs.svelte'
  import { systemPrefs, TEXT_SCALE } from '../sys/systemPrefs.svelte'
  import { type Edge, type Rect, type SnapZone, resize, snapZoneAt, unsnapUnder, usable } from '../geometry'
  import type { DeskWindow } from '../windows.svelte'

  /// After the first render: the title and the tabs that replace each other
  /// (one tab left, a second opened; an app's own heading as well, keyed by
  /// which heading it is) fade in as the design system's views do; the
  /// window's first title does not.
  let shown = $state(false)
  onMount(() => (shown = true))

  const SUSPEND_AFTER_MS = 5000

  interface Props {
    win: DeskWindow
    /// Where a drag would snap if let go now; the layer draws it.
    onsnappreview: (zone: SnapZone | null) => void
  }

  const { win, onsnappreview }: Props = $props()
  const desk = useDesk()
  const chrome = new WindowChrome()
  /// A window keeps its id for life (the layer is keyed by it).
  // svelte-ignore state_referenced_locally
  const id = win.id
  provideWindow(desk, id, chrome, () => lifecycle)
  desk.chromes.set(id, chrome)
  chrome.deliver(...desk.takeIntents(id))
  onDestroy(() => desk.chromes.delete(id))

  /// Hidden while background running is off: the app's content goes after a
  /// grace period (a quick minimise and restore keeps it) and comes back
  /// with the window, restoring itself from its `appState`.
  let suspended = $state(false)
  const hidden = $derived(desk.isHidden(win.id))
  const mayRun = $derived(desk.mayRunHidden(win.appId) || chrome.keepAlive.length > 0)
  $effect(() => {
    if (!hidden || mayRun) {
      suspended = false
      return
    }
    const t = setTimeout(() => {
      suspended = true
      chrome.reset()
    }, SUSPEND_AFTER_MS)
    return () => clearTimeout(t)
  })
  const lifecycle = $derived<LifecycleState>(
    suspended ? 'suspended' : hidden ? 'background' : desk.windows.active?.id === win.id ? 'active' : 'visible',
  )
  $effect.pre(() => {
    chrome.lifecycle = lifecycle
  })

  const spec = $derived(app(win.appId))
  const title = $derived(win.title ?? (spec ? spec.title($LL) : win.appId))
  const active = $derived(desk.windows.active?.id === win.id)
  const compact = $derived(desk.windows.compact)
  const toolbar = $derived(chrome.toolbar)
  const sidebar = $derived(chrome.sidebar)
  const footer = $derived(chrome.footer)
  let footerHeight = $state(0)
  const flush = $derived(!!toolbar?.flush)

  /// The content (or a list inside it) has scrolled away from the top: the
  /// bar blurs what is under it, unless it is blurred always or flush.
  let scrolled = $state(false)
  const blurred = $derived(!flush && (shellPrefs.titlebar === 'always' || scrolled))
  function onContentScroll(e: Event) {
    const content = e.currentTarget as HTMLElement
    const target = e.target as HTMLElement
    // Pages sliding past each other (sys.PageStack): blurred over both.
    scrolled = !!(content.dataset.pageMoving || target.dataset?.pageMoving) || content.scrollTop > 2 || (target !== content && target.scrollTop > 2)
  }

  /// The rect while a drag or resize is under way; the store gets it on release.
  let live = $state<Rect | null>(null)
  /// Geometry animates for a maximise or a snap, never under the pointer.
  let animate = $state(false)

  const rect = $derived.by(() => {
    if (compact) return usable(desk.windows.area)
    return live ?? win.rect
  })
  /// Too narrow for the sidebar beside the content: it folds behind a
  /// title-bar button and opens over the content.
  const folded = $derived(compact || rect.width < 640)
  const controlLabels = $derived({ close: $LL.deskClose(), minimize: $LL.deskMinimize(), zoom: $LL.deskZoom(), restore: $LL.deskUnzoom() })

  function animateOnce() {
    animate = true
    setTimeout(() => (animate = false), 260)
  }

  function toggleMaximize() {
    if (compact) return
    animateOnce()
    desk.windows.toggleMaximize(win.id)
  }

  // ---- drag -------------------------------------------------------------

  let drag: { pointerX: number; pointerY: number; start: Rect; moved: boolean; zone: SnapZone | null } | null = null

  function onTitlePointerDown(e: PointerEvent) {
    desk.windows.focus(win.id)
    if (compact || e.button !== 0) return
    if ((e.target as HTMLElement).closest('button, input, select, a, [role=tab], [data-no-drag]')) return
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
    drag = { pointerX: e.clientX, pointerY: e.clientY, start: { ...win.rect }, moved: false, zone: null }
  }

  function onTitlePointerMove(e: PointerEvent) {
    if (!drag) return
    const dx = e.clientX - drag.pointerX
    const dy = e.clientY - drag.pointerY
    if (!drag.moved) {
      if (Math.abs(dx) + Math.abs(dy) < 4) return
      drag.moved = true
      // Taken from a snap: back to its own size, under the pointer.
      if (win.snap) {
        const restore = win.restore ?? win.rect
        drag.start = unsnapUnder(e.clientX, e.clientY, win.rect, restore)
        drag.pointerX = e.clientX
        drag.pointerY = e.clientY
        desk.windows.unsnap(win.id, drag.start)
        live = { ...drag.start }
        return
      }
    }
    live = {
      ...drag.start,
      x: drag.start.x + dx,
      y: Math.max(desk.windows.area.top, drag.start.y + dy),
    }
    // Over another window of this app: a merge, not a snap.
    const merge = spec?.panes ? mergeAt(e.clientX, e.clientY) : null
    if (!samePaneDrop(merge, desk.paneDrop)) desk.paneDrop = merge
    merging = merge !== null
    if (merge) {
      if (drag.zone) {
        drag.zone = null
        onsnappreview(null)
      }
      return
    }
    const zone = snapZoneAt(e.clientX, e.clientY, desk.windows.area)
    if (zone !== drag.zone) {
      drag.zone = zone
      onsnappreview(zone)
    }
  }

  function onTitlePointerUp() {
    if (!drag) return
    const { moved, zone } = drag
    drag = null
    onsnappreview(null)
    const merge = desk.paneDrop
    desk.paneDrop = null
    merging = false
    if (moved && merge) {
      live = null
      desk.mergeWindow(win.id, merge)
      return
    }
    if (moved && zone) {
      animateOnce()
      desk.windows.snap(win.id, zone)
    } else if (moved && live) {
      desk.windows.place(win.id, live)
    }
    live = null
  }

  /// The window of this app under the pointer, other than this one, and
  /// where in it this one would go: over its bar or tab strip a tab, over a
  /// pane beside it, on the side nearest the pointer.
  function mergeAt(x: number, y: number): PaneDrop | null {
    for (const el of document.elementsFromPoint(x, y)) {
      const target = (el as HTMLElement).closest<HTMLElement>('.desk-window')
      if (!target || target.dataset.windowId === win.id) continue
      const windowId = target.dataset.windowId
      if (!windowId || target.dataset.appId !== win.appId || target.dataset.minimized === 'true') return null
      const band = [target.querySelector('.lk-window__bar'), target.querySelector('[data-pane-strip]')]
        .map((b) => b?.getBoundingClientRect().bottom ?? 0)
        .reduce((a, b) => Math.max(a, b), 0)
      if (y < band) return { windowId, kind: 'tab' }
      const pane = (el as HTMLElement).closest<HTMLElement>('[data-pane-id]')
      const paneId = pane?.dataset.paneId
      if (!pane || !paneId) return null
      const r = pane.getBoundingClientRect()
      return { windowId, kind: 'split', paneId, side: sideAt({ x: r.left, y: r.top, w: r.width, h: r.height }, x, y) }
    }
    return null
  }

  function samePaneDrop(a: PaneDrop | null, b: PaneDrop | null): boolean {
    if (a === null || b === null) return a === b
    if (a.windowId !== b.windowId || a.kind !== b.kind) return false
    return a.kind === 'tab' || (b.kind === 'split' && a.paneId === b.paneId && a.side === b.side)
  }

  /// This window is the one a dragged window would merge into as a tab.
  const tabDrop = $derived(desk.paneDrop?.windowId === win.id && desk.paneDrop.kind === 'tab')
  /// This window is being dragged onto another to merge.
  let merging = $state(false)

  // ---- resize -----------------------------------------------------------

  let sizing: { edge: Edge; pointerX: number; pointerY: number; start: Rect } | null = null
  const EDGES: Edge[] = ['n', 's', 'e', 'w', 'ne', 'nw', 'se', 'sw']

  function onEdgePointerDown(e: PointerEvent, edge: Edge) {
    if (compact || e.button !== 0) return
    e.stopPropagation()
    desk.windows.focus(win.id)
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
    if (win.snap) desk.windows.unsnap(win.id, { ...win.rect })
    sizing = { edge, pointerX: e.clientX, pointerY: e.clientY, start: { ...win.rect } }
  }

  function onEdgePointerMove(e: PointerEvent) {
    if (!sizing || !spec) return
    live = resize(sizing.start, sizing.edge, e.clientX - sizing.pointerX, e.clientY - sizing.pointerY, spec.minSize)
  }

  function onEdgePointerUp() {
    if (!sizing) return
    sizing = null
    if (live) desk.windows.place(win.id, live)
    live = null
  }

  const edgeClass: Record<Edge, string> = {
    n: 'top-0 left-3 right-3 h-2 -translate-y-1/2 cursor-ns-resize',
    s: 'bottom-0 left-3 right-3 h-2 translate-y-1/2 cursor-ns-resize',
    e: 'right-0 top-3 bottom-3 w-2 translate-x-1/2 cursor-ew-resize',
    w: 'left-0 top-3 bottom-3 w-2 -translate-x-1/2 cursor-ew-resize',
    ne: 'right-0 top-0 h-3 w-3 translate-x-1/2 -translate-y-1/2 cursor-nesw-resize',
    nw: 'left-0 top-0 h-3 w-3 -translate-x-1/2 -translate-y-1/2 cursor-nwse-resize',
    se: 'right-0 bottom-0 h-3 w-3 translate-x-1/2 translate-y-1/2 cursor-nwse-resize',
    sw: 'left-0 bottom-0 h-3 w-3 -translate-x-1/2 translate-y-1/2 cursor-nesw-resize',
  }
</script>

<div
  class="desk-window desk-opening absolute flex"
  style:left="{rect.x}px"
  style:top="{rect.y}px"
  style:width="{rect.width}px"
  style:height="{rect.height}px"
  style:z-index={win.z}
  data-active={active}
  data-minimized={win.minimized}
  data-snapped={!!win.snap}
  data-compact={compact}
  data-animate={animate}
  data-window-id={win.id}
  data-app-id={win.appId}
  data-merging={merging}
  aria-label={title}
  role="dialog"
  tabindex="-1"
  onpointerdowncapture={() => desk.windows.focus(win.id)}
>
  <!-- The design system's window: the bar floats over the content, which
       scrolls under it (blurred once scrolled, or always). With a sidebar the
       inset glass sidebar holds the lights; else the bar does. Both are drag
       handles. -->
  <div class="lk-window h-full min-w-0 flex-1" class:lk-window--inactive={!active}>
    {#if sidebar && !folded}
      <aside class="lk-window__sidebar" style:width="{sidebar.width}px" aria-label={$LL.deskSidebar()}>
        {@render handle('side')}
        <div class="lk-window__sidebar-body">{@render sidebar.content()}</div>
      </aside>
    {/if}
    <div class="lk-window__main" style:left="{sidebar && !folded ? sidebar.width + 14 : 0}px">
      {@render handle('bar')}
      {#if tabDrop}
        <div class="desk-pane-drop desk-pane-drop--tab" aria-hidden="true"></div>
      {/if}
      <!-- A size container: an app lays itself out by its window's width
           (`@md:`, `@3xl:`), never the screen's (`md:`). A column: an app
           whose content fills the window takes `min-h-0 flex-1`. -->
      <div
        class="lk-window__content desk-window-body @container flex flex-col"
        class:lk-window__content--panes={spec?.panes}
        style:bottom="{footer ? footerHeight : 0}px"
        style:zoom={TEXT_SCALE[systemPrefs.value.textSize] === 1 ? undefined : TEXT_SCALE[systemPrefs.value.textSize]}
        onscrollcapture={onContentScroll}
      >
        <!-- A window with panes lays them out under the bar itself. -->
        {#if !spec?.panes}
          <div class="lk-window__spacer" aria-hidden="true"></div>
          {#if toolbar?.tabs}<div class="shrink-0 px-[17px] pb-[7px]">{@render toolbar.tabs()}</div>{/if}
        {/if}
        {#if spec && !suspended}
          {#await spec.load()}
            <div class="flex flex-1 items-center justify-center"><Spinner /></div>
          {:then mod}
            {#if spec.panes}
              <PaneHost content={mod.default} appTitle={spec.title($LL)} />
            {:else}
              <mod.default />
            {/if}
          {:catch}
            <p class="p-6 text-sm text-(--color-danger)">{$LL.deskAppFailed()}</p>
          {/await}
        {/if}
      </div>
      {#if footer}
        <div class="lk-window__footer" bind:clientHeight={footerHeight}>{@render footer.content()}</div>
      {/if}
      {#if sidebar && folded && chrome.sidebarOpen}
        <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
        <div class="absolute inset-0 z-20" onclick={() => (chrome.sidebarOpen = false)}></div>
        <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
        <aside
          class="lk-window__sidebar z-30 pt-[9px]"
          style:top="var(--titlebar-height)"
          style:width="{Math.min(sidebar.width, rect.width - 40)}px"
          aria-label={$LL.deskSidebar()}
          onclick={(e) => {
            // A choice made in the folded sidebar is a reason to fold it again.
            if ((e.target as HTMLElement).closest('button')) chrome.sidebarOpen = false
          }}
        >
          <div class="lk-window__sidebar-body">{@render sidebar.content()}</div>
        </aside>
      {/if}
    </div>
  </div>

  {#if !compact && !win.snap}
    {#each EDGES as edge (edge)}
      <div
        class="absolute z-10 {edgeClass[edge]}"
        style:touch-action="none"
        aria-hidden="true"
        onpointerdown={(e) => onEdgePointerDown(e, edge)}
        onpointermove={onEdgePointerMove}
        onpointerup={onEdgePointerUp}
        onpointercancel={onEdgePointerUp}
      ></div>
    {/each}
  {/if}
</div>

<!-- A part of the frame the window is dragged by; a double-click zooms. -->
{#snippet handle(part: 'bar' | 'side')}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="{part === 'bar' ? 'lk-window__bar' : 'lk-window__sidebar-top'} select-none"
    class:lk-window__bar--glass={part === 'bar' && blurred}
    class:lk-window__bar--flush={part === 'bar' && flush}
    style:touch-action="none"
    onpointerdown={onTitlePointerDown}
    onpointermove={onTitlePointerMove}
    onpointerup={onTitlePointerUp}
    onpointercancel={onTitlePointerUp}
    ondblclick={(e) => {
      if (!(e.target as HTMLElement).closest('button, input, select, [role=tab]')) toggleMaximize()
    }}
  >
    {#if part === 'bar'}{@render bar()}{:else}{@render controls()}{/if}
  </div>
{/snippet}

{#snippet controls()}
  <WindowControls
    inactive={!active}
    zoomed={win.snap === 'max'}
    labels={controlLabels}
    onclose={() => desk.windows.close(win.id)}
    onminimize={compact ? undefined : () => desk.windows.minimize(win.id)}
    onzoom={compact ? undefined : toggleMaximize}
  />
{/snippet}

{#snippet bar()}
  {#if !sidebar || folded}{@render controls()}{/if}
  {#if sidebar && folded}
    <IconButton
      icon="side_navigation"
      label={$LL.deskSidebar()}
      size="sm"
      active={chrome.sidebarOpen}
      aria-expanded={chrome.sidebarOpen}
      onclick={() => (chrome.sidebarOpen = !chrome.sidebarOpen)}
    />
  {/if}
  {#if toolbar?.back}<IconButton icon="chevron_left" label={$LL.back()} size="sm" onclick={toolbar.back} />{/if}
  {@render toolbar?.leading?.()}
  {#if toolbar?.heading}
    <div class="flex min-w-0 items-center" class:flex-1={toolbar.headingFill} data-no-drag use:viewEnter={shown} use:viewIn={toolbar.heading}>{@render toolbar.heading()}</div>
  {:else}
    <!-- One line: the title, then what it is about, which gives way first. -->
    <div class="lk-window__heading" use:viewEnter={shown}>
      <h2 class="lk-window__title min-w-0 shrink-[0.2]">{toolbar?.title ?? title}</h2>
      {#if toolbar?.subtitle}<p class="lk-window__subtitle min-w-0">{toolbar.subtitle}</p>{/if}
    </div>
  {/if}
  {#if toolbar?.actions}<div class="lk-window__tools" data-no-drag>{@render toolbar.actions()}</div>{/if}
{/snippet}
