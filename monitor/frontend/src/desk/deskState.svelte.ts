/// One server's desk: its windows, preferences, notifications and the shell's
/// own state (which panel is open, Spotlight, a context menu). Made by
/// `Desk.svelte` for the server it shows and reached by every part of the
/// shell through [useDesk]; an app reaches its own window through
/// `sys` and nothing else of the desk.

import { getContext, setContext } from 'svelte'
import { SvelteMap } from 'svelte/reactivity'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import type { ServerEntry } from '../lib/servers.svelte'
import type { Capabilities } from '../types'
import './apps'
import { app, availableApps } from './registry.svelte'
import { opensPath, type AppSpec } from './sys/manifest'
import { WINDOW, type LifecycleState, type WindowHandle } from './sys/window.svelte'
import { systemPrefs } from './sys/systemPrefs.svelte'
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import type { DeskNotification } from './deskApi'
import type { IconTone } from './lk/AppIcon.svelte'
import type { MenuEntry } from './lk/Menu.svelte'
import { AppData } from './appData'
import { AgentStore } from './agent/agentStore.svelte'
import { registerWebApps } from './webapps/register'
import { DeskNotifications } from './notifications.svelte'
import { DeskPrefs } from './prefs.svelte'
import { DeskThemes } from './themes.svelte'
import { SessionSync } from './session.svelte'
import { AgentStorage, BrowserStorage, deviceId, type DeskStorage } from './storage'
import type { AppIconChrome, WindowChrome } from './window/chrome.svelte'
import { WindowManager, type DeskWindow, type Intent, type OpenOptions } from './windows.svelte'
import { merge, panesOf, readLayout, removeTab, writeLayout, type Layout, type Placement, type Side } from './panes'

/// A drop that merges a dragged window into another (see `Desk.paneDrop`).
export type PaneDrop =
  | { windowId: string; kind: 'tab' }
  | { windowId: string; kind: 'split'; paneId: string; side: Side }

export type Panel = 'control' | 'notifications' | 'calendar' | 'launchpad'

/// A context menu's rows (`lk/Menu.svelte`); icons are glyph names.
export type MenuItem = MenuEntry

export interface ContextMenu {
  x: number
  y: number
  items: MenuItem[]
  /// [y] is where the menu ends rather than starts (the dock's, which opens
  /// upwards).
  above?: boolean
  /// [x] is where the menu ends rather than starts (under the bar's right side).
  end?: boolean
  /// The menubar title that opened it, so moving along the bar switches.
  owner?: string
}

const RETRY_MIN_MS = 1000
const RETRY_MAX_MS = 30_000

export class Desk {
  readonly entry: ServerEntry
  readonly windows = new WindowManager((id) => app(id))
  storage = $state<DeskStorage | null>(null)
  session = $state<SessionSync | null>(null)
  prefs = $state<DeskPrefs | null>(null)
  /// Installed themes, where the agent keeps them (`/desk/themes`).
  themes = $state<DeskThemes | null>(null)
  notifications = $state<DeskNotifications | null>(null)
  appData = $state.raw<AppData | null>(null)

  panel = $state<Panel | null>(null)
  spotlight = $state(false)
  menu = $state<ContextMenu | null>(null)
  /// Connected to the agent's event stream (the menubar's dot).
  live = $state(false)
  /// The lock screen is over the desk.
  locked = $state(false)
  /// The browser tab is hidden.
  hidden = $state(typeof document !== 'undefined' && document.visibilityState === 'hidden')
  /// Agent mode is over the desk (`agent/AgentMode.svelte`).
  agentMode = $state(false)
  /// Agent mode's tasks, from the first time it opens until the desk goes.
  agent = $state.raw<AgentStore | null>(null)
  /// The window each app notification came from, by notification id.
  readonly noticeWindows = new SvelteMap<number, string>()
  /// Each open window's frame (what its app registered), by window id.
  readonly chromes = new SvelteMap<string, WindowChrome>()
  /// Where a window being dragged would merge if let go now: into another
  /// window of its app with panes, as a tab or beside one of its panes. The
  /// target draws it (`window/PaneHost.svelte`).
  paneDrop = $state<PaneDrop | null>(null)

  #abort = new AbortController()
  #offWebApps: (() => void) | null = null
  #intents = new SvelteMap<string, Intent[]>()

  constructor(entry: ServerEntry) {
    this.entry = { ...entry }
  }

  get caps(): Capabilities | undefined {
    return capabilitiesStore.byServer[this.entry.id]
  }

  get apps(): AppSpec[] {
    return availableApps(this.caps)
  }

  /// Whether a hidden window of [appId] keeps running (Settings → Apps; an
  /// installed app also needs the `background` permission).
  mayRunHidden(appId: string): boolean {
    if (!this.allows(appId, 'background')) return false
    const p = this.prefs?.value
    return !p || (p.background && !p.background_denied.includes(appId))
  }

  /// Whether [appId] may use [permission]: a built-in app always, an
  /// installed one when its approved permissions list it.
  allows(appId: string, permission: string): boolean {
    const spec = app(appId)
    return !!spec && (spec.kind === 'system' || (spec.permissions ?? []).includes(permission))
  }

  /// Hidden from the user: minimised, behind the front window on a phone,
  /// or the whole desk out of sight.
  isHidden(id: string): boolean {
    const w = this.windows.get(id)
    if (!w) return true
    if (w.minimized || this.locked || this.hidden) return true
    return this.windows.compact && this.windows.active?.id !== id
  }

  /// What the app's newest window set for its icon and badge, for the dock.
  appChrome(appId: string): { icon: AppIconChrome | null; badge: string | null; dockItems: MenuEntry[] } {
    const newest = this.windows.of(appId).reduce<DeskWindow | null>((a, w) => (!a || w.z > a.z ? w : a), null)
    const chrome = newest ? this.chromes.get(newest.id) : undefined
    return { icon: chrome?.icon ?? null, badge: chrome?.badge ?? null, dockItems: chrome?.dockItems ?? [] }
  }

  /// Whether a window of [appId] is still loading the app's code.
  launching(appId: string): boolean {
    return this.windows.of(appId).some((w) => this.chromes.get(w.id)?.launching)
  }

  /// Who a notification is from, as the banner and the centre show it.
  noticeSource(n: DeskNotification): { appId: string; title: string; glyph: string; tone: IconTone } {
    const appId = n.source.startsWith('app:') ? n.source.slice(4) : 'status'
    const spec = app(appId)
    if (appId !== 'status' && spec) return { appId, title: spec.title(get(LL)), glyph: spec.glyph, tone: spec.tone }
    // The agent's own: its alerts, shown as the Status app's by level.
    const level = { info: ['info', 'sky'], warning: ['warning', 'amber'], critical: ['error', 'berry'] } as const
    const [glyph, tone] = level[n.level] ?? level.info
    return { appId: 'status', title: get(LL).deskAppStatus(), glyph, tone }
  }

  /// A notification was clicked: the window that posted it comes forward, or
  /// its app opens.
  openNotice(n: DeskNotification) {
    void this.notifications?.markRead(n.id)
    const windowId = this.noticeWindows.get(n.id)
    if (windowId && this.windows.get(windowId)) {
      this.panel = null
      this.windows.focus(windowId)
    } else {
      this.open(this.noticeSource(n).appId)
    }
  }

  /// The windows running out of sight (hidden, not suspended).
  get inBackground(): DeskWindow[] {
    return this.windows.windows.filter((w) => this.chromes.get(w.id)?.lifecycle === 'background')
  }

  /// The front window's frame.
  get activeChrome(): WindowChrome | undefined {
    const id = this.windows.active?.id
    return id ? this.chromes.get(id) : undefined
  }

  get ready(): boolean {
    return this.session?.status === 'ready' || this.session?.status === 'failed'
  }

  /// Loads what this desk keeps, then listens for what changes it.
  async start() {
    await capabilitiesStore.ensure(this.entry.id)
    if (this.#abort.signal.aborted) return
    const storage: DeskStorage = this.caps?.features?.includes('desk')
      ? new AgentStorage(this.entry)
      : new BrowserStorage(this.entry.id)
    this.storage = storage
    this.prefs = new DeskPrefs(storage)
    this.themes = storage.keepsThemes ? new DeskThemes(this.entry, this.prefs) : null
    this.notifications = new DeskNotifications(storage)
    this.appData = new AppData(storage)
    this.session = new SessionSync(this.windows, storage, deviceId(), this.entry.id)
    // Installed apps first: a restored window of one needs it registered.
    await this.reloadWebApps()
    const system = systemPrefs.value
    await Promise.all([
      this.prefs.load(),
      this.session.load(system.restoreWindows),
      this.notifications.load(),
      this.themes?.load(),
    ])
    if (this.#abort.signal.aborted) return
    // Nothing came back: the app this browser opens at start.
    if (this.windows.windows.length === 0 && system.openOnStart !== 'none') this.open(system.openOnStart)
    if (storage.events) void this.#listen(storage)
  }

  /// Reads the installed apps again (one approved or removed in Settings).
  async reloadWebApps() {
    if (!this.caps?.features?.includes('desk')) return
    try {
      const off = await registerWebApps(this.entry, () => this.#offWebApps?.())
      if (this.#abort.signal.aborted) off()
      else this.#offWebApps = off
    } catch {
      // The desk works without them; they come back on the next start.
    }
  }

  /// Opens [appId] if this server and account may use it. [from] is the app
  /// asking, stamped on its intent.
  open(appId: string, options?: OpenOptions, from?: string): string | null {
    const spec = app(appId)
    if (!spec || !spec.available(this.caps)) return null
    this.panel = null
    this.spotlight = false
    // A window opened is a window to see.
    this.agentMode = false
    const id = this.windows.open(appId, options)
    if (id && options?.intent) {
      const intent: Intent = { action: String(options.intent.action), data: options.intent.data, from }
      const chrome = this.chromes.get(id)
      if (chrome) chrome.deliver(intent)
      else this.#intents.set(id, [...(this.#intents.get(id) ?? []), intent])
    }
    return id
  }

  /// Merges window [sourceId] into the window [drop] names: its tabs and
  /// panes, with their ids, move there and it goes without being closed, so
  /// what its panes hold open (a terminal's session) is rejoined.
  mergeWindow(sourceId: string, drop: PaneDrop) {
    const source = this.windows.get(sourceId)
    const target = this.windows.get(drop.windowId)
    if (!source || !target || source === target || source.appId !== target.appId) return
    if (!app(source.appId)?.panes) return
    const placement: Placement =
      drop.kind === 'tab' ? { kind: 'tab' } : { kind: 'split', paneId: drop.paneId, side: drop.side }
    const merged = merge(readLayout(target.appState, target.id), readLayout(source.appState, source.id), placement)
    this.windows.setAppState(target.id, writeLayout(merged))
    this.windows.absorb(source.id)
    this.windows.focus(target.id)
  }

  /// Takes tab [tabId] out of window [windowId] into a window of its own at
  /// [at] (the pointer). Not for a window's only tab: dragging the window is
  /// that. False when the app is at its window limit.
  detachTab(windowId: string, tabId: string, at: { x: number; y: number }): boolean {
    const w = this.windows.get(windowId)
    if (!w) return false
    const layout = readLayout(w.appState, w.id)
    const tab = layout.tabs.find((t) => t.id === tabId)
    const rest = removeTab(layout, tabId)
    if (!tab || !rest) return false
    const own: Layout = { tabs: [tab], tab: tab.id, focus: panesOf(tab.root)[0].id }
    const id = this.windows.open(w.appId, { newWindow: true, appState: writeLayout(own) })
    const opened = id ? this.windows.get(id) : undefined
    if (!opened || opened.id === w.id) return false
    this.windows.setAppState(w.id, writeLayout(rest))
    this.windows.place(opened.id, { ...opened.rect, x: Math.round(at.x - 80), y: Math.round(at.y - 16) })
    return true
  }

  /// Intents for a window opened just now, before its frame existed.
  takeIntents(windowId: string): Intent[] {
    const intents = this.#intents.get(windowId) ?? []
    this.#intents.delete(windowId)
    return intents
  }

  showMenu(event: MouseEvent, items: MenuItem[]) {
    event.preventDefault()
    event.stopPropagation()
    this.menu = { x: event.clientX, y: event.clientY, items }
  }

  /// Whether this agent runs Agent mode and the account may use it (`shell`).
  get agentAvailable(): boolean {
    const caps = this.caps
    return !!caps?.features?.includes('agent_mode') && caps.grants?.shell?.ok === true
  }

  /// Turns Agent mode on or off; the windows stay as they are.
  toggleAgent(on = !this.agentMode) {
    if (on && !this.agentAvailable) return
    if (on && !this.agent) this.agent = new AgentStore(this.entry)
    this.agentMode = on
    this.panel = null
    this.spotlight = false
    this.menu = null
  }

  togglePanel(panel: Panel) {
    this.panel = this.panel === panel ? null : panel
    this.spotlight = false
  }

  /// Saves what is pending and stops listening: the desk is going away.
  async stop() {
    this.#abort.abort()
    this.agent?.stop()
    this.#offWebApps?.()
    this.#offWebApps = null
    this.prefs?.close()
    this.themes?.close()
    this.notifications?.close()
    await this.session?.close()
  }

  async #listen(storage: DeskStorage) {
    let wait = RETRY_MIN_MS
    while (!this.#abort.signal.aborted) {
      const opened = Date.now()
      try {
        await storage.events!(this.#abort.signal, (e) => {
          this.live = true
          this.#event(e)
        })
      } catch {
        // Refused or dropped: tried again below.
      }
      this.live = false
      if (this.#abort.signal.aborted) return
      // A stream that stayed up a while starts the wait over.
      if (Date.now() - opened > RETRY_MAX_MS) wait = RETRY_MIN_MS
      await new Promise((r) => setTimeout(r, wait))
      wait = Math.min(wait * 2, RETRY_MAX_MS)
      // Whatever was said while away is fetched rather than replayed.
      void this.notifications?.load()
    }
  }

  #event(e: Record<string, unknown>) {
    switch (e.type) {
      case 'notification':
        this.notifications?.arrived(e.notification as DeskNotification)
        break
      case 'session':
        void this.session?.remoteChanged(String(e.device), Number(e.revision))
        break
      case 'preferences':
        // A theme installed or removed elsewhere says so this way too.
        void this.prefs?.load()
        void this.themes?.load()
        break
      case 'resync':
        void this.prefs?.load()
        void this.themes?.load()
        void this.notifications?.load()
        break
    }
  }
}

const DESK = Symbol('desk')

export function provideDesk(desk: Desk) {
  setContext(DESK, desk)
}

export function useDesk(): Desk {
  const desk = getContext<Desk | undefined>(DESK)
  if (!desk) throw new Error('useDesk outside a desk')
  return desk
}

/// Gives the window's app its `sys` handle (`sys/window.svelte.ts`).
/// [lifecycle] is the window's state as the window works it out.
export function provideWindow(desk: Desk, id: string, chrome: WindowChrome, lifecycle: () => LifecycleState) {
  const handle: WindowHandle = {
    id,
    get appId() {
      return desk.windows.get(id)?.appId ?? ''
    },
    chrome,
    get appState() {
      return desk.windows.get(id)?.appState ?? null
    },
    setAppState: (state) => desk.windows.setAppState(id, state),
    setTitle: (title) => desk.windows.setTitle(id, title),
    setAppName: (name) => (chrome.appName = name === null ? null : String(name).slice(0, 64)),
    setIcon: (icon) => (chrome.icon = icon && { glyph: String(icon.glyph), tone: icon.tone }),
    setBadge: (badge) => (chrome.badge = badge === null || badge === '' ? null : String(badge).slice(0, 8)),
    close: () => desk.windows.close(id),
    open: (appId, options) => desk.open(appId, options, desk.windows.get(id)?.appId),
    openWindow: (appState) => {
      const appId = desk.windows.get(id)?.appId
      return appId ? desk.open(appId, { newWindow: true, appState }, appId) : null
    },
    get canOpenWindow() {
      const appId = desk.windows.get(id)?.appId
      const spec = appId ? app(appId) : undefined
      return !!spec && desk.windows.of(spec.id).length < spec.instances
    },
    notify: (notice) => {
      const appId = desk.windows.get(id)?.appId
      if (!appId || !desk.allows(appId, 'notifications')) return
      const n = desk.notifications?.posted(appId, notice)
      if (n) desk.noticeWindows.set(n.id, id)
    },
    handlers: (path, kind) => {
      const self = desk.windows.get(id)?.appId
      const ll = get(LL)
      return desk.apps
        .filter((a) => a.id !== self && opensPath(a.opens, path, kind))
        .map((a) => ({ id: a.id, title: a.title(ll), glyph: a.glyph, tone: a.tone }))
    },
    get storage() {
      const appId = desk.windows.get(id)?.appId
      if (!appId || !desk.appData) throw new Error('storage before the desk loaded')
      return desk.appData.for(appId)
    },
    addPathIcon: (path, label) => {
      const appId = desk.windows.get(id)?.appId
      if (!appId) return
      desk.prefs?.addIcon({ kind: 'path', app_id: appId, server_id: desk.entry.id, path, label: label.slice(0, 64) })
    },
    get active() {
      return desk.windows.active?.id === id
    },
    get closed() {
      return desk.windows.wasClosed(id)
    },
    get lifecycle() {
      return lifecycle()
    },
    // A pane's handle has them (`window/PaneHost.svelte`); the window's not.
    panes: null,
  }
  setContext(WINDOW, handle)
}

/// Settings → Apps showing [appId]'s own page: it runs as that app (its
/// storage, its notifications) while its toolbar and window are Settings'.
export function provideAppSettings(desk: Desk, appId: string, settings: WindowHandle) {
  const handle: WindowHandle = {
    ...settings,
    appId,
    get appState() {
      return null
    },
    setAppState() {},
    setAppName() {},
    setIcon() {},
    setBadge() {},
    get active() {
      return settings.active
    },
    get lifecycle() {
      return settings.lifecycle
    },
    notify: (notice) => {
      desk.notifications?.posted(appId, notice)
    },
    handlers: () => [],
    get storage() {
      if (!desk.appData) throw new Error('storage before the desk loaded')
      return desk.appData.for(appId)
    },
    addPathIcon() {},
  }
  setContext(WINDOW, handle)
}

/// The desk's preferences (wallpaper, background apps), for the Settings app
/// only — no other app touches them. Null until they have loaded.
export function useDeskPrefs(): {
  readonly prefs: DeskPrefs | null
  /// Installed themes; null where the agent keeps none.
  readonly themes: DeskThemes | null
  readonly notifications: DeskNotifications | null
  readonly apps: AppSpec[]
  reloadApps(): Promise<void>
} {
  const desk = getContext<Desk | undefined>(DESK)
  return {
    get prefs() {
      return desk?.prefs ?? null
    },
    get themes() {
      return desk?.themes ?? null
    },
    /// Do Not Disturb lives here.
    get notifications() {
      return desk?.notifications ?? null
    },
    /// The apps this account can use here.
    get apps() {
      return desk?.apps ?? []
    },
    reloadApps: async () => desk?.reloadWebApps(),
  }
}
