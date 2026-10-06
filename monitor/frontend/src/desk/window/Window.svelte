<script lang="ts">
  import { Maximize2, Minus, X } from '@lucide/svelte'
  import { Spinner } from '@serverbox/webui'
  import { LL } from '../../i18n/i18n-svelte'
  import { app } from '../apps'
  import { provideWindow, useDesk } from '../deskState.svelte'
  import { type Edge, type Rect, type SnapZone, resize, snapZoneAt, unsnapUnder, usable } from '../geometry'
  import type { DeskWindow } from '../windows.svelte'

  interface Props {
    win: DeskWindow
    /// Where a drag would snap if let go now; the layer draws it.
    onsnappreview: (zone: SnapZone | null) => void
  }

  const { win, onsnappreview }: Props = $props()
  const desk = useDesk()
  // svelte-ignore state_referenced_locally
  provideWindow(desk, win.id)

  const spec = $derived(app(win.appId))
  const title = $derived(win.title ?? (spec ? spec.title($LL) : win.appId))
  const active = $derived(desk.windows.active?.id === win.id)
  const compact = $derived(desk.windows.compact)

  /// The rect while a drag or resize is under way; the store gets it on release.
  let live = $state<Rect | null>(null)
  /// Geometry animates for a maximise or a snap, never under the pointer.
  let animate = $state(false)

  const rect = $derived.by(() => {
    if (compact) return usable(desk.windows.area)
    return live ?? win.rect
  })

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
    if ((e.target as HTMLElement).closest('button, input, a, [data-no-drag]')) return
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
    if (moved && zone) {
      animateOnce()
      desk.windows.snap(win.id, zone)
    } else if (moved && live) {
      desk.windows.place(win.id, live)
    }
    live = null
  }

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
  class="desk-window desk-opening absolute"
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
  aria-label={title}
  role="dialog"
  tabindex="-1"
  onpointerdowncapture={() => desk.windows.focus(win.id)}
>
  <!-- Clipped to the window's corners; the resize edges outside it are not,
       so they can be taken from just beyond the border. -->
  <div class="flex h-full flex-col overflow-hidden rounded-[inherit]">
  <!-- The title bar is a drag handle; its buttons are the keyboard's way. -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <header
    class="relative grid h-10 shrink-0 select-none grid-cols-[5rem_1fr_5rem] items-center px-3"
    style:touch-action="none"
    onpointerdown={onTitlePointerDown}
    onpointermove={onTitlePointerMove}
    onpointerup={onTitlePointerUp}
    onpointercancel={onTitlePointerUp}
    ondblclick={(e) => {
      if (!(e.target as HTMLElement).closest('button')) toggleMaximize()
    }}
  >
    <div class="desk-traffic-group flex items-center gap-2" data-no-drag>
      <button
        class="desk-traffic bg-[#ff5f57]"
        aria-label={$LL.deskClose()}
        title={$LL.deskClose()}
        onclick={() => desk.windows.close(win.id)}
      >
        <X strokeWidth={3} />
      </button>
      {#if !compact}
        <button
          class="desk-traffic bg-[#febb2e]"
          aria-label={$LL.deskMinimize()}
          title={$LL.deskMinimize()}
          onclick={() => desk.windows.minimize(win.id)}
        >
          <Minus strokeWidth={3} />
        </button>
        <button
          class="desk-traffic bg-[#28c840]"
          aria-label={$LL.deskZoom()}
          title={$LL.deskZoom()}
          onclick={toggleMaximize}
        >
          <Maximize2 strokeWidth={3} />
        </button>
      {/if}
    </div>
    <h2 class="truncate text-center text-[0.8rem] font-semibold desk-muted" class:!opacity-100={active}>
      {title}
    </h2>
    <div></div>
  </header>

  <!-- A size container: an app lays itself out by its window's width
       (`@md:`, `@3xl:`), never the screen's (`md:`). A column: an app whose
       content fills the window under its toolbar takes `min-h-0 flex-1`,
       never a height worked out from the toolbar's. -->
  <div class="desk-window-body @container relative flex min-h-0 flex-1 flex-col overflow-auto">
    {#if spec}
      {#await spec.load()}
        <div class="flex h-full items-center justify-center"><Spinner /></div>
      {:then mod}
        <mod.default />
      {:catch}
        <p class="p-6 text-sm text-danger">{$LL.deskAppFailed()}</p>
      {/await}
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
