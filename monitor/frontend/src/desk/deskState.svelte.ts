/// One server's desk: its windows, preferences, notifications and the shell's
/// own state (which panel is open, Spotlight, a context menu). Made by
/// `Desk.svelte` for the server it shows and reached by every part of the
/// shell through [useDesk]; an app reaches its own window through
/// [useWindow] and nothing else of the desk.

import { getContext, setContext } from 'svelte'
import type { Component } from 'svelte'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import type { ServerEntry } from '../lib/servers.svelte'
import type { Capabilities } from '../types'
import { app, availableApps, type AppSpec } from './apps'
import type { DeskNotification } from './deskApi'
import { DeskNotifications } from './notifications.svelte'
import { DeskPrefs } from './prefs.svelte'
import { SessionSync } from './session.svelte'
import { AgentStorage, BrowserStorage, deviceId, type DeskStorage } from './storage'
import { WindowManager, type OpenOptions } from './windows.svelte'

export type Panel = 'control' | 'notifications' | 'calendar' | 'launchpad'

export type MenuItem =
  | {
      label: string
      icon?: Component
      shortcut?: string
      checked?: boolean
      disabled?: boolean
      danger?: boolean
      action: () => void
    }
  | { separator: true }

export interface ContextMenu {
  x: number
  y: number
  items: MenuItem[]
  /// [y] is where the menu ends rather than starts (the dock's, which opens
  /// upwards).
  above?: boolean
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
const WINDOW = Symbol('desk-window')

export function provideDesk(desk: Desk) {
  setContext(DESK, desk)
}

export function useDesk(): Desk {
  const desk = getContext<Desk | undefined>(DESK)
  if (!desk) throw new Error('useDesk outside a desk')
  return desk
}

/// What an app may do with the window it is in.
export interface WindowHandle {
  readonly id: string
  /// What the app saved for itself; null on a fresh window.
  readonly appState: unknown
  setAppState(state: unknown): void
  /// Replaces the app's title in the title bar, the dock menu and Spotlight.
  setTitle(title: string | null): void
  close(): void
  /// Opens another app (or another window of one) on this desk. Answers the
  /// window's id, or null when the app is not available or at its limit.
  open(appId: string, options?: OpenOptions): string | null
  /// Puts an icon on the desk that opens [path] with this window's app.
  addPathIcon(path: string, label: string): void
  readonly active: boolean
}

export function provideWindow(desk: Desk, id: string) {
  const handle: WindowHandle = {
    id,
    get appState() {
      return desk.windows.get(id)?.appState ?? null
    },
    setAppState: (state) => desk.windows.setAppState(id, state),
    setTitle: (title) => desk.windows.setTitle(id, title),
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
  }
  setContext(WINDOW, handle)
}

/// The window the calling component is in. Outside one (a test rendering an
/// app alone) it answers a handle that does nothing.
export function useWindow(): WindowHandle {
  return (
    getContext<WindowHandle | undefined>(WINDOW) ?? {
      id: '',
      appState: null,
      setAppState() {},
      setTitle() {},
      close() {},
      open: () => null,
      addPathIcon() {},
      active: true,
    }
  )
}

/// The desk's appearance (accent, wallpaper, custom image), for the Settings
/// app's Appearance section only — no other app touches the desk's
/// preferences. Null until they have loaded.
export function useDeskAppearance(): { readonly prefs: DeskPrefs | null } {
  const desk = getContext<Desk | undefined>(DESK)
  return {
    get prefs() {
      return desk?.prefs ?? null
    },
  }
}
