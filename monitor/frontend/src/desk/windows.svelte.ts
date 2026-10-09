/// The desk's windows: which are open, where, in what order. State only — a
/// window's chrome is `window/Window.svelte`, its content the app's.
///
/// One instance per desk (`Desk.svelte` makes it and puts it in context), so a
/// desk unmounted when the server switches takes its windows with it.

import {
  type Area,
  type Rect,
  type Size,
  type SnapZone,
  cascade,
  clamp,
  COMPACT_WIDTH,
  snapRect,
} from './geometry'

/// What the manager needs to know of an app.
export interface WindowPolicy {
  /// How many windows of it may be open; 1 focuses the open one instead.
  instances: number
  size: Size
  minSize: Size
}

export interface DeskWindow {
  id: string
  appId: string
  /// What the app keeps for itself (a path, a tab); restored with the window.
  appState: unknown
  /// Set by the app; the app's title otherwise.
  title: string | null
  rect: Rect
  z: number
  minimized: boolean
  /// Maximised or snapped: [rect] is what it covers, [restore] what it had.
  snap: SnapZone | null
  restore: Rect | null
}

/// One window as the agent stores it (`api::desk::Window`).
export interface StoredWindow {
  window_id: string
  app_id: string
  server_id?: string | null
  x: number
  y: number
  width: number
  height: number
  z: number
  minimized: boolean
  maximized: boolean
  app_state?: unknown
}

export interface OpenOptions {
  appState?: unknown
  /// Open another window even where one is open (up to the app's limit).
  newWindow?: boolean
  /// Something for the app to do once open (`sys.useIntents`). Not saved
  /// with the window: it is delivered once.
  intent?: Intent
}

/// A request handed to an app. `open` is the desk's own (a path from Files
/// or Spotlight, `data: { path, kind }`); an app may name others for apps it
/// knows, prefixed by the receiving app's id (`terminal.type`).
export interface Intent {
  action: string
  data?: unknown
  /// The app that sent it, set by the desk (never by the sender): an app
  /// acts on an intent only from the apps it expects.
  from?: string
}

function newWindowId(): string {
  return typeof crypto.randomUUID === 'function'
    ? crypto.randomUUID()
    : `w${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`
}

export class WindowManager {
  windows = $state<DeskWindow[]>([])
  area = $state<Area>({ width: 1280, height: 800, top: 40, bottom: 84, left: 0, right: 0 })
  /// Bumped on every change worth saving (`session.svelte.ts` watches it).
  changes = $state(0)

  #policy: (appId: string) => WindowPolicy | undefined
  #z = 0
  /// Ids closed on this desk (ids are never reused); see `wasClosed`.
  // eslint-disable-next-line svelte/prefer-svelte-reactivity -- deliberately plain; see `wasClosed`
  readonly #closed = new Set<string>()

  constructor(policy: (appId: string) => WindowPolicy | undefined) {
    this.#policy = policy
  }

  /// One window at a time, full screen: a phone.
  get compact(): boolean {
    return this.area.width < COMPACT_WIDTH
  }

  /// The window in front that is not minimised.
  get active(): DeskWindow | undefined {
    let top: DeskWindow | undefined
    for (const w of this.windows) if (!w.minimized && (!top || w.z > top.z)) top = w
    return top
  }

  get(id: string): DeskWindow | undefined {
    return this.windows.find((w) => w.id === id)
  }

  of(appId: string): DeskWindow[] {
    return this.windows.filter((w) => w.appId === appId)
  }

  /// Opens [appId], or brings forward the one window an app allows. Answers
  /// the window's id, or null when the app is unknown or at its limit (the
  /// newest of its windows is focused then).
  open(appId: string, options: OpenOptions = {}): string | null {
    const policy = this.#policy(appId)
    if (!policy) return null
    const existing = this.of(appId)
    const wantNew = options.newWindow || policy.instances > 1
    if (existing.length > 0 && (!wantNew || existing.length >= policy.instances)) {
      const target = existing.reduce((a, b) => (b.z > a.z ? b : a))
      if (options.appState !== undefined && policy.instances === 1) target.appState = options.appState
      this.focus(target.id)
      return policy.instances === 1 ? target.id : null
    }
    const rect = cascade(this.windows.length, policy.size, this.area)
    const win: DeskWindow = {
      id: newWindowId(),
      appId,
      appState: options.appState ?? null,
      title: null,
      rect,
      z: ++this.#z,
      minimized: false,
      snap: null,
      restore: null,
    }
    this.windows.push(win)
    this.#changed()
    return win.id
  }

  close(id: string) {
    const before = this.windows.length
    this.windows = this.windows.filter((w) => w.id !== id)
    if (this.windows.length !== before) {
      this.#closed.add(id)
      this.#changed()
    }
  }

  closeApp(appId: string) {
    for (const w of this.of(appId)) this.#closed.add(w.id)
    this.windows = this.windows.filter((w) => w.appId !== appId)
    this.#changed()
  }

  /// Takes [id] away without closing it: its content went into another
  /// window (a merge, `deskState`), so what it holds open lives on there.
  absorb(id: string) {
    const before = this.windows.length
    this.windows = this.windows.filter((w) => w.id !== id)
    if (this.windows.length !== before) this.#changed()
  }

  /// Whether [id] was closed here. Plain, not reactive: it is read in an app's
  /// teardown, where state reads answer the value from before the change.
  wasClosed(id: string): boolean {
    return this.#closed.has(id)
  }

  focus(id: string) {
    const w = this.get(id)
    if (!w) return
    const wasMinimized = w.minimized
    w.minimized = false
    if (w.z !== this.#z || wasMinimized) {
      w.z = ++this.#z
      this.#changed()
    }
  }

  minimize(id: string) {
    const w = this.get(id)
    if (!w || w.minimized) return
    w.minimized = true
    this.#changed()
  }

  /// Maximises, or puts a maximised (or snapped) window back where it was.
  toggleMaximize(id: string) {
    const w = this.get(id)
    if (!w) return
    if (w.snap) this.unsnap(id)
    else this.snap(id, 'max')
  }

  snap(id: string, zone: SnapZone) {
    const w = this.get(id)
    if (!w) return
    if (!w.snap) w.restore = { ...w.rect }
    w.snap = zone
    w.rect = snapRect(zone, this.area)
    this.focus(id)
    this.#changed()
  }

  unsnap(id: string, at?: Rect) {
    const w = this.get(id)
    if (!w?.snap) return
    const policy = this.#policy(w.appId)
    const back = at ?? w.restore ?? w.rect
    w.snap = null
    w.restore = null
    w.rect = policy ? clamp(back, this.area, policy.minSize) : back
    this.#changed()
  }

  /// Where a drag or a resize left it: kept on the area.
  place(id: string, rect: Rect) {
    const w = this.get(id)
    if (!w) return
    const policy = this.#policy(w.appId)
    w.rect = policy ? clamp(rect, this.area, policy.minSize) : rect
    w.snap = null
    w.restore = null
    this.#changed()
  }

  setTitle(id: string, title: string | null) {
    const w = this.get(id)
    if (w) w.title = title
  }

  setAppState(id: string, appState: unknown) {
    const w = this.get(id)
    if (!w) return
    w.appState = appState
    this.#changed()
  }

  /// The browser window changed size: snapped windows follow, the rest are
  /// kept reachable. Not a change worth saving by itself.
  resizeArea(area: Area) {
    this.area = area
    for (const w of this.windows) {
      if (w.snap) w.rect = snapRect(w.snap, area)
      else {
        const policy = this.#policy(w.appId)
        if (policy) w.rect = clamp(w.rect, area, policy.minSize)
      }
    }
  }

  /// Cycles focus through the windows not minimised (Alt+` style).
  cycle() {
    const visible = this.windows.filter((w) => !w.minimized).sort((a, b) => a.z - b.z)
    if (visible.length > 1) this.focus(visible[0].id)
  }

  /// What the agent stores. A snapped window is stored where it is, a
  /// maximised one as maximised over what it will go back to.
  serialize(serverId: string | null): { active_window_id: string | null; windows: StoredWindow[] } {
    const windows = [...this.windows]
      .sort((a, b) => a.z - b.z)
      .map((w, i): StoredWindow => {
        const maximized = w.snap === 'max'
        const rect = maximized && w.restore ? w.restore : w.rect
        return {
          window_id: w.id,
          app_id: w.appId,
          server_id: serverId,
          x: Math.round(rect.x),
          y: Math.round(rect.y),
          width: Math.max(1, Math.round(rect.width)),
          height: Math.max(1, Math.round(rect.height)),
          z: i + 1,
          minimized: w.minimized,
          maximized,
          app_state: w.appState ?? null,
        }
      })
    return { active_window_id: this.active?.id ?? null, windows }
  }

  /// Makes the windows what [stored] says, keeping the ones still there (an
  /// app's state lives in its mounted component), dropping apps this desk
  /// no longer knows.
  hydrate(stored: StoredWindow[]) {
    const known = stored.filter((s) => this.#policy(s.app_id))
    const current = this.windows
    const next: DeskWindow[] = []
    for (const s of [...known].sort((a, b) => a.z - b.z)) {
      const policy = this.#policy(s.app_id)!
      const base = clamp({ x: s.x, y: s.y, width: s.width, height: s.height }, this.area, policy.minSize)
      const w = current.find((x) => x.id === s.window_id) ?? {
        id: s.window_id,
        appId: s.app_id,
        appState: null,
        title: null,
        rect: base,
        z: 0,
        minimized: false,
        snap: null,
        restore: null,
      }
      w.appState = s.app_state ?? null
      w.minimized = s.minimized
      w.z = ++this.#z
      if (s.maximized) {
        w.restore = base
        w.snap = 'max'
        w.rect = snapRect('max', this.area)
      } else {
        w.snap = null
        w.restore = null
        w.rect = base
      }
      next.push(w)
    }
    this.windows = next
  }

  #changed() {
    this.changes++
  }
}
