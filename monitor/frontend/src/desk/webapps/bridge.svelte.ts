/// The desk's side of an installed app's frame: answers its calls with what
/// its window handle allows and its approved permissions grant, and tells it
/// what changes (lifecycle, theme, locale, intents, its buttons used).
///
/// Everything from the frame is untrusted: shapes and sizes are checked here,
/// one message at a time; a message from any window but the frame's is
/// ignored. Nothing secret is ever sent to it.

import { SvelteMap } from 'svelte/reactivity'
import type { WindowHandle } from '../sys/window.svelte'
import type { Intent } from '../windows.svelte'
import type { MenuEntry } from '../lk/Menu.svelte'
import { isCall, PROTOCOL, type ActionItem, type Event, type MenuDescription, type Reply, type ToolbarDescription } from './protocol'

const MAX_MESSAGE_BYTES = 1 << 20
const MAX_IN_FLIGHT = 32
const MAX_ITEMS = 64
const MAX_MENUS = 8
const MAX_LABEL = 80
const MAX_KEEP_ALIVE = 4
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

export interface BridgeHost {
  handle: WindowHandle
  /// Whether the app's approved permissions include [permission].
  allows(permission: string): boolean
  /// Light or dark, and the panel's language, as they change.
  theme(): { dark: boolean }
  locale(): string
}

export class WebAppBridge {
  /// What the app asked the desk to draw for it.
  toolbar = $state<ToolbarDescription>({})
  menus = $state<MenuDescription[]>([])
  /// The frame said it is listening.
  ready = $state(false)

  #host: BridgeHost
  #frame: () => Window | null
  #inFlight = 0
  #keepAlive = new SvelteMap<string, () => void>()
  #pending: Event[] = []

  constructor(host: BridgeHost, frame: () => Window | null) {
    this.#host = host
    this.#frame = frame
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

  /// The window's `message` listener.
  async receive(e: MessageEvent) {
    const frame = this.#frame()
    if (!frame || e.source !== frame) return
    if (!isCall(e.data)) return
    const call = e.data
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

  /// The frame is going away.
  close() {
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
          permissions: ['notifications', 'background'].filter((p) => this.#host.allows(p)),
        }
      }
      case 'setTitle':
        return h.setTitle(a.title === null ? null : (text(a.title, MAX_LABEL) ?? null))
      case 'setAppName':
        return h.setAppName(a.name === null ? null : (text(a.name, 64) ?? null))
      case 'setIcon': {
        const g = glyph(a.glyph)
        return h.setIcon(g && typeof a.tone === 'string' ? { glyph: g, tone: a.tone as never } : null)
      }
      case 'setBadge':
        return h.setBadge(typeof a.badge === 'number' || typeof a.badge === 'string' ? a.badge : null)
      case 'setAppState':
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
    // An opaque origin cannot be named; the message goes to this frame's
    // window only, and carries nothing the app may not see.
    this.#frame()?.postMessage(message, '*')
  }
}
