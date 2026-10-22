/// The wallpaper each server's desk had, kept in this browser so the login
/// screen can show it before signing in. The agent serves preferences only to
/// its signed-in account, and an unauthenticated route would hand anyone who
/// can reach the agent its images; a copy here is seen only by whoever
/// already signed in from this browser.
///
/// IndexedDB, not Cache Storage: an agent reached over plain HTTP (an operator
/// allowed it) is not a secure context, where Cache Storage does not exist. A
/// browser without either keeps nothing and shows the default.

import type { WallpaperPreset } from '../prefs.svelte'

export type Fit = 'cover' | 'contain' | 'fill'

/// An installed theme's background as the desk drew it (`themeWallpaper`).
export interface CachedTheme {
  ground: string
  image: Blob | null
  opacity: number
  blur: number
  tile: number
}

export type CachedWallpaper =
  | { preset: WallpaperPreset; fit: Fit }
  | { image: Blob; fit: Fit }
  | { theme: CachedTheme; fit: Fit }

interface Row {
  key: string
  serverId: string
  at: number
  preset?: WallpaperPreset
  image?: Blob
  theme?: CachedTheme
  fit: Fit
}

const DB = 'desk-lock'
const STORE = 'wallpapers'

let opening: Promise<IDBDatabase | null> | null = null

function db(): Promise<IDBDatabase | null> {
  opening ??= new Promise((resolve) => {
    try {
      if (typeof indexedDB === 'undefined') return resolve(null)
      const req = indexedDB.open(DB, 1)
      req.onupgradeneeded = () => req.result.createObjectStore(STORE, { keyPath: 'key' })
      req.onsuccess = () => resolve(req.result)
      req.onerror = () => resolve(null)
      req.onblocked = () => resolve(null)
    } catch {
      resolve(null)
    }
  })
  return opening
}

function run<T>(mode: IDBTransactionMode, fn: (store: IDBObjectStore) => IDBRequest<T>): Promise<T | null> {
  return db().then(
    (d) =>
      new Promise<T | null>((resolve) => {
        if (!d) return resolve(null)
        try {
          const req = fn(d.transaction(STORE, mode).objectStore(STORE))
          req.onsuccess = () => resolve(req.result)
          req.onerror = () => resolve(null)
        } catch {
          resolve(null)
        }
      }),
  )
}

export async function saveWallpaper(serverId: string, wallpaper: CachedWallpaper) {
  const row: Row = {
    key: serverId,
    serverId,
    at: Date.now(),
    fit: wallpaper.fit,
    ...('preset' in wallpaper
      ? { preset: wallpaper.preset }
      : 'theme' in wallpaper
        ? { theme: wallpaper.theme }
        : { image: wallpaper.image }),
  }
  await run('readwrite', (s) => s.put(row))
  // TODO: remove once no browser keeps rows keyed by server and account
  // (several accounts per agent, before 2026-10-14).
  const rows = (await run<Row[]>('readonly', (s) => s.getAll())) ?? []
  for (const r of rows) if (r.serverId === serverId && r.key !== serverId) await run('readwrite', (s) => s.delete(r.key))
}

/// [serverId]'s, the one last kept.
export async function loadWallpaper(serverId: string): Promise<CachedWallpaper | null> {
  const rows = (await run<Row[]>('readonly', (s) => s.getAll())) ?? []
  const row = rows.filter((r) => r.serverId === serverId).sort((a, b) => b.at - a.at)[0] ?? null
  if (!row) return null
  if (row.preset) return { preset: row.preset, fit: row.fit }
  if (row.image) return { image: row.image, fit: row.fit }
  if (row.theme) return { theme: row.theme, fit: row.fit }
  return null
}

/// Drops what is kept for [serverId].
export async function dropWallpapers(serverId: string) {
  const rows = (await run<Row[]>('readonly', (s) => s.getAll())) ?? []
  for (const r of rows) if (r.serverId === serverId) await run('readwrite', (s) => s.delete(r.key))
}
