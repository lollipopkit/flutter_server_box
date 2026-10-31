/// `serverbox-desk`: what an installed desk app uses of the desk,
/// from inside its sandboxed frame (docs/dev/desk-sys.md).
///
///   import { connect } from 'serverbox-desk'
///   const desk = await connect() // the desk's styles and theme are on the page
///   document.body.innerHTML = '<button class="lk-btn lk-btn--primary">Run</button>'
///   desk.toolbar({ actions: [{ id: 'refresh', label: 'Refresh', icon: 'refresh' }] })
///   desk.on('action', ({ id }) => …)
///   desk.sidebar({ sections: [{ items: [{ id: 'status', label: 'Status', icon: 'info' }] }], selected: 'status' })
///   desk.on('navigate', ({ id }) => …)

import { PROTOCOL, type AppTheme, type JobView, type MenuDescription, type SidebarDescription, type SudoAsk, type ToolbarDescription } from './protocol.js'
import { applyTheme, useStylesheet } from './ui.js'

export type { ActionItem, AppTheme, JobView, MenuDescription, SidebarDescription, SidebarItem, SidebarSection, SudoAsk, ToolbarDescription } from './protocol.js'
export { translator, type Dictionary, type Translate } from './i18n.js'
export { formatBytes, formatDate, formatTime } from './format.js'

export type Lifecycle = 'active' | 'visible' | 'background' | 'suspended'

export interface Hello {
  protocol: number
  appId: string
  windowId: string
  appState: unknown
  lifecycle: Lifecycle
  theme: AppTheme
  locale: string
  /// The desk's design system for this frame (the agent's
  /// `/desk-app/desk.css`); absent from a desk before it served one.
  ui?: { stylesheet: string } | null
  /// What was approved that the desk itself grants (`notifications`,
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
  /// A place in the app's sidebar was chosen.
  navigate: { id: string }
}

/// Thrown for a refusal: `notPermitted`, `tooLarge`, `busy`, a backend's own
/// code (gRPC's: `invalidArgument`, `failedPrecondition`, …) with its words
/// in [detail]; `declined` when the sudo dialog was closed.
export class DeskError extends Error {
  constructor(
    code: string,
    readonly detail?: string,
  ) {
    super(code)
  }
}

export interface CallOptions {
  /// Runs as root: the desk's dialog says this first.
  sudo?: SudoAsk
}

export interface JobOptions extends CallOptions {
  /// Each line of the job's log as it comes.
  onLine?: (text: string) => void
  /// How often the job is read while it runs (ms, default 1000).
  every?: number
}

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
  /// The app's places, drawn as the window's sidebar; `navigate` says which
  /// one was chosen. Send it again with `selected` when the app moves itself.
  sidebar(sidebar: SidebarDescription): Promise<void>
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
  /// A function of the backend's `api` (`kind: wasm`), by name, with its
  /// parameters by name; its value.
  call<T = unknown>(fn: string, args?: Record<string, unknown>, options?: CallOptions): Promise<T>
  /// One of the backend's `jobs`: started, its lines to `onLine`, its value
  /// once it ends. One job at a time per app.
  job<T = unknown>(fn: string, args?: Record<string, unknown>, options?: JobOptions): Promise<T>
  /// The job running now or the last one (after the window reopened), from
  /// line [since].
  jobView(since?: number): Promise<JobView | null>
  /// Follows the job running now until it ends; as `job`.
  follow<T = unknown>(options?: Omit<JobOptions, 'sudo'>): Promise<T>
  /// Asks the running job to stop.
  cancelJob(): Promise<void>
  /// Opens a web page (http or https) in a tab of its own: links in the
  /// app's frame cannot open one themselves.
  openUrl(url: string): Promise<void>
  /// The desk's own dialog to restart (or shut down) the machine, which the
  /// user confirms there. Needs `root`.
  power(action?: 'reboot' | 'shutdown'): Promise<void>
  /// The desk's own page for one of the agent's model server stacks
  /// (Ollama, llama.cpp, vLLM, SGLang: `ollama.ollama`, `ggml.llama_cpp`,
  /// `vllm.vllm`, `sglang.sglang`) in a sheet over the window, set up with
  /// [setup]'s model and backend (`cuda`, `rocm`, `vulkan`, `cpu`) when it
  /// is not deployed; the account confirms there. Settles once it is
  /// closed. Needs `process`.
  openStack(id: string, setup?: { model?: string | null; backend?: string }): Promise<void>
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
      else w.reject(new DeskError(m.error ?? 'failed', (m as { message?: string }).message))
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

  async function follow<T>(options: Omit<JobOptions, 'sudo'> = {}, since = 0): Promise<T> {
    for (;;) {
      const view = await call<JobView | null>('backend.jobView', { since })
      if (!view) throw new DeskError('notFound')
      for (const l of view.lines) options.onLine?.(l.text)
      since = view.next
      if (view.state === 'succeeded') return view.value as T
      if (view.state !== 'running') throw new DeskError(view.error?.error ?? view.state, view.error?.message)
      await new Promise((r) => setTimeout(r, options.every ?? 1000))
    }
  }

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
    sidebar: (sidebar) => call('sidebar', sidebar),
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
    call: (fn, args, options) => call('backend.call', { function: fn, args: args ?? {}, sudo: options?.sudo }),
    async job(fn, args, options = {}) {
      const started = await call<JobView>('backend.job', { function: fn, args: args ?? {}, sudo: options.sudo })
      void started
      return follow(options)
    },
    jobView: (since = 0) => call('backend.jobView', { since }),
    follow: (options) => follow(options),
    cancelJob: () => call('backend.cancel'),
    power: (action = 'reboot') => call('power', { action }),
    openUrl: (url) => call('openUrl', { url }),
    openStack: (id, setup = {}) => call('openStack', { id, model: setup.model ?? null, backend: setup.backend ?? 'cpu' }),
  }
}
