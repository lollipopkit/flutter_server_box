/// The wallpaper each account had, kept in this browser so the login screen
/// can show it before anyone signs in. The agent serves preferences only to
/// a signed-in account, and an unauthenticated route would hand anyone who can
/// reach the agent its accounts' names and images; a copy here is seen only by
/// whoever already signed in from this browser.
///
/// IndexedDB, not Cache Storage: an agent reached over plain HTTP (an operator
/// allowed it) is not a secure context, where Cache Storage does not exist. A
/// browser without either keeps nothing and shows the default.

import type { WallpaperPreset } from '../prefs.svelte'

export type Fit = 'cover' | 'contain' | 'fill'

export type CachedWallpaper =
  | { preset: WallpaperPreset; fit: Fit }
  | { image: Blob; fit: Fit }

interface Row {
  key: string
  serverId: string
  username: string
  at: number
  preset?: WallpaperPreset
  image?: Blob
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

const keyOf = (serverId: string, username: string) => `${serverId}\n${username}`

export async function saveWallpaper(serverId: string, username: string, wallpaper: CachedWallpaper) {
  const row: Row = {
    key: keyOf(serverId, username),
    serverId,
    username,
    at: Date.now(),
    fit: wallpaper.fit,
    ...('preset' in wallpaper ? { preset: wallpaper.preset } : { image: wallpaper.image }),
  }
  await run('readwrite', (s) => s.put(row))
}

/// [username]'s on [serverId]; without a name, the one last kept for any of
/// its accounts.
export async function loadWallpaper(serverId: string, username: string | null): Promise<CachedWallpaper | null> {
  let row: Row | null = null
  if (username !== null) row = (await run<Row | undefined>('readonly', (s) => s.get(keyOf(serverId, username)))) ?? null
  if (!row) {
    const rows = (await run<Row[]>('readonly', (s) => s.getAll())) ?? []
    row = rows.filter((r) => r.serverId === serverId).sort((a, b) => b.at - a.at)[0] ?? null
  }
  if (!row) return null
  if (row.preset) return { preset: row.preset, fit: row.fit }
  if (row.image) return { image: row.image, fit: row.fit }
  return null
}

/// Drops what is kept for [serverId] (one account's, or every one's).
export async function dropWallpapers(serverId: string, username?: string) {
  if (username !== undefined) {
    await run('readwrite', (s) => s.delete(keyOf(serverId, username)))
    return
  }
  const rows = (await run<Row[]>('readonly', (s) => s.getAll())) ?? []
  for (const r of rows) if (r.serverId === serverId) await run('readwrite', (s) => s.delete(r.key))
}
