/// The agent's `/api/v1/desk*` (`monitor/src/api/desk.rs`), always to an
/// explicit server: a desk saves to the server it was opened for, even while
/// the panel is switching to another.

import { ApiError, requestFor } from '../lib/api'
import { isSecureAgentUrl } from '../lib/agentUrl'
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
  /// `preset:<id>` or `custom`.
  wallpaper: string
  wallpaper_fit: 'cover' | 'contain' | 'fill'
  dock: string[]
  icons: DeskIcon[]
  /// Hidden apps keep running; off suspends them (`docs/dev/desk-sys.md`).
  background: boolean
  /// Apps suspended when hidden even while [background] is on.
  background_denied: string[]
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
}

async function raw(entry: ServerEntry, path: string, init: RequestInit): Promise<Response> {
  if (!isSecureAgentUrl(entry.url)) throw new ApiError('Remote monitor agents require HTTPS; HTTP is allowed only on loopback.')
  const headers: Record<string, string> = {}
  if (entry.token) headers.Authorization = `Bearer ${entry.token}`
  try {
    return await fetch(`${entry.url}/api/v1${path}`, { ...init, headers, signal: AbortSignal.timeout(60_000) })
  } catch {
    throw new ApiError('Request failed')
  }
}

/// Reads `/desk/events` until [signal] aborts or the stream ends, calling
/// [onEvent] with each parsed `data:` line. Throws on a refused or broken
/// stream; the caller decides when to try again.
export async function readEvents(
  entry: ServerEntry,
  signal: AbortSignal,
  onEvent: (event: Record<string, unknown>) => void,
): Promise<void> {
  if (!isSecureAgentUrl(entry.url)) throw new ApiError('insecure')
  const res = await fetch(`${entry.url}/api/v1/desk/events`, {
    headers: entry.token ? { Authorization: `Bearer ${entry.token}` } : {},
    signal,
  })
  if (!res.ok || !res.body) throw new ApiError('Failed to open the event stream', res.status)
  const reader = res.body.pipeThrough(new TextDecoderStream()).getReader()
  let buffer = ''
  for (;;) {
    const { value, done } = await reader.read()
    if (done) return
    buffer += value
    let end: number
    while ((end = buffer.indexOf('\n\n')) >= 0) {
      const frame = buffer.slice(0, end)
      buffer = buffer.slice(end + 2)
      for (const line of frame.split('\n')) {
        if (!line.startsWith('data:')) continue
        try {
          onEvent(JSON.parse(line.slice(5).trim()) as Record<string, unknown>)
        } catch {
          // A line that is not JSON is not an event.
        }
      }
    }
  }
}
