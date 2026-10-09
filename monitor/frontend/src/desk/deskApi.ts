/// The agent's `/api/v1/desk*` (`monitor/src/api/desk.rs`), always to an
/// explicit server: a desk saves to the server it was opened for, even while
/// the panel is switching to another.

import { ApiError, readEventStream, requestFor } from '../lib/api'
import { isSecureAgentUrl } from '../lib/agentUrl'
import type { InstalledApp } from '../types'
import type { ServerEntry } from '../lib/servers.svelte'
import type { StoredWindow } from './windows.svelte'

export interface DeskIcon {
  id: string
  kind: 'app' | 'path'
  app_id: string
  server_id?: string | null
  path?: string | null
  label: string
  col?: number | null
  row?: number | null
}

export interface DeskPreferences {
  accent: string | null
  /// `preset:<id>`, `custom`, or `theme` (the selected theme's background).
  wallpaper: string
  wallpaper_fit: 'cover' | 'contain' | 'fill'
  dock: string[]
  icons: DeskIcon[]
  /// Hidden apps keep running; off suspends them (`docs/dev/desk-sys.md`).
  background: boolean
  /// Apps suspended when hidden even while [background] is on.
  background_denied: string[]
  /// The installed theme the desk is drawn with: `<installation>` or
  /// `<installation>#<variant>`; null for the design system's own
  /// (`/desk/themes`).
  theme?: string | null
}

/// A color as a theme writes one: ARGB, or a palette role.
export type ThemeColor = number | string

/// One theme of an installed package (`fl_theme::Theme`): the package, or
/// one of its variants.
export interface PackageTheme {
  variant: { key: string; name: string } | null
  modes: ('light' | 'dark')[]
  /// The initial preference: 0 system, 1 light, 2 dark.
  mode: 0 | 1 | 2
  seed: number
  schemeLight: Record<string, number>
  schemeDark: Record<string, number>
  /// The accent and neutral palettes by tone.
  accentTones: Record<string, number>
  neutralTones: Record<string, number>
  background: { style: 'none' | 'gradient' | 'image'; opacity: number; blur: number; tile: number }
  shapes: { card: number; tile: number; button: number }
  /// `[components]` as the app reads them (`themeComponents`).
  components: Record<string, unknown>
  density: string | null
}

export interface ThemePackage {
  installationId: string
  id: string
  name: string
  schemaMin: number
  schemaMax: number
  themes: PackageTheme[]
}

export interface InstalledTheme {
  installationId: string
  id: string
  name: string
  installedAt: string
  package: ThemePackage
}

export interface StoreRelease {
  version: string
  schemaMin: number
  schemaMax: number
  url: string | null
  path: string | null
  sha256: string | null
  size: number | null
  notes: string | null
}

export interface StoreItem {
  repo: string
  repoUrl: string
  listing: {
    id: string
    name: string
    /// One string, or one per language tag (`zh-tw`, `zh`, `en`).
    description: string | Record<string, string>
    homepage: string | null
    license: string | null
    releases: StoreRelease[]
  }
  /// The newest version the agent installs; null when all need newer.
  release: StoreRelease | null
}

export interface ThemeStoreView {
  catalog: string | null
  repos: string[]
  items: StoreItem[]
  fetchedAt: string
}

export interface DeskView {
  preferences: DeskPreferences | null
  wallpaper_sha256: string | null
  presets: string[]
}

export interface StoredSession {
  revision: number
  active_window_id: string | null
  windows: StoredWindow[]
}

export type SessionSave = { ok: true; revision: number } | { ok: false; current: StoredSession }

export interface DeskNotification {
  id: number
  created_at: string
  level: 'info' | 'warning' | 'critical'
  source: string
  subject: string
  body: string
  read: boolean
}

export const deskApi = {
  get: (entry: ServerEntry) => requestFor<DeskView>(entry, '/desk', {}, 'Failed to load the desk'),

  putPreferences: (entry: ServerEntry, preferences: DeskPreferences) =>
    requestFor<DeskPreferences>(
      entry,
      '/desk/preferences',
      { method: 'PUT', body: JSON.stringify(preferences) },
      'Failed to save the desk',
    ),

  getSession: (entry: ServerEntry, device: string) =>
    requestFor<StoredSession>(
      entry,
      `/desk/session?device=${encodeURIComponent(device)}`,
      {},
      'Failed to load the windows',
    ),

  /// Saves from [expected]; a 409 answers what is current instead.
  async putSession(
    entry: ServerEntry,
    device: string,
    expected: number,
    session: Omit<StoredSession, 'revision'>,
  ): Promise<SessionSave> {
    try {
      const { revision } = await requestFor<{ revision: number }>(
        entry,
        '/desk/session',
        {
          method: 'PUT',
          body: JSON.stringify({ device, expected_revision: expected, ...session }),
        },
        'Failed to save the windows',
      )
      return { ok: true, revision }
    } catch (e) {
      if (e instanceof ApiError && e.status === 409 && e.body?.current) {
        return { ok: false, current: e.body.current as StoredSession }
      }
      throw e
    }
  },

  appItems: (entry: ServerEntry, app: string) =>
    requestFor<{ items: Record<string, unknown> }>(entry, `/desk/apps/${encodeURIComponent(app)}/storage`, {}, 'Failed to load'),

  appPut: (entry: ServerEntry, app: string, key: string, value: unknown) =>
    requestFor<void>(
      entry,
      `/desk/apps/${encodeURIComponent(app)}/storage?key=${encodeURIComponent(key)}`,
      { method: 'PUT', body: JSON.stringify(value) },
      'Failed to save',
    ),

  appRemove: (entry: ServerEntry, app: string, key: string) =>
    requestFor<void>(
      entry,
      `/desk/apps/${encodeURIComponent(app)}/storage?key=${encodeURIComponent(key)}`,
      { method: 'DELETE' },
      'Failed to save',
    ),

  /// The apps installed on the agent (`api::apps`); an admin also sees those
  /// waiting for approval.
  apps: (entry: ServerEntry) => requestFor<{ apps: InstalledApp[] }>(entry, '/apps', {}, 'Failed to load the apps'),

  /// Where an installed app's UI loads from (a ticketed path).
  launchApp: (entry: ServerEntry, id: string) =>
    requestFor<{ url: string; version: string; stylesheet?: string }>(entry, `/apps/${encodeURIComponent(id)}/launch`, {}, 'Failed to open the app'),

  /// Runs [method] of an installed app's backend (`kind: wasm`) as the
  /// signed-in account; answers the backend's own reply.
  callApp: (entry: ServerEntry, id: string, method: string, params: unknown) =>
    requestFor<{ ok?: unknown; error?: string }>(
      entry,
      `/apps/${encodeURIComponent(id)}/call`,
      { method: 'POST', body: JSON.stringify({ method, params: params ?? null }) },
      'The app’s backend failed',
      undefined,
      60_000,
    ),

  notifications: (entry: ServerEntry, limit = 80) =>
    requestFor<{ notifications: DeskNotification[]; unread: number }>(
      entry,
      `/desk/notifications?limit=${limit}`,
      {},
      'Failed to load notifications',
    ),

  markRead: (entry: ServerEntry, read: { ids: number[] } | { all: true }) =>
    requestFor<void>(
      entry,
      '/desk/notifications/read',
      { method: 'POST', body: JSON.stringify(read) },
      'Failed to mark notifications read',
    ),

  /// The custom wallpaper as an object URL (an `<img>` cannot send the
  /// bearer header). The caller revokes it.
  async wallpaperUrl(entry: ServerEntry): Promise<string | null> {
    const res = await raw(entry, '/desk/wallpaper', { method: 'GET' })
    if (res.status === 404) return null
    if (!res.ok) throw new ApiError('Failed to load the wallpaper', res.status)
    return URL.createObjectURL(await res.blob())
  },

  async putWallpaper(entry: ServerEntry, file: Blob): Promise<string> {
    const res = await raw(entry, '/desk/wallpaper', { method: 'PUT', body: file })
    if (!res.ok) {
      let code: string | undefined
      try {
        code = ((await res.json()) as { error?: string }).error
      } catch {
        // No body to read.
      }
      throw new ApiError(code ?? 'Failed to save the wallpaper', res.status, code)
    }
    return ((await res.json()) as { sha256: string }).sha256
  },

  async deleteWallpaper(entry: ServerEntry): Promise<void> {
    const res = await raw(entry, '/desk/wallpaper', { method: 'DELETE' })
    if (!res.ok) throw new ApiError('Failed to remove the wallpaper', res.status)
  },

  themes: (entry: ServerEntry) => requestFor<InstalledTheme[]>(entry, '/desk/themes', {}, 'Failed to load the themes'),

  /// Installs a `.fsbt`; a refused package throws with the reason the app's
  /// installer would give (`code` `invalidTheme`).
  async installTheme(entry: ServerEntry, file: Blob): Promise<InstalledTheme> {
    const res = await raw(entry, '/desk/themes', { method: 'POST', body: file })
    return themeAnswer(res, 'Failed to install the theme')
  },

  async removeTheme(entry: ServerEntry, installation: string): Promise<void> {
    const res = await raw(entry, `/desk/themes/${encodeURIComponent(installation)}`, { method: 'DELETE' })
    if (!res.ok && res.status !== 404) throw new ApiError('Failed to remove the theme', res.status)
  },

  /// A theme's background as an object URL; null when it has none.
  async themeBackgroundUrl(entry: ServerEntry, installation: string, variant: string | null): Promise<string | null> {
    const query = variant ? `?variant=${encodeURIComponent(variant)}` : ''
    const res = await raw(entry, `/desk/themes/${encodeURIComponent(installation)}/background${query}`, { method: 'GET' })
    if (res.status === 404) return null
    if (!res.ok) throw new ApiError('Failed to load the theme background', res.status)
    return URL.createObjectURL(await res.blob())
  },

  themeStore: (entry: ServerEntry, refresh = false) =>
    requestFor<ThemeStoreView>(
      entry,
      `/desk/themes/store${refresh ? '?refresh=1' : ''}`,
      {},
      'Failed to read the theme store',
      undefined,
      120_000,
    ),

  async installFromStore(entry: ServerEntry, item: StoreItem, version: string): Promise<InstalledTheme> {
    const res = await raw(entry, '/desk/themes/store/install', {
      method: 'POST',
      body: JSON.stringify({ repo: item.repoUrl, id: item.listing.id, version }),
      headers: { 'content-type': 'application/json' },
    })
    return themeAnswer(res, 'Failed to install the theme')
  },
}

/// An install's answer, or its refusal: `reason` (the package's or the
/// store's own words) as the message.
async function themeAnswer(res: Response, fallback: string): Promise<InstalledTheme> {
  let body: { error?: string; reason?: string } & Partial<InstalledTheme> = {}
  try {
    body = await res.json()
  } catch {
    // No body to read.
  }
  if (!res.ok) throw new ApiError(body.reason ?? body.error ?? fallback, res.status, body.error)
  return body as InstalledTheme
}

async function raw(entry: ServerEntry, path: string, init: RequestInit): Promise<Response> {
  if (!isSecureAgentUrl(entry.url)) throw new ApiError('Remote monitor agents require HTTPS; HTTP is allowed only on loopback.')
  const headers: Record<string, string> = { ...(init.headers as Record<string, string> | undefined) }
  if (entry.token) headers.Authorization = `Bearer ${entry.token}`
  try {
    return await fetch(`${entry.url}/api/v1${path}`, { ...init, headers, signal: AbortSignal.timeout(120_000) })
  } catch {
    throw new ApiError('Request failed')
  }
}

/// Reads `/desk/events` until [signal] aborts or the stream ends, calling
/// [onEvent] with each parsed `data:` line. Throws on a refused or broken
/// stream; the caller decides when to try again.
export function readEvents(
  entry: ServerEntry,
  signal: AbortSignal,
  onEvent: (event: Record<string, unknown>) => void,
): Promise<void> {
  return readEventStream(entry, '/desk/events', signal, onEvent)
}

