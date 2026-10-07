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
import type { AppSpec } from './sys/manifest'
import { WINDOW, type LifecycleState, type WindowHandle } from './sys/window.svelte'
import type { DeskNotification } from './deskApi'
import type { MenuEntry } from './lk/Menu.svelte'
import { DeskNotifications } from './notifications.svelte'
import { DeskPrefs } from './prefs.svelte'
import { SessionSync } from './session.svelte'
import { AgentStorage, BrowserStorage, deviceId, type DeskStorage } from './storage'
import type { AppIconChrome, WindowChrome } from './window/chrome.svelte'
import { WindowManager, type DeskWindow, type OpenOptions } from './windows.svelte'

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
  notifications = $state<DeskNotifications | null>(null)

  panel = $state<Panel | null>(null)
  spotlight = $state(false)
  menu = $state<ContextMenu | null>(null)
  /// Connected to the agent's event stream (the menubar's dot).
  live = $state(false)
  /// The lock screen is over the desk.
  locked = $state(false)
  /// The browser tab is hidden.
  hidden = $state(typeof document !== 'undefined' && document.visibilityState === 'hidden')
  /// Each open window's frame (what its app registered), by window id.
  readonly chromes = new SvelteMap<string, WindowChrome>()

  #abort = new AbortController()

  constructor(entry: ServerEntry) {
    this.entry = { ...entry }
  }

  get caps(): Capabilities | undefined {
    return capabilitiesStore.byServer[this.entry.id]
  }

  get apps(): AppSpec[] {
    return availableApps(this.caps)
  }

  /// Whether a hidden app keeps running (Settings → General).
  get backgroundAllowed(): boolean {
    return this.prefs?.value.background ?? true
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
  appChrome(appId: string): { icon: AppIconChrome | null; badge: string | null } {
    const newest = this.windows.of(appId).reduce<DeskWindow | null>((a, w) => (!a || w.z > a.z ? w : a), null)
    const chrome = newest ? this.chromes.get(newest.id) : undefined
    return { icon: chrome?.icon ?? null, badge: chrome?.badge ?? null }
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
      ? new AgentStorage(this.entry, this.caps.features.includes('desk_background'))
      : new BrowserStorage(this.entry.id)
    this.storage = storage
    this.prefs = new DeskPrefs(storage)
    this.notifications = new DeskNotifications(storage)
    this.session = new SessionSync(this.windows, storage, deviceId(), this.entry.id)
    await Promise.all([this.prefs.load(), this.session.load(), this.notifications.load()])
    if (storage.events) void this.#listen(storage)
  }

  /// Opens [appId] if this server and account may use it.
  open(appId: string, options?: OpenOptions): string | null {
    const spec = app(appId)
    if (!spec || !spec.available(this.caps)) return null
    this.panel = null
    this.spotlight = false
    return this.windows.open(appId, options)
  }

  showMenu(event: MouseEvent, items: MenuItem[]) {
    event.preventDefault()
    event.stopPropagation()
    this.menu = { x: event.clientX, y: event.clientY, items }
  }

  togglePanel(panel: Panel) {
    this.panel = this.panel === panel ? null : panel
    this.spotlight = false
  }

  /// Saves what is pending and stops listening: the desk is going away.
  async stop() {
    this.#abort.abort()
    this.prefs?.close()
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
        void this.prefs?.load()
        break
      case 'resync':
        void this.prefs?.load()
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
    open: (appId, options) => desk.open(appId, options),
    addPathIcon: (path, label) => {
      const appId = desk.windows.get(id)?.appId
      if (!appId) return
      desk.prefs?.addIcon({ kind: 'path', app_id: appId, server_id: desk.entry.id, path, label: label.slice(0, 64) })
    },
    get active() {
      return desk.windows.active?.id === id
    },
    get lifecycle() {
      return lifecycle()
    },
  }
  setContext(WINDOW, handle)
}

/// The desk's preferences (wallpaper, background apps), for the Settings app
/// only — no other app touches them. Null until they have loaded.
export function useDeskPrefs(): { readonly prefs: DeskPrefs | null } {
  const desk = getContext<Desk | undefined>(DESK)
  return {
    get prefs() {
      return desk?.prefs ?? null
    },
  }
}
