/// The state behind `PaneHost.svelte`: the window's layout (kept in its
/// `appState`, see `panes.ts`), each pane's frame and title, and the panes
/// closed here.

import { SvelteMap } from 'svelte/reactivity'
import {
  activeTab,
  addTab,
  allPanes,
  focus,
  focusedPane,
  moveTab,
  pane,
  readLayout,
  removePane,
  removeTab,
  setPaneState,
  setRatio,
  showTab,
  split,
  tabOf,
  writeLayout,
  panesOf,
  type Layout,
  type Tab,
} from '../panes'
import type { WindowHandle } from '../sys/window.svelte'
import { WindowChrome } from './chrome.svelte'

const MAX_TITLE = 120

export class PaneHostState {
  readonly parent: WindowHandle
  readonly layout: Layout = $derived.by(() => readLayout(this.parent.appState, this.parent.id))
  readonly #chromes = new SvelteMap<string, WindowChrome>()
  readonly #titles = new SvelteMap<string, string>()
  /// Panes closed here. Plain, not reactive: read in a pane's teardown, where
  /// state reads answer the value from before the change.
  // eslint-disable-next-line svelte/prefer-svelte-reactivity -- deliberately plain; see above
  readonly #closed = new Set<string>()

  constructor(parent: WindowHandle) {
    this.parent = parent
  }

  get focusId(): string {
    return focusedPane(this.layout).id
  }

  get count(): number {
    return allPanes(this.layout).length
  }

  /// The frame of the focused pane, whose toolbar, sidebar, footer and menus
  /// the window shows.
  get focusedChrome(): WindowChrome | undefined {
    return this.#chromes.get(this.focusId)
  }

  stateOf(id: string): unknown {
    return allPanes(this.layout).find((p) => p.id === id)?.state ?? null
  }

  /// Whether [id] is in the tab on show.
  shown(id: string): boolean {
    return tabOf(this.layout, id)?.id === activeTab(this.layout).id
  }

  titleOf(id: string): string | null {
    return this.#titles.get(id) ?? null
  }

  /// A tab's title: its focused pane's, or its first's.
  tabTitle(tab: Tab): string | null {
    const panes = panesOf(tab.root)
    const lead = panes.find((p) => p.id === this.layout.focus) ?? panes[0]
    return this.titleOf(lead.id)
  }

  chromeFor(id: string): WindowChrome {
    let chrome = this.#chromes.get(id)
    if (!chrome) {
      chrome = new WindowChrome(this.parent.chrome)
      this.#chromes.set(id, chrome)
    }
    return chrome
  }

  /// A pane's content went away.
  release(id: string) {
    this.#chromes.delete(id)
  }

  wasClosed(id: string): boolean {
    return this.#closed.has(id) || this.parent.closed
  }

  setState(id: string, state: unknown) {
    this.#commit(setPaneState(this.layout, id, state))
  }

  setTitle(id: string, title: string | null) {
    if (title === null || title === '') this.#titles.delete(id)
    else this.#titles.set(id, String(title).slice(0, MAX_TITLE))
  }

  focus(id: string) {
    this.#commit(focus(this.layout, id))
  }

  showTab(tabId: string) {
    this.#commit(showTab(this.layout, tabId))
  }

  newTab(state: unknown = null) {
    this.#commit(addTab(this.layout, pane(state)))
  }

  split(id: string, side: 'right' | 'bottom', state: unknown = null) {
    this.#commit(split(this.layout, id, side, pane(state)))
  }

  moveTab(tabId: string, to: number) {
    this.#commit(moveTab(this.layout, tabId, to))
  }

  setRatio(tabId: string, path: string, ratio: number) {
    this.#commit(setRatio(this.layout, tabId, path, ratio))
  }

  /// Closes [id]; the window goes with its last pane.
  closePane(id: string) {
    this.#closed.add(id)
    const next = removePane(this.layout, id)
    if (next) this.#commit(next)
    else this.parent.close()
  }

  closeTab(tabId: string) {
    const tab = this.layout.tabs.find((t) => t.id === tabId)
    if (!tab) return
    for (const p of panesOf(tab.root)) this.#closed.add(p.id)
    const next = removeTab(this.layout, tabId)
    if (next) this.#commit(next)
    else this.parent.close()
  }

  #commit(next: Layout) {
    if (next !== this.layout) this.parent.setAppState(writeLayout(next))
  }
}
