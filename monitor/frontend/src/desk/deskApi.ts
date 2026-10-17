/// The agent's `/api/v1/desk*` (`monitor/src/api/desk.rs`), always to an
/// explicit server: a desk saves to the server it was opened for, even while
/// the panel is switching to another.

import { ApiError, errorFrom, errorFromBody, fetchFor, readEventStream, requestFor } from '../lib/api'
import type { ErrorBody } from '../lib/api'
import type { InstalledApp } from '../types'
import type { JobView as AppJobView } from '../../../sdk/serverbox-desk/src/protocol'
import type { ServerEntry } from '../lib/servers.svelte'
import type { StoredWindow } from './windows.svelte'

/// sudo's password for one call or job, from the desk's dialog: empty uses
/// the one the agent remembers.
export interface AppSudo {
  password: string | null
  remember: boolean
}

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
  /// When the account walked through or skipped the first-run guide; null
  /// shows it. Absent on an agent from before it (shown once per browser).
  onboarded_at?: string | null
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
  kind?: string | null
  params?: Record<string, unknown> | null
  read: boolean
}

export const deskApi = {
  get: (entry: ServerEntry) => requestFor<DeskView>(entry, '/desk', {}),

  putPreferences: (entry: ServerEntry, preferences: DeskPreferences) =>
    requestFor<DeskPreferences>(
      entry,
      '/desk/preferences',
      { method: 'PUT', body: JSON.stringify(preferences) },
    ),

  /// The first-run guide done with, or offered again.
  setOnboarded: (entry: ServerEntry, done: boolean) =>
    requestFor<void>(entry, '/desk/onboarding', { method: done ? 'PUT' : 'DELETE' }),

  getSession: (entry: ServerEntry, device: string) =>
    requestFor<StoredSession>(
      entry,
      `/desk/session?device=${encodeURIComponent(device)}`,
      {},
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
    requestFor<{ items: Record<string, unknown> }>(entry, `/desk/apps/${encodeURIComponent(app)}/storage`, {}),

  appPut: (entry: ServerEntry, app: string, key: string, value: unknown) =>
    requestFor<void>(
      entry,
      `/desk/apps/${encodeURIComponent(app)}/storage?key=${encodeURIComponent(key)}`,
      { method: 'PUT', body: JSON.stringify(value) },
    ),

  appRemove: (entry: ServerEntry, app: string, key: string) =>
    requestFor<void>(
      entry,
      `/desk/apps/${encodeURIComponent(app)}/storage?key=${encodeURIComponent(key)}`,
      { method: 'DELETE' },
    ),

  /// The apps installed on the agent (`api::apps`), approved or waiting.
  apps: (entry: ServerEntry) => requestFor<{ apps: InstalledApp[] }>(entry, '/apps', {}),

  /// Where an installed app's UI loads from (a ticketed path).
  launchApp: (entry: ServerEntry, id: string) =>
    requestFor<{ url: string; version: string; stylesheet?: string }>(entry, `/apps/${encodeURIComponent(id)}/launch`, {}),

  /// One of an installed app's backend's `api` functions (`kind: wasm`),
  /// as the signed-in account: `{ value }`. [sudo] only after the desk's own
  /// dialog asked for it.
  callApp: (entry: ServerEntry, id: string, fn: string, args: unknown, sudo?: AppSudo) =>
    requestFor<{ value: unknown }>(
      entry,
      `/apps/${encodeURIComponent(id)}/call`,
      { method: 'POST', body: JSON.stringify({ function: fn, args: args ?? {}, sudo }) },
      undefined,
      // The agent ends a call after 60 s.
      70_000,
    ),

  /// Starts one of its `jobs`; its view.
  startAppJob: (entry: ServerEntry, id: string, fn: string, args: unknown, sudo?: AppSudo) =>
    requestFor<AppJobView>(entry, `/apps/${encodeURIComponent(id)}/jobs`, {
      method: 'POST',
      body: JSON.stringify({ function: fn, args: args ?? {}, sudo }),
    }),

  /// Its job running now or its last, lines from [since]; null when it has
  /// had none since the agent started.
  appJob: async (entry: ServerEntry, id: string, since: number) => {
    try {
      return await requestFor<AppJobView>(entry, `/apps/${encodeURIComponent(id)}/jobs?since=${since}`, {})
    } catch (e) {
      if (e instanceof ApiError && e.status === 404) return null
      throw e
    }
  },

  cancelAppJob: (entry: ServerEntry, id: string) =>
    requestFor<AppJobView>(entry, `/apps/${encodeURIComponent(id)}/jobs/cancel`, { method: 'POST' }),

  /// Whether the agent keeps a sudo password for this account (Agent mode's
  /// and the apps', 15 minutes).
  sudoRemembered: (entry: ServerEntry) => requestFor<{ remembered: boolean }>(entry, '/apps/sudo', {}),

  notifications: (entry: ServerEntry, limit = 80) =>
    requestFor<{ notifications: DeskNotification[]; unread: number }>(
      entry,
      `/desk/notifications?limit=${limit}`,
      {},
    ),

  markRead: (entry: ServerEntry, read: { ids: number[] } | { all: true }) =>
    requestFor<void>(
      entry,
      '/desk/notifications/read',
      { method: 'POST', body: JSON.stringify(read) },
    ),

  /// The custom wallpaper as an object URL (an `<img>` cannot send the
  /// bearer header). The caller revokes it.
  async wallpaperUrl(entry: ServerEntry): Promise<string | null> {
    const res = await raw(entry, '/desk/wallpaper', { method: 'GET' })
    if (res.status === 404) return null
    if (!res.ok) throw await errorFrom(res)
    return URL.createObjectURL(await res.blob())
  },

  async putWallpaper(entry: ServerEntry, file: Blob): Promise<string> {
    const res = await raw(entry, '/desk/wallpaper', { method: 'PUT', body: file })
    if (!res.ok) {
      // `{"error": <code>}`: the code is the message and the code.
      const e = await errorFrom(res)
      throw new ApiError(e.message, e.status, e.code ?? (e.body?.error as string | undefined), e.body)
    }
    return ((await res.json()) as { sha256: string }).sha256
  },

  async deleteWallpaper(entry: ServerEntry): Promise<void> {
    const res = await raw(entry, '/desk/wallpaper', { method: 'DELETE' })
    if (!res.ok) throw await errorFrom(res)
  },

  themes: (entry: ServerEntry) => requestFor<InstalledTheme[]>(entry, '/desk/themes', {}),

  /// Installs a `.fsbt`; a refused package throws with the reason the app's
  /// installer would give (`code` `invalidTheme`).
  async installTheme(entry: ServerEntry, file: Blob): Promise<InstalledTheme> {
    const res = await raw(entry, '/desk/themes', { method: 'POST', body: file })
    return themeAnswer(res)
  },

  async removeTheme(entry: ServerEntry, installation: string): Promise<void> {
    const res = await raw(entry, `/desk/themes/${encodeURIComponent(installation)}`, { method: 'DELETE' })
    if (!res.ok && res.status !== 404) throw await errorFrom(res)
  },

  /// A theme's background as an object URL; null when it has none.
  async themeBackgroundUrl(entry: ServerEntry, installation: string, variant: string | null): Promise<string | null> {
    const query = variant ? `?variant=${encodeURIComponent(variant)}` : ''
    const res = await raw(entry, `/desk/themes/${encodeURIComponent(installation)}/background${query}`, { method: 'GET' })
    if (res.status === 404) return null
    if (!res.ok) throw await errorFrom(res)
    return URL.createObjectURL(await res.blob())
  },

  themeStore: (entry: ServerEntry, refresh = false) =>
    requestFor<ThemeStoreView>(
      entry,
      `/desk/themes/store${refresh ? '?refresh=1' : ''}`,
      {},
      undefined,
      120_000,
    ),

  async installFromStore(entry: ServerEntry, item: StoreItem, version: string): Promise<InstalledTheme> {
    const res = await raw(entry, '/desk/themes/store/install', {
      method: 'POST',
      body: JSON.stringify({ repo: item.repoUrl, id: item.listing.id, version }),
      headers: { 'content-type': 'application/json' },
    })
    return themeAnswer(res)
  },
}

/// An install's answer, or its refusal: `reason` (the package's or the
/// store's own words) as the message.
async function themeAnswer(res: Response): Promise<InstalledTheme> {
  const body = (await res.json().catch(() => ({}))) as ErrorBody & { reason?: string } & Partial<InstalledTheme>
  if (!res.ok) {
    if (body.reason) throw new ApiError(body.reason, res.status, body.error, body)
    const e = errorFromBody(res.status, body)
    throw new ApiError(e.message, e.status, body.error, body)
  }
  return body as InstalledTheme
}

/// A request whose answer the caller reads itself (bytes, a theme's refusal):
/// [fetchFor], with a session that has expired ending as anywhere else.
function raw(entry: ServerEntry, path: string, init: RequestInit): Promise<Response> {
  return fetchFor(entry, path, init, AbortSignal.timeout(120_000))
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

