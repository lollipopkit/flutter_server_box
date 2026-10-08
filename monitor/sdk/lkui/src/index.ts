/// `lkui`: what an installed desk app uses of the desk,
/// from inside its sandboxed frame (docs/dev/desk-sys.md).
///
///   import { connect } from 'lkui'
///   const desk = await connect() // the desk's styles and theme are on the page
///   document.body.innerHTML = '<button class="lk-btn lk-btn--primary">Run</button>'
///   desk.toolbar({ actions: [{ id: 'refresh', label: 'Refresh', icon: 'refresh' }] })
///   desk.on('action', ({ id }) => …)

import { PROTOCOL, type AppTheme, type MenuDescription, type ToolbarDescription } from './protocol.js'
import { applyTheme, useStylesheet } from './ui.js'

export type { ActionItem, AppTheme, MenuDescription, ToolbarDescription } from './protocol.js'

export type Lifecycle = 'active' | 'visible' | 'background' | 'suspended'

export interface Hello {
  protocol: number
  appId: string
  windowId: string
  appState: unknown
  lifecycle: Lifecycle
  theme: AppTheme
  locale: string
  /// The desk's design system for this frame (`_desk/desk.css` under the
  /// app's own path); absent from a desk before it served one.
  ui?: { stylesheet: string } | null
  /// What the admin approved that the desk itself grants (`notifications`,
  /// `background`).
  permissions: string[]
}

export interface Intent {
  action: string
  data?: unknown
  /// The app that sent it; null when the desk did (Files, Spotlight).
  from: string | null
}

export interface Events {
  lifecycle: Lifecycle
  theme: AppTheme
  locale: string
  intent: Intent
  /// A toolbar button or menu row the app described was used.
  action: { id: string }
}

/// Thrown for a refusal: `notPermitted`, `tooLarge`, `busy`, a backend's own code…
export class DeskError extends Error {}

export interface Desk {
  readonly info: Hello
  on<E extends keyof Events>(event: E, handler: (data: Events[E]) => void): () => void
  setTitle(title: string | null): Promise<void>
  setAppName(name: string | null): Promise<void>
  setIcon(icon: { glyph: string; tone: string } | null): Promise<void>
  setBadge(badge: string | number | null): Promise<void>
  /// Small JSON (≤16 KiB, never secrets) the window comes back with.
  setAppState(state: unknown): Promise<void>
  toolbar(toolbar: ToolbarDescription): Promise<void>
  menus(menus: MenuDescription[]): Promise<void>
  notify(notice: { title: string; body?: string; level?: 'info' | 'warning' | 'critical' }): Promise<void>
  readonly storage: {
    get<T = unknown>(key: string): Promise<T | undefined>
    set(key: string, value: unknown): Promise<void>
    remove(key: string): Promise<void>
    keys(): Promise<string[]>
  }
  /// Opens another app; the only intent an installed app may hand on is the
  /// desk's `open` of a path.
  open(appId: string, options?: { newWindow?: boolean; path?: { path: string; kind: 'file' | 'dir' } }): Promise<boolean>
  handlers(path: string, kind: 'file' | 'dir'): Promise<{ id: string; title: string }[]>
  /// Keeps running while hidden until the returned function is called (or
  /// 10 minutes pass). Needs `background`.
  keepAlive(reason: string): Promise<() => Promise<void>>
  close(): Promise<void>
  /// Calls the app's backend (`kind: wasm`), as the signed-in account.
  backend<T = unknown>(method: string, params?: unknown): Promise<T>
}

/// Where the desk's port arrives: this frame's window, from its parent.
export interface Channel {
  parent: unknown
  self: {
    addEventListener(type: 'message', listener: (e: MessageEvent) => void): void
  }
}

/// The app's end of its channel to the desk (a `MessagePort`).
interface Port {
  postMessage(message: unknown): void
  onmessage: ((e: MessageEvent) => void) | null
}

/// The port the desk hands this page once it has loaded.
function portFrom(channel: Channel): Promise<Port> {
  return new Promise((resolve) => {
    channel.self.addEventListener('message', (e: MessageEvent) => {
      const m = e.data as { sbm?: number; event?: string } | null
      if (e.source === channel.parent && m?.sbm === PROTOCOL && m.event === 'connect' && e.ports[0]) resolve(e.ports[0])
    })
  })
}

export interface ConnectOptions {
  /// Put the desk's design system on the page and keep it in the desk's
  /// mode and theme (default). Off for an app that draws itself entirely.
  style?: boolean
  /// Where the desk's port arrives; for tests.
  channel?: Channel
}

/// Connects to the desk this frame runs in; by default the page is in the
/// desk's design system once this resolves (`ui.ts`).
export async function connect(options: ConnectOptions = {}): Promise<Desk> {
  const port = await portFrom(options.channel ?? { parent: window.parent, self: window as unknown as Channel['self'] })
  let next = 1
  const waiting = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>()
  const listeners = new Map<string, Set<(data: unknown) => void>>()

  port.onmessage = (e: MessageEvent) => {
    const m = e.data as { sbm?: number; re?: number; ok?: boolean; value?: unknown; error?: string; event?: string; data?: unknown }
    if (!m || m.sbm !== PROTOCOL) return
    if (typeof m.re === 'number') {
      const w = waiting.get(m.re)
      if (!w) return
      waiting.delete(m.re)
      if (m.ok) w.resolve(m.value)
      else w.reject(new DeskError(m.error ?? 'failed'))
    } else if (typeof m.event === 'string') {
      for (const f of listeners.get(m.event) ?? []) f(m.data)
    }
  }

  function call<T = unknown>(name: string, args?: unknown): Promise<T> {
    const id = next++
    return new Promise<T>((resolve, reject) => {
      waiting.set(id, { resolve: resolve as (v: unknown) => void, reject })
      port.postMessage({ sbm: PROTOCOL, id, call: name, args })
    })
  }

  const info = await call<Hello>('hello')
  if (options.style !== false) {
    applyTheme(info.theme)
    const set = listeners.get('theme') ?? new Set()
    set.add((theme) => applyTheme(theme as AppTheme))
    listeners.set('theme', set)
    if (info.ui?.stylesheet) await useStylesheet(info.ui.stylesheet)
  }
  let keep = 0

  return {
    info,
    on(event, handler) {
      const set = listeners.get(event) ?? new Set()
      set.add(handler as (data: unknown) => void)
      listeners.set(event, set)
      return () => set.delete(handler as (data: unknown) => void)
    },
    setTitle: (title) => call('setTitle', { title }),
    setAppName: (name) => call('setAppName', { name }),
    setIcon: (icon) => call('setIcon', icon ?? { glyph: null }),
    setBadge: (badge) => call('setBadge', { badge }),
    setAppState: (state) => call('setAppState', { state }),
    toolbar: (toolbar) => call('toolbar', toolbar),
    menus: (menus) => call('menus', { menus }),
    notify: (notice) => call('notify', notice),
    storage: {
      get: (key) => call('storage.get', { key }),
      set: (key, value) => call('storage.set', { key, value }),
      remove: (key) => call('storage.remove', { key }),
      keys: () => call('storage.keys'),
    },
    open: (appId, options) =>
      call('open', {
        appId,
        newWindow: options?.newWindow === true,
        intent: options?.path ? { action: 'open', data: options.path } : undefined,
      }),
    handlers: (path, kind) => call('handlers', { path, kind }),
    async keepAlive(reason) {
      const token = `k${++keep}`
      await call('keepAlive', { token, reason })
      return () => call('release', { token })
    },
    close: () => call('close'),
    backend: (method, params) => call('backend.call', { method, params: params ?? null }),
  }
}
