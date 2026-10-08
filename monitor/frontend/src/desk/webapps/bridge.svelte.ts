/// The desk's side of an installed app's frame: answers its calls with what
/// its window handle allows and its approved permissions grant, and tells it
/// what changes (lifecycle, theme, locale, intents, its buttons used).
///
/// It talks over one `MessagePort` handed to the page the frame first loaded
/// (`attach`): a page the frame navigates to later has no port, so it never
/// reaches the bridge, and the window tears the frame down when it sees the
/// second load. Everything from the port is untrusted: shapes and sizes are
/// checked here, one message at a time. Nothing secret is ever sent.

import { SvelteMap } from 'svelte/reactivity'
import type { WindowHandle } from '../sys/window.svelte'
import type { Intent } from '../windows.svelte'
import type { MenuEntry } from '../lk/Menu.svelte'
import type { IconTone } from '../lk/AppIcon.svelte'
import { isCall, PROTOCOL, type ActionItem, type AppTheme, type Event, type MenuDescription, type Reply, type ToolbarDescription } from '../../../../sdk/desk-sys/src/protocol'

const MAX_MESSAGE_BYTES = 1 << 20
const MAX_IN_FLIGHT = 32
const MAX_ITEMS = 64
const MAX_MENUS = 8
const MAX_LABEL = 80
const MAX_KEEP_ALIVE = 4
const MAX_APP_STATE = 16 * 1024
const TONES: IconTone[] = ['berry', 'soft', 'ink', 'sky', 'teal', 'violet', 'amber', 'leaf', 'pale', 'bright', 'mist']
const MAX_OPENS = 3
const OPEN_WINDOW_MS = 10_000
/// As `sys.useLifecycle().keepAlive`.
const KEEP_ALIVE_MAX_MS = 10 * 60_000

function text(value: unknown, max: number): string | undefined {
  return typeof value === 'string' ? value.slice(0, max) : undefined
}

function glyph(value: unknown): string | undefined {
  return typeof value === 'string' && /^[a-z0-9_]{1,64}$/.test(value) ? value : undefined
}

function actionItems(value: unknown): ActionItem[] {
  if (!Array.isArray(value)) return []
  return value.slice(0, MAX_ITEMS).flatMap((raw): ActionItem[] => {
    const v = raw as Record<string, unknown> | null
    if (!v || typeof v !== 'object') return []
    if (v.separator === true) return [{ id: '', label: '', separator: true }]
    const id = text(v.id, 64)
    const label = text(v.label, MAX_LABEL)
    if (!id || !label) return []
    return [
      {
        id,
        label,
        icon: glyph(v.icon),
        shortcut: text(v.shortcut, 8),
        checked: v.checked === true,
        disabled: v.disabled === true,
        danger: v.danger === true,
      },
    ]
  })
}

/// The desk's end of the frame's channel (a `MessagePort`).
export interface BridgePort {
  postMessage(message: unknown): void
  onmessage: ((e: MessageEvent) => void) | null
  close?(): void
}

export interface BridgeHost {
  handle: WindowHandle
  /// Whether the app's approved permissions include [permission].
  allows(permission: string): boolean
  /// Light or dark, and the panel's language, as they change.
  theme(): AppTheme
  locale(): string
  /// The desk's design system served to this frame, once launched.
  stylesheet?(): string | null
  /// Runs [method] of the app's backend, when it has one.
  backend?: (method: string, params: unknown) => Promise<{ ok?: unknown; error?: string }>
}

export class WebAppBridge {
  /// What the app asked the desk to draw for it.
  toolbar = $state<ToolbarDescription>({})
  menus = $state<MenuDescription[]>([])
  /// The frame said it is listening.
  ready = $state(false)

  #host: BridgeHost
  #port: BridgePort | null = null
  #opens: number[] = []
  #inFlight = 0
  #keepAlive = new SvelteMap<string, () => void>()
  #pending: Event[] = []

  constructor(host: BridgeHost) {
    this.#host = host
  }

  /// Talks over [port] from now on (the frame's first page holds the other end).
  attach(port: BridgePort) {
    this.#port = port
    port.onmessage = (e) => void this.receive(e.data)
  }

  /// A row or button the desk drew was used.
  action(id: string) {
    this.send('action', { id })
  }

  /// Rows for `useMenus`, each sending its id back.
  menuEntries(): { label: string; items: MenuEntry[] }[] {
    return this.menus.map((m) => ({
      label: m.label,
      items: m.items.map((i): MenuEntry =>
        i.separator
          ? { separator: true }
          : { label: i.label, icon: i.icon, shortcut: i.shortcut, checked: i.checked, disabled: i.disabled, danger: i.danger, action: () => this.action(i.id) },
      ),
    }))
  }

  intent(intent: Intent) {
    this.send('intent', { action: intent.action, data: intent.data, from: intent.from ?? null })
  }

  /// Sends [event] once the frame is ready; until then they wait, in order.
  send(event: string, data?: unknown) {
    const message: Event = { sbm: PROTOCOL, event, data }
    if (!this.ready) {
      this.#pending.push(message)
      return
    }
    this.#post(message)
  }

  /// One message from the port.
  async receive(data: unknown) {
    if (!this.#port || !isCall(data)) return
    const call = data
    if (this.#inFlight >= MAX_IN_FLIGHT) return this.#reply({ sbm: PROTOCOL, re: call.id, ok: false, error: 'busy' })
    let size: number
    try {
      size = JSON.stringify(call.args ?? null).length
    } catch {
      return this.#reply({ sbm: PROTOCOL, re: call.id, ok: false, error: 'invalidArgs' })
    }
    if (size > MAX_MESSAGE_BYTES) return this.#reply({ sbm: PROTOCOL, re: call.id, ok: false, error: 'tooLarge' })
    this.#inFlight++
    try {
      const value = await this.#answer(call.call, call.args)
      this.#reply({ sbm: PROTOCOL, re: call.id, ok: true, value })
    } catch (err) {
      this.#reply({ sbm: PROTOCOL, re: call.id, ok: false, error: err instanceof Error ? err.message : 'failed' })
    } finally {
      this.#inFlight--
    }
  }

  /// The frame is going away (or left its page): nothing more is heard.
  close() {
    if (this.#port) {
      this.#port.onmessage = null
      this.#port.close?.()
      this.#port = null
    }
    for (const release of this.#keepAlive.values()) release()
    this.#keepAlive.clear()
  }

  async #answer(name: string, args: unknown): Promise<unknown> {
    const h = this.#host.handle
    const a = (args ?? {}) as Record<string, unknown>
    switch (name) {
      case 'hello': {
        this.ready = true
        const pending = this.#pending
        this.#pending = []
        queueMicrotask(() => pending.forEach((m) => this.#post(m)))
        return {
          protocol: PROTOCOL,
          appId: h.appId,
          windowId: h.id,
          appState: h.appState,
          lifecycle: h.lifecycle,
          theme: this.#host.theme(),
          locale: this.#host.locale(),
          ui: this.#host.stylesheet?.() ? { stylesheet: this.#host.stylesheet!() } : null,
          permissions: ['notifications', 'background'].filter((p) => this.#host.allows(p)),
        }
      }
      case 'setTitle':
        return h.setTitle(a.title === null ? null : (text(a.title, MAX_LABEL) ?? null))
      case 'setAppName':
        return h.setAppName(a.name === null ? null : (text(a.name, 64) ?? null))
      case 'setIcon': {
        const g = glyph(a.glyph)
        const tone = TONES.find((t) => t === a.tone)
        return h.setIcon(g && tone ? { glyph: g, tone } : null)
      }
      case 'setBadge':
        return h.setBadge(typeof a.badge === 'number' || typeof a.badge === 'string' ? a.badge : null)
      case 'setAppState':
        // The agent keeps 16 KiB per window; more would fail the whole
        // desk's session save.
        if (JSON.stringify(a.state ?? null).length > MAX_APP_STATE) throw new Error('tooLarge')
        return h.setAppState(JSON.parse(JSON.stringify(a.state ?? null)))
      case 'toolbar':
        this.toolbar = { title: text(a.title, MAX_LABEL), subtitle: text(a.subtitle, MAX_LABEL), actions: actionItems(a.actions) }
        return
      case 'menus':
        this.menus = (Array.isArray(a.menus) ? a.menus : []).slice(0, MAX_MENUS).flatMap((raw) => {
          const m = raw as Record<string, unknown> | null
          const label = text(m?.label, 32)
          return label ? [{ label, items: actionItems(m?.items) }] : []
        })
        return
      case 'notify':
        if (!this.#host.allows('notifications')) throw new Error('notPermitted')
        return h.notify({ title: text(a.title, 200) ?? '', body: text(a.body, 2000), level: a.level as never })
      case 'storage.get':
        return h.storage.get(String(a.key))
      case 'storage.set':
        return h.storage.set(String(a.key), a.value)
      case 'storage.remove':
        return h.storage.remove(String(a.key))
      case 'storage.keys':
        return h.storage.keys()
      case 'open': {
        // Another app, as itself; the only intent it may hand on is the
        // desk's `open` of a path, never a request another app acts on.
        // Opening another app takes the focus (and the keyboard): not a
        // thing to do in a loop.
        const now = Date.now()
        this.#opens = this.#opens.filter((t) => now - t < OPEN_WINDOW_MS)
        if (this.#opens.length >= MAX_OPENS) throw new Error('busy')
        this.#opens.push(now)
        const appId = String(a.appId)
        const intent = a.intent as { action?: unknown; data?: unknown } | undefined
        if (intent && intent.action !== 'open') throw new Error('notPermitted')
        const data = intent?.data as { path?: unknown; kind?: unknown } | undefined
        const open = intent
          ? { action: 'open', data: { path: String(data?.path ?? ''), kind: data?.kind === 'dir' ? 'dir' : 'file' } }
          : undefined
        return h.open(appId, { newWindow: a.newWindow === true, intent: open }) !== null
      }
      case 'handlers':
        return h.handlers(String(a.path), a.kind === 'dir' ? 'dir' : 'file').map((x) => ({ id: x.id, title: x.title }))
      case 'keepAlive': {
        if (!this.#host.allows('background')) throw new Error('notPermitted')
        const token = text(a.token, 64)
        if (!token || !h.chrome || this.#keepAlive.size >= MAX_KEEP_ALIVE) throw new Error('invalidArgs')
        this.#keepAlive.get(token)?.()
        const release = h.chrome.holdKeepAlive(text(a.reason, MAX_LABEL) ?? '')
        const timer = setTimeout(release, KEEP_ALIVE_MAX_MS)
        this.#keepAlive.set(token, () => {
          clearTimeout(timer)
          release()
        })
        return
      }
      case 'release': {
        const token = text(a.token, 64) ?? ''
        this.#keepAlive.get(token)?.()
        this.#keepAlive.delete(token)
        return
      }
      case 'backend.call': {
        const method = text(a.method, 64)
        if (!method || !this.#host.backend) throw new Error('noBackend')
        const reply = await this.#host.backend(method, a.params ?? null)
        if (reply && typeof reply === 'object' && 'error' in reply && reply.error !== undefined) throw new Error(String(reply.error))
        return reply?.ok ?? null
      }
      case 'close':
        return h.close()
      default:
        throw new Error('unknownCall')
    }
  }

  #reply(reply: Reply) {
    this.#post(reply)
  }

  #post(message: Reply | Event) {
    this.#port?.postMessage(message)
  }
}
