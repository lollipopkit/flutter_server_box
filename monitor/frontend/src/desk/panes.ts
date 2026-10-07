/// Tabs and split panes inside one window (an app whose manifest sets
/// `panes`), as plain data: the window's `appState` holds the layout, and
/// each pane's own state sits in it. Pure, so the rules are testable without
/// a DOM (`tests/deskPanes.test.ts`); `window/PaneHost.svelte` draws it.
///
/// A pane keeps its id for life, wherever it moves — to another tab, into
/// another window by a merge, out to a window of its own — and its app keys
/// what outlives a mount by that id (a terminal's session handle).

export type SplitDir = 'row' | 'column'
/// Where a new pane goes beside an existing one.
export type Side = 'left' | 'right' | 'top' | 'bottom'

export interface Pane {
  kind: 'pane'
  id: string
  /// The app's own state for this pane (what `useWindow().appState` answers).
  state: unknown
}

export interface Split {
  kind: 'split'
  /// `row`: side by side; `column`: one above the other.
  dir: SplitDir
  /// The share of the first child, 0–1.
  ratio: number
  a: PaneNode
  b: PaneNode
}

export type PaneNode = Pane | Split

export interface Tab {
  id: string
  root: PaneNode
}

export interface Layout {
  tabs: Tab[]
  /// The tab on show.
  tab: string
  /// The pane that has the focus, in the tab on show.
  focus: string
}

/// Marks a window's `appState` as a layout; anything else is one pane's state.
const MARK = '$panes'
const MIN_RATIO = 0.1

export function newId(prefix: string): string {
  return `${prefix}${Math.random().toString(36).slice(2, 10)}${Date.now().toString(36).slice(-4)}`
}

export function pane(state: unknown = null, id = newId('p')): Pane {
  return { kind: 'pane', id, state }
}

/// The layout a window's `appState` holds. A state that is not one (a window
/// opened with an app's plain state, or saved before the app had panes) is a
/// single pane whose id is the window's, so what the app keyed by the window
/// id is found again under the pane's.
export function readLayout(appState: unknown, windowId: string): Layout {
  if (isLayout(appState)) return appState.layout
  const only = pane(appState ?? null, windowId)
  return { tabs: [{ id: `t${windowId}`, root: only }], tab: `t${windowId}`, focus: only.id }
}

export function writeLayout(layout: Layout): unknown {
  return { [MARK]: 1, layout }
}

function isLayout(value: unknown): value is { layout: Layout } {
  if (typeof value !== 'object' || value === null || !(MARK in value)) return false
  const layout = (value as { layout?: Layout }).layout
  return !!layout && Array.isArray(layout.tabs) && layout.tabs.length > 0
}

export function panesOf(node: PaneNode): Pane[] {
  return node.kind === 'pane' ? [node] : [...panesOf(node.a), ...panesOf(node.b)]
}

export function allPanes(layout: Layout): Pane[] {
  return layout.tabs.flatMap((t) => panesOf(t.root))
}

export function tabOf(layout: Layout, paneId: string): Tab | undefined {
  return layout.tabs.find((t) => panesOf(t.root).some((p) => p.id === paneId))
}

export function activeTab(layout: Layout): Tab {
  return layout.tabs.find((t) => t.id === layout.tab) ?? layout.tabs[0]
}

/// The focused pane, or the first of the tab on show when the focus is stale.
export function focusedPane(layout: Layout): Pane {
  const tab = activeTab(layout)
  const panes = panesOf(tab.root)
  return panes.find((p) => p.id === layout.focus) ?? panes[0]
}

function mapNode(node: PaneNode, fn: (node: PaneNode) => PaneNode): PaneNode {
  const mapped = fn(node)
  if (mapped !== node || node.kind === 'pane') return mapped
  const a = mapNode(node.a, fn)
  const b = mapNode(node.b, fn)
  return a === node.a && b === node.b ? node : { ...node, a, b }
}

function mapTabs(layout: Layout, fn: (root: PaneNode) => PaneNode): Layout {
  let changed = false
  const tabs = layout.tabs.map((t) => {
    const root = fn(t.root)
    if (root === t.root) return t
    changed = true
    return { ...t, root }
  })
  return changed ? { ...layout, tabs } : layout
}

/// Replaces one pane's state; every other node keeps its identity.
export function setPaneState(layout: Layout, paneId: string, state: unknown): Layout {
  return mapTabs(layout, (root) =>
    mapNode(root, (n) => (n.kind === 'pane' && n.id === paneId ? { ...n, state } : n)),
  )
}

export function focus(layout: Layout, paneId: string): Layout {
  const tab = tabOf(layout, paneId)
  if (!tab || (layout.focus === paneId && layout.tab === tab.id)) return layout
  return { ...layout, tab: tab.id, focus: paneId }
}

export function showTab(layout: Layout, tabId: string): Layout {
  const tab = layout.tabs.find((t) => t.id === tabId)
  if (!tab || layout.tab === tabId) return layout
  // The pane last focused in it is not remembered; its first is focused.
  return { ...layout, tab: tabId, focus: panesOf(tab.root)[0].id }
}

/// [node] beside the pane [paneId], on [side]; the two share its space.
export function split(layout: Layout, paneId: string, side: Side, node: PaneNode): Layout {
  const dir: SplitDir = side === 'left' || side === 'right' ? 'row' : 'column'
  const first = side === 'left' || side === 'top'
  const next = mapTabs(layout, (root) =>
    mapNode(root, (n) =>
      n.kind === 'pane' && n.id === paneId
        ? { kind: 'split', dir, ratio: 0.5, a: first ? node : n, b: first ? n : node }
        : n,
    ),
  )
  if (next === layout) return layout
  const tab = tabOf(next, paneId)
  return { ...next, tab: tab?.id ?? next.tab, focus: panesOf(node)[0].id }
}

/// A new tab holding [root], after the one on show, and shown.
export function addTab(layout: Layout, root: PaneNode, id = newId('t')): Layout {
  const at = layout.tabs.findIndex((t) => t.id === layout.tab)
  const tabs = [...layout.tabs]
  tabs.splice(at + 1, 0, { id, root })
  return { tabs, tab: id, focus: panesOf(root)[0].id }
}

function without(node: PaneNode, paneId: string): PaneNode | null {
  if (node.kind === 'pane') return node.id === paneId ? null : node
  const a = without(node.a, paneId)
  const b = without(node.b, paneId)
  if (a === null) return b
  if (b === null) return a
  return a === node.a && b === node.b ? node : { ...node, a, b }
}

/// The layout without [paneId] (its sibling takes the space, a tab left empty
/// goes), or null when nothing is left.
export function removePane(layout: Layout, paneId: string): Layout | null {
  const tabs: Tab[] = []
  for (const t of layout.tabs) {
    const root = without(t.root, paneId)
    if (root) tabs.push(root === t.root ? t : { ...t, root })
  }
  if (tabs.length === 0) return null
  return settle(layout, tabs)
}

/// The layout without the tab [tabId], or null when it was the last.
export function removeTab(layout: Layout, tabId: string): Layout | null {
  const tabs = layout.tabs.filter((t) => t.id !== tabId)
  if (tabs.length === 0) return null
  return settle(layout, tabs)
}

/// [tabs] with the tab on show and the focus kept where they still exist, or
/// moved to the neighbour of what went.
function settle(layout: Layout, tabs: Tab[]): Layout {
  const was = layout.tabs.findIndex((t) => t.id === layout.tab)
  const tab = tabs.find((t) => t.id === layout.tab) ?? tabs[Math.min(Math.max(was, 0), tabs.length - 1)]
  const panes = panesOf(tab.root)
  const focus = panes.some((p) => p.id === layout.focus) ? layout.focus : panes[0].id
  return { tabs, tab: tab.id, focus }
}

export function moveTab(layout: Layout, tabId: string, to: number): Layout {
  const from = layout.tabs.findIndex((t) => t.id === tabId)
  if (from < 0) return layout
  const tabs = [...layout.tabs]
  const [tab] = tabs.splice(from, 1)
  tabs.splice(Math.max(0, Math.min(to, tabs.length)), 0, tab)
  return { ...layout, tabs }
}

/// The split at [path] (`a`/`b` steps from the tab's root) given [ratio].
export function setRatio(layout: Layout, tabId: string, path: string, ratio: number): Layout {
  const r = Math.min(1 - MIN_RATIO, Math.max(MIN_RATIO, ratio))
  const at = (node: PaneNode, rest: string): PaneNode => {
    if (node.kind !== 'split') return node
    if (rest === '') return node.ratio === r ? node : { ...node, ratio: r }
    const step = rest[0] as 'a' | 'b'
    const child = at(node[step], rest.slice(1))
    return child === node[step] ? node : { ...node, [step]: child }
  }
  const tabs = layout.tabs.map((t) => (t.id === tabId ? { ...t, root: at(t.root, path) } : t))
  return { ...layout, tabs }
}

/// Where another window's layout goes when it is dropped on this one.
export type Placement = { kind: 'tab' } | { kind: 'split'; paneId: string; side: Side }

/// [source] merged into [target]: its tabs after the one on show, or its tab
/// on show split in beside a pane (the rest of its tabs follow as tabs).
export function merge(target: Layout, source: Layout, placement: Placement): Layout {
  const shown = activeTab(source)
  const rest = source.tabs.filter((t) => t.id !== shown.id)
  let next = target
  if (placement.kind === 'split') {
    next = split(next, placement.paneId, placement.side, shown.root)
  } else {
    next = addTab(next, shown.root, shown.id)
  }
  const at = next.tabs.findIndex((t) => t.id === next.tab)
  const tabs = [...next.tabs]
  tabs.splice(at + 1, 0, ...rest)
  // Focus what was focused in the window dropped.
  const focusId = panesOf(shown.root).some((p) => p.id === source.focus)
    ? source.focus
    : panesOf(shown.root)[0].id
  return { tabs, tab: next.tab, focus: focusId }
}

export interface Rect {
  x: number
  y: number
  w: number
  h: number
}

/// Each pane's place in its tab, as fractions of the tab's box.
export function paneRects(root: PaneNode, box: Rect = { x: 0, y: 0, w: 1, h: 1 }): Map<string, Rect> {
  const out = new Map<string, Rect>()
  const walk = (node: PaneNode, r: Rect) => {
    if (node.kind === 'pane') {
      out.set(node.id, r)
      return
    }
    const [ra, rb] = halves(node, r)
    walk(node.a, ra)
    walk(node.b, rb)
  }
  walk(root, box)
  return out
}

function halves(node: Split, r: Rect): [Rect, Rect] {
  return node.dir === 'row'
    ? [
        { x: r.x, y: r.y, w: r.w * node.ratio, h: r.h },
        { x: r.x + r.w * node.ratio, y: r.y, w: r.w * (1 - node.ratio), h: r.h },
      ]
    : [
        { x: r.x, y: r.y, w: r.w, h: r.h * node.ratio },
        { x: r.x, y: r.y + r.h * node.ratio, w: r.w, h: r.h * (1 - node.ratio) },
      ]
}

export interface Divider {
  /// The split's path from the root (see [setRatio]).
  path: string
  dir: SplitDir
  /// The split's whole box, against which a drag is a ratio.
  box: Rect
  /// Where the line is: x for a row split, y for a column split.
  at: number
}

export function dividers(root: PaneNode): Divider[] {
  const out: Divider[] = []
  const walk = (node: PaneNode, r: Rect, path: string) => {
    if (node.kind !== 'split') return
    out.push({
      path,
      dir: node.dir,
      box: r,
      at: node.dir === 'row' ? r.x + r.w * node.ratio : r.y + r.h * node.ratio,
    })
    const [ra, rb] = halves(node, r)
    walk(node.a, ra, `${path}a`)
    walk(node.b, rb, `${path}b`)
  }
  walk(root, { x: 0, y: 0, w: 1, h: 1 }, '')
  return out
}

/// The side of [r] nearest to (px, py), both in the same units: where a pane
/// dropped there goes.
export function sideAt(r: Rect, px: number, py: number): Side {
  const fx = (px - r.x) / r.w
  const fy = (py - r.y) / r.h
  const d: [Side, number][] = [
    ['left', fx],
    ['right', 1 - fx],
    ['top', fy],
    ['bottom', 1 - fy],
  ]
  return d.reduce((best, cur) => (cur[1] < best[1] ? cur : best))[0]
}
