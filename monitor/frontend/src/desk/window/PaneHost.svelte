<script lang="ts">
  /// A window's tabs and split panes (an app whose manifest sets `panes`).
  ///
  /// Every pane of every tab stays mounted, laid out absolutely in one flat
  /// list keyed by its id, so a split, a closed neighbour, a tab switch or a
  /// merge never remounts a pane — a terminal keeps its screen. Panes of
  /// other tabs are hidden (`visibility`, `inert`) at their size, and run
  /// in the background. The window shows the focused pane's toolbar,
  /// sidebar, footer and menus; intents go to it.

  import type { Component } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import Icon from '../lk/Icon.svelte'
  import IconButton from '../lk/IconButton.svelte'
  import { useDesk } from '../deskState.svelte'
  import { activeTab, dividers, paneRects, type Divider, type Rect } from '../panes'
  import { useWindow } from '../sys/window.svelte'
  import PaneSlot from './PaneSlot.svelte'
  import { PaneHostState } from './paneHostState.svelte'

  interface Props {
    content: Component
    /// What a tab is called before its pane names itself.
    appTitle: string
  }

  const { content, appTitle }: Props = $props()
  const desk = useDesk()
  const parent = useWindow()
  const host = new PaneHostState(parent)
  const winChrome = parent.chrome

  // ---- the window shows the focused pane --------------------------------

  if (winChrome) {
    // With several tabs the tabs are the title (the design system's terminal
    // tabs): the focused pane's tools stay, its title gives way to them.
    $effect(() => {
      const toolbar = host.focusedChrome?.toolbar
      if (!multiTab) {
        if (toolbar) return winChrome.pushToolbar(toolbar)
        return
      }
      return winChrome.pushToolbar({
        get actions() {
          return host.focusedChrome?.toolbar?.actions
        },
        get leading() {
          return host.focusedChrome?.toolbar?.leading
        },
        get back() {
          return host.focusedChrome?.toolbar?.back
        },
        get flush() {
          return host.focusedChrome?.toolbar?.flush
        },
        heading: tabsHeading,
        headingFill: true,
      })
    })
    $effect(() => {
      const sidebar = host.focusedChrome?.sidebar
      if (sidebar) return winChrome.pushSidebar(sidebar)
    })
    $effect(() => {
      const footer = host.focusedChrome?.footer
      if (footer) return winChrome.pushFooter(footer)
    })
    $effect(() =>
      winChrome.pushMenus({
        get menus() {
          return host.focusedChrome?.menus ?? []
        },
      }),
    )
    $effect(() =>
      winChrome.pushDockMenu({
        get menus() {
          return [{ label: '', items: host.focusedChrome?.dockItems ?? [] }]
        },
      }),
    )
    $effect(() => {
      const chrome = host.focusedChrome
      if (chrome && winChrome.pendingIntents > 0) chrome.deliver(...winChrome.takeIntents())
    })
  }

  let shownTitle: string | null | undefined
  $effect(() => {
    const title = host.titleOf(host.focusId)
    if (title === shownTitle) return
    shownTitle = title
    parent.setTitle(title)
  })

  // ---- layout -----------------------------------------------------------

  const layout = $derived(host.layout)
  const multiTab = $derived(layout.tabs.length > 1)
  const tab = $derived(activeTab(layout))
  /// Split: the panes start under the bar rather than behind it, so no
  /// divider runs through the title.
  const underBar = $derived(multiTab || tab.root.kind === 'split')
  /// Every pane, every tab, in one list ordered by id: a pane added or gone
  /// never moves the others in the DOM.
  const placed = $derived.by(() => {
    const out: { id: string; tabId: string; rect: Rect; alone: boolean }[] = []
    for (const t of layout.tabs) {
      const rects = paneRects(t.root)
      for (const [id, rect] of rects) out.push({ id, tabId: t.id, rect, alone: rects.size === 1 })
    }
    return out.sort((a, b) => (a.id < b.id ? -1 : 1))
  })
  const lines = $derived(dividers(tab.root))

  /// Each tab is called what its session calls itself, as it is.
  const tabLabels = $derived(layout.tabs.map((t) => host.tabTitle(t) ?? appTitle))

  let area = $state<HTMLDivElement | null>(null)

  const pct = (n: number) => `${n * 100}%`

  // ---- dividers ---------------------------------------------------------

  let sizing: { divider: Divider; tabId: string } | null = null

  function onDividerDown(e: PointerEvent, divider: Divider) {
    if (e.button !== 0) return
    e.preventDefault()
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
    sizing = { divider, tabId: tab.id }
  }

  function onDividerMove(e: PointerEvent) {
    if (!sizing || !area) return
    const r = area.getBoundingClientRect()
    const { box, dir, path } = sizing.divider
    const ratio =
      dir === 'row'
        ? ((e.clientX - r.left) / r.width - box.x) / box.w
        : ((e.clientY - r.top) / r.height - box.y) / box.h
    host.setRatio(sizing.tabId, path, ratio)
  }

  function onDividerUp() {
    sizing = null
  }

  // ---- tabs -------------------------------------------------------------

  let strip = $state<HTMLDivElement | null>(null)
  /// A tab under the pointer: moved along the strip it is reordered, pulled
  /// away from it it becomes a window of its own.
  let tabDrag: { id: string; x: number; y: number; moved: boolean; away: boolean } | null = $state(null)

  function onTabDown(e: PointerEvent, id: string) {
    if (e.button !== 0 || (e.target as HTMLElement).closest('button')) return
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
    tabDrag = { id, x: e.clientX, y: e.clientY, moved: false, away: false }
    host.showTab(id)
  }

  function onTabMove(e: PointerEvent) {
    if (!tabDrag || !strip) return
    if (!tabDrag.moved && Math.abs(e.clientX - tabDrag.x) + Math.abs(e.clientY - tabDrag.y) < 5) return
    tabDrag.moved = true
    const r = strip.getBoundingClientRect()
    tabDrag.away = e.clientY < r.top - 24 || e.clientY > r.bottom + 24
    if (tabDrag.away) return
    const tabs = [...strip.querySelectorAll<HTMLElement>('[role=tab]')]
    const to = tabs.findIndex((el) => {
      const b = el.getBoundingClientRect()
      return e.clientX < b.left + b.width / 2
    })
    const index = to < 0 ? tabs.length - 1 : to
    const from = layout.tabs.findIndex((t) => t.id === tabDrag!.id)
    if (index !== from) host.moveTab(tabDrag.id, index > from ? index - 1 : index)
  }

  function onTabUp(e: PointerEvent) {
    const drag = tabDrag
    tabDrag = null
    if (drag?.moved && drag.away) desk.detachTab(parent.id, drag.id, { x: e.clientX, y: e.clientY })
  }

  // ---- a window dragged onto this one -----------------------------------

  const drop = $derived(desk.paneDrop?.windowId === parent.id ? desk.paneDrop : null)
  const dropRect = $derived.by(() => {
    if (drop?.kind !== 'split') return null
    const r = placed.find((p) => p.id === drop.paneId)?.rect
    if (!r) return null
    switch (drop.side) {
      case 'left':
        return { ...r, w: r.w / 2 }
      case 'right':
        return { ...r, x: r.x + r.w / 2, w: r.w / 2 }
      case 'top':
        return { ...r, h: r.h / 2 }
      case 'bottom':
        return { ...r, y: r.y + r.h / 2, h: r.h / 2 }
    }
  })
</script>

{#snippet tabsHeading()}
  <div class="desk-tabbar">
    <div bind:this={strip} class="desk-tabs" role="tablist" aria-label={appTitle} data-pane-strip>
      {#each layout.tabs as t, i (t.id)}
        <div
          role="tab"
          tabindex={t.id === tab.id ? 0 : -1}
          aria-selected={t.id === tab.id}
          class="desk-tab"
          class:desk-tab--on={t.id === tab.id}
          class:desk-tab--dragging={tabDrag?.id === t.id && tabDrag?.moved}
          title={tabLabels[i]}
          style:touch-action="none"
          onpointerdown={(e) => onTabDown(e, t.id)}
          onpointermove={onTabMove}
          onpointerup={onTabUp}
          onpointercancel={() => (tabDrag = null)}
          onkeydown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') host.showTab(t.id)
          }}
        >
          <button type="button" class="desk-tab__close" aria-label={$LL.deskCloseTab()} onclick={() => host.closeTab(t.id)}>
            <Icon name="close" size={14} />
          </button>
          <span class="desk-tab__title">{tabLabels[i]}</span>
        </div>
      {/each}
    </div>
    <IconButton icon="add" label={$LL.deskNewTab()} onclick={() => host.newTab()} />
  </div>
{/snippet}

<div class="desk-panes absolute inset-0" data-pane-host>

  <div
    bind:this={area}
    class="desk-panes__area"
    class:desk-panes__area--bar={underBar}
  >
    {#each placed as p (p.id)}
      {@const shown = p.tabId === tab.id}
      <div
        class="desk-pane"
        data-pane-id={p.id}
        style:left={pct(p.rect.x)}
        style:top={pct(p.rect.y)}
        style:width={pct(p.rect.w)}
        style:height={pct(p.rect.h)}
        style:--pane-top={underBar ? '0px' : 'var(--titlebar-height)'}
        style:visibility={shown ? null : 'hidden'}
        inert={!shown}
        onpointerdowncapture={() => host.focus(p.id)}
      >
        <div class="shrink-0" style:height="var(--pane-top)" aria-hidden="true"></div>
        <PaneSlot {host} paneId={p.id} {content} />
        {#if shown && !p.alone && host.focusId !== p.id}<div class="desk-pane__dim" aria-hidden="true"></div>{/if}
      </div>
    {/each}

    {#each lines as d (d.path)}
      <div
        class="desk-divider desk-divider--{d.dir}"
        style:left={d.dir === 'row' ? pct(d.at) : pct(d.box.x)}
        style:top={d.dir === 'row' ? pct(d.box.y) : pct(d.at)}
        style:width={d.dir === 'row' ? null : pct(d.box.w)}
        style:height={d.dir === 'row' ? pct(d.box.h) : null}
        style:touch-action="none"
        role="separator"
        aria-orientation={d.dir === 'row' ? 'vertical' : 'horizontal'}
        onpointerdown={(e) => onDividerDown(e, d)}
        onpointermove={onDividerMove}
        onpointerup={onDividerUp}
        onpointercancel={onDividerUp}
      ></div>
    {/each}

    {#if dropRect}
      <div
        class="desk-pane-drop"
        style:left={pct(dropRect.x)}
        style:top={pct(dropRect.y)}
        style:width={pct(dropRect.w)}
        style:height={pct(dropRect.h)}
        aria-hidden="true"
      ></div>
    {/if}
  </div>
</div>
