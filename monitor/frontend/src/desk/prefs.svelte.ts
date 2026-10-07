/// One desk's preferences: accent, wallpaper, dock, icons. Loaded once, saved
/// after a pause, and taken again when another tab changed them.

import { defaultDock } from './registry.svelte'
import type { DeskIcon, DeskPreferences } from './deskApi'
import type { DeskStorage } from './storage'

export const WALLPAPERS = ['bloom', 'dusk', 'nightfall', 'graphite'] as const
export type WallpaperPreset = (typeof WALLPAPERS)[number]

/// The first is the default (stored as `null`): ClawBox's berry.
export const ACCENTS = ['#8b2252', '#2563eb', '#7c3aed', '#dc2626', '#ea580c', '#ca8a04', '#16a34a', '#0891b2', '#525252']

export function defaults(): DeskPreferences {
  return {
    accent: null,
    wallpaper: 'preset:bloom',
    wallpaper_fit: 'cover',
    dock: defaultDock(),
    icons: [
      { id: 'files', kind: 'app', app_id: 'files', label: '', col: null, row: null },
      { id: 'terminal', kind: 'app', app_id: 'terminal', label: '', col: null, row: null },
    ],
    background: true,
  }
}

const SAVE_DELAY_MS = 500

export class DeskPrefs {
  value = $state<DeskPreferences>(defaults())
  /// The custom wallpaper as an object URL, while there is one.
  wallpaperUrl = $state<string | null>(null)
  #wallpaperSha: string | null = null
  #storage: DeskStorage
  #timer: ReturnType<typeof setTimeout> | null = null

  constructor(storage: DeskStorage) {
    this.#storage = storage
  }

  get remote(): boolean {
    return this.#storage.remote
  }

  /// Whether the background choice is kept (an older agent cannot).
  get keepsBackground(): boolean {
    return this.#storage.keepsBackground
  }

  /// The preset id, or null for the custom image.
  get preset(): WallpaperPreset | null {
    const id = this.value.wallpaper.startsWith('preset:') ? this.value.wallpaper.slice(7) : null
    return id && (WALLPAPERS as readonly string[]).includes(id) ? (id as WallpaperPreset) : null
  }

  async load() {
    try {
      const { preferences, wallpaperSha } = await this.#storage.load()
      // A preference newer than what was stored takes its default.
      this.value = preferences ? { ...defaults(), ...preferences } : defaults()
      if (wallpaperSha !== this.#wallpaperSha) {
        this.#wallpaperSha = wallpaperSha
        this.#setWallpaperUrl(wallpaperSha ? await this.#storage.wallpaperUrl() : null)
      }
    } catch {
      // The defaults stand.
    }
  }

  update(patch: Partial<DeskPreferences>) {
    this.value = { ...this.value, ...patch }
    if (this.#timer) clearTimeout(this.#timer)
    this.#timer = setTimeout(() => {
      this.#timer = null
      void this.#storage.savePreferences($state.snapshot(this.value) as DeskPreferences).catch(() => {})
    }, SAVE_DELAY_MS)
  }

  pin(appId: string) {
    if (!this.value.dock.includes(appId)) this.update({ dock: [...this.value.dock, appId] })
  }

  unpin(appId: string) {
    this.update({ dock: this.value.dock.filter((id) => id !== appId) })
  }

  moveInDock(appId: string, to: number) {
    const dock = this.value.dock.filter((id) => id !== appId)
    dock.splice(Math.max(0, Math.min(to, dock.length)), 0, appId)
    this.update({ dock })
  }

  addIcon(icon: Omit<DeskIcon, 'id'>) {
    const id = typeof crypto.randomUUID === 'function' ? crypto.randomUUID() : `i${Date.now().toString(36)}`
    this.update({ icons: [...this.value.icons, { ...icon, id }] })
  }

  removeIcon(id: string) {
    this.update({ icons: this.value.icons.filter((i) => i.id !== id) })
  }

  renameIcon(id: string, label: string) {
    this.update({ icons: this.value.icons.map((i) => (i.id === id ? { ...i, label } : i)) })
  }

  placeIcon(id: string, col: number, row: number) {
    // A cell holds one icon: whoever was there swaps into the moved one's.
    const moved = this.value.icons.find((i) => i.id === id)
    if (!moved) return
    this.update({
      icons: this.value.icons.map((i) => {
        if (i.id === id) return { ...i, col, row }
        if (i.col === col && i.row === row) return { ...i, col: moved.col ?? null, row: moved.row ?? null }
        return i
      }),
    })
  }

  async setCustomWallpaper(file: Blob) {
    await this.#storage.putWallpaper(file)
    this.#wallpaperSha = null
    this.update({ wallpaper: 'custom' })
    await this.load()
  }

  async removeCustomWallpaper() {
    await this.#storage.deleteWallpaper()
    this.#setWallpaperUrl(null)
    this.#wallpaperSha = null
    if (this.value.wallpaper === 'custom') this.update({ wallpaper: 'preset:bloom' })
  }

  close() {
    if (this.#timer) {
      clearTimeout(this.#timer)
      this.#timer = null
      void this.#storage.savePreferences($state.snapshot(this.value) as DeskPreferences).catch(() => {})
    }
    this.#setWallpaperUrl(null)
  }

  #setWallpaperUrl(url: string | null) {
    if (this.wallpaperUrl) URL.revokeObjectURL(this.wallpaperUrl)
    this.wallpaperUrl = url
  }
}
