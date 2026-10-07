/// Where one server's desk is kept: on its agent (`desk` feature), or in this
/// browser for an agent without it. The desk's stores talk to this and never
/// to `deskApi` directly, so the fallback is one class and not a branch in
/// each of them.

import type { ServerEntry } from '../lib/servers.svelte'
import { deskApi, readEvents, type DeskNotification, type DeskPreferences, type SessionSave, type StoredSession } from './deskApi'

export interface DeskStorage {
  /// Whether this is the agent's (shared by every browser) or this browser's.
  readonly remote: boolean
  /// Whether `background` is kept (an older agent's storage drops it).
  readonly keepsBackground: boolean
  /// What an app keeps for itself (`sys.storage`), all of it.
  appItems(app: string): Promise<Record<string, unknown>>
  appPut(app: string, key: string, value: unknown): Promise<void>
  appRemove(app: string, key: string): Promise<void>
  load(): Promise<{ preferences: DeskPreferences | null; wallpaperSha: string | null }>
  savePreferences(p: DeskPreferences): Promise<void>
  loadSession(device: string): Promise<StoredSession>
  saveSession(device: string, expected: number, session: Omit<StoredSession, 'revision'>): Promise<SessionSave>
  wallpaperUrl(): Promise<string | null>
  putWallpaper(file: Blob): Promise<void>
  deleteWallpaper(): Promise<void>
  notifications(): Promise<{ notifications: DeskNotification[]; unread: number }>
  markRead(read: { ids: number[] } | { all: true }): Promise<void>
  /// Resolves when the stream ends; null where there is none.
  events: ((signal: AbortSignal, onEvent: (e: Record<string, unknown>) => void) => Promise<void>) | null
}

export class AgentStorage implements DeskStorage {
  readonly remote = true
  readonly keepsBackground: boolean
  #entry: ServerEntry

  /// Where apps keep their own data when the agent cannot (no
  /// `desk_storage`). TODO: remove once agents without it are gone.
  #appFallback: BrowserStorage | null

  /// [keepsBackground]: the agent stores `background` (`desk_background`);
  /// an older one refuses preferences carrying it. [keepsAppData]: it has
  /// `/desk/apps/{app}/storage` (`desk_storage`).
  constructor(entry: ServerEntry, keepsBackground: boolean, keepsAppData: boolean) {
    // A copy: the session token it was made with is the one it keeps using.
    this.#entry = { ...entry }
    this.keepsBackground = keepsBackground
    this.#appFallback = keepsAppData ? null : new BrowserStorage(entry.id)
  }

  async appItems(app: string) {
    if (this.#appFallback) return this.#appFallback.appItems(app)
    return (await deskApi.appItems(this.#entry, app)).items
  }
  async appPut(app: string, key: string, value: unknown) {
    if (this.#appFallback) return this.#appFallback.appPut(app, key, value)
    await deskApi.appPut(this.#entry, app, key, value)
  }
  async appRemove(app: string, key: string) {
    if (this.#appFallback) return this.#appFallback.appRemove(app, key)
    await deskApi.appRemove(this.#entry, app, key)
  }

  async load() {
    const view = await deskApi.get(this.#entry)
    return { preferences: view.preferences, wallpaperSha: view.wallpaper_sha256 }
  }
  async savePreferences(p: DeskPreferences) {
    if (this.keepsBackground) {
      await deskApi.putPreferences(this.#entry, p)
    } else {
      // TODO: remove once agents without `desk_background` are gone.
      const { background: _, background_denied: __, ...older } = p
      await deskApi.putPreferences(this.#entry, older as DeskPreferences)
    }
  }
  loadSession(device: string) {
    return deskApi.getSession(this.#entry, device)
  }
  saveSession(device: string, expected: number, session: Omit<StoredSession, 'revision'>) {
    return deskApi.putSession(this.#entry, device, expected, session)
  }
  wallpaperUrl() {
    return deskApi.wallpaperUrl(this.#entry)
  }
  async putWallpaper(file: Blob) {
    await deskApi.putWallpaper(this.#entry, file)
  }
  deleteWallpaper() {
    return deskApi.deleteWallpaper(this.#entry)
  }
  notifications() {
    return deskApi.notifications(this.#entry)
  }
  markRead(read: { ids: number[] } | { all: true }) {
    return deskApi.markRead(this.#entry, read)
  }
  events = (signal: AbortSignal, onEvent: (e: Record<string, unknown>) => void) =>
    readEvents(this.#entry, signal, onEvent)
}

/// This browser's copy, for an agent that keeps no desk. No custom wallpaper
/// (an image does not belong in `localStorage`) and nothing to be told.
const MAX_APP_BYTES = 256 * 1024

function bytes(text: string): number {
  return new TextEncoder().encode(text).length
}

export class BrowserStorage implements DeskStorage {
  readonly remote = false
  readonly keepsBackground = true
  #key: string

  constructor(serverId: string) {
    this.#key = `desk.v1:${serverId}`
  }

  #read<T>(part: string): T | null {
    try {
      const raw = window.localStorage.getItem(`${this.#key}:${part}`)
      return raw ? (JSON.parse(raw) as T) : null
    } catch {
      return null
    }
  }

  #write(part: string, value: unknown) {
    try {
      window.localStorage.setItem(`${this.#key}:${part}`, JSON.stringify(value))
    } catch {
      // Full or refused: the desk keeps working, unsaved.
    }
  }

  async appItems(app: string) {
    return this.#read<Record<string, unknown>>(`app:${app}`) ?? {}
  }
  async appPut(app: string, key: string, value: unknown) {
    const items = { ...(await this.appItems(app)), [key]: value }
    // The agent's bound (`api::desk_storage`), counted the same way.
    const size = Object.entries(items).reduce((n, [k, v]) => n + bytes(k) + bytes(JSON.stringify(v)), 0)
    if (size > MAX_APP_BYTES) throw new Error('tooLarge')
    this.#write(`app:${app}`, items)
  }
  async appRemove(app: string, key: string) {
    const items = { ...(await this.appItems(app)) }
    delete items[key]
    this.#write(`app:${app}`, items)
  }

  async load() {
    return { preferences: this.#read<DeskPreferences>('preferences'), wallpaperSha: null }
  }
  async savePreferences(p: DeskPreferences) {
    this.#write('preferences', p)
  }
  async loadSession(device: string) {
    return (
      this.#read<StoredSession>(`session:${device}`) ?? { revision: 0, active_window_id: null, windows: [] }
    )
  }
  async saveSession(device: string, expected: number, session: Omit<StoredSession, 'revision'>): Promise<SessionSave> {
    const current = await this.loadSession(device)
    if (current.revision !== expected) return { ok: false, current }
    const revision = expected + 1
    this.#write(`session:${device}`, { ...session, revision })
    return { ok: true, revision }
  }
  async wallpaperUrl() {
    return null
  }
  async putWallpaper() {
    throw new Error('unsupported')
  }
  async deleteWallpaper() {}
  async notifications() {
    return { notifications: [], unread: 0 }
  }
  async markRead() {}
  events = null
}

/// This browser's id, so a phone and a desktop keep their own windows. Not a
/// secret: it only names which arrangement is whose.
export function deviceId(): string {
  const KEY = 'desk.device'
  try {
    const known = window.localStorage.getItem(KEY)
    if (known && /^[A-Za-z0-9_-]{1,64}$/.test(known)) return known
    const id = typeof crypto.randomUUID === 'function' ? crypto.randomUUID() : `d${Date.now().toString(36)}`
    window.localStorage.setItem(KEY, id)
    return id
  } catch {
    return 'default'
  }
}
