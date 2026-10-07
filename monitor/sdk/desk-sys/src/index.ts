/// `@lollipopkit/desk-sys`: what an installed desk app uses of the desk,
/// from inside its sandboxed frame (docs/dev/desk-sys.md).
///
///   import { connect } from '@lollipopkit/desk-sys'
///   const desk = await connect()
///   desk.toolbar({ actions: [{ id: 'refresh', label: 'Refresh', icon: 'refresh' }] })
///   desk.on('action', ({ id }) => …)

import { PROTOCOL, type MenuDescription, type ToolbarDescription } from './protocol'

export type { ActionItem, MenuDescription, ToolbarDescription } from './protocol'

export type Lifecycle = 'active' | 'visible' | 'background' | 'suspended'

export interface Hello {
  protocol: number
  appId: string
  windowId: string
  appState: unknown
  lifecycle: Lifecycle
  theme: { dark: boolean }
  locale: string
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
  theme: { dark: boolean }
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

/// The window an app's messages go to, and come from: its parent (the desk).
export interface Channel {
  parent: { postMessage(message: unknown, targetOrigin: string): void }
  self: {
    addEventListener(type: 'message', listener: (e: MessageEvent) => void): void
  }
}

/// Connects to the desk this frame runs in. [channel] is for tests.
export async function connect(channel?: Channel): Promise<Desk> {
  const { parent, self }: Channel = channel ?? { parent: window.parent, self: window as unknown as Channel['self'] }
  let next = 1
  const waiting = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>()
  const listeners = new Map<string, Set<(data: unknown) => void>>()

  self.addEventListener('message', (e: MessageEvent) => {
    if (e.source !== parent) return
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
  })

  function call<T = unknown>(name: string, args?: unknown): Promise<T> {
    const id = next++
    return new Promise<T>((resolve, reject) => {
      waiting.set(id, { resolve: resolve as (v: unknown) => void, reject })
      parent.postMessage({ sbm: PROTOCOL, id, call: name, args }, '*')
    })
  }

  const info = await call<Hello>('hello')
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
