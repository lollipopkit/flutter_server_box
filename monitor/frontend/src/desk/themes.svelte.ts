/// The theme packages this account installed on the agent (`desk_themes`),
/// which one the desk is drawn with, and its background as a URL an image
/// can load.

import { ApiError } from '../lib/api'
import type { ServerEntry } from '../lib/servers.svelte'
import { theme as appearance } from '../lib/theme.svelte'
import { deskApi, type InstalledTheme, type PackageTheme, type StoreItem, type ThemeStoreView } from './deskApi'
import type { DeskPrefs } from './prefs.svelte'
import { themeOf, themeValue } from './themeStyle'

export type { InstalledTheme, PackageTheme, StoreItem, ThemeStoreView }
export { css, themeDark, themeValue, themeWallpaper } from './themeStyle'

export class DeskThemes {
  installed = $state<InstalledTheme[]>([])
  loaded = $state(false)
  /// The active theme's background, while it has one.
  backgroundUrl = $state<string | null>(null)
  #entry: ServerEntry
  #prefs: DeskPrefs
  #backgroundFor: string | null = null

  constructor(entry: ServerEntry, prefs: DeskPrefs) {
    // A copy: the session token it was made with is the one it keeps using.
    this.#entry = { ...entry }
    this.#prefs = prefs
  }

  /// The package and theme the desk is drawn with, or null.
  get active(): { pkg: InstalledTheme; theme: PackageTheme } | null {
    return themeOf(this.installed, this.#prefs.value.theme)
  }

  async load() {
    try {
      this.installed = await deskApi.themes(this.#entry)
    } catch {
      // What was listed stands.
    }
    this.loaded = true
    await this.#syncBackground()
  }

  /// Installs a `.fsbt`; a refused package throws with the app's reason.
  async install(file: Blob): Promise<InstalledTheme> {
    const installed = await deskApi.installTheme(this.#entry, file)
    await this.load()
    return installed
  }

  /// The theme store as the agent last read it, or read again.
  store(refresh = false): Promise<ThemeStoreView> {
    return deskApi.themeStore(this.#entry, refresh)
  }

  async installFromStore(item: StoreItem, version: string): Promise<InstalledTheme> {
    const installed = await deskApi.installFromStore(this.#entry, item, version)
    await this.load()
    return installed
  }

  async remove(installationId: string) {
    await deskApi.removeTheme(this.#entry, installationId)
    // The agent let go of a selection of it; so does this copy.
    if (this.#prefs.value.theme?.split('#')[0] === installationId) {
      this.#prefs.value = {
        ...this.#prefs.value,
        theme: null,
        wallpaper: this.#prefs.value.wallpaper === 'theme' ? 'preset:bloom' : this.#prefs.value.wallpaper,
      }
    }
    await this.load()
  }

  /// Draws the desk with [theme] of [installationId], or the design
  /// system's own for null. As the app does: the theme's background becomes
  /// the wallpaper, and its preferred brightness the mode unless it locks one.
  select(installationId: string | null, theme: PackageTheme | null) {
    const wallpaper = this.#prefs.value.wallpaper
    if (!installationId || !theme) {
      this.#prefs.update({ theme: null, wallpaper: wallpaper === 'theme' ? 'preset:bloom' : wallpaper })
    } else {
      const drawn = theme.background.style !== 'none'
      this.#prefs.update({
        theme: themeValue(installationId, theme),
        wallpaper: drawn ? 'theme' : wallpaper === 'theme' ? 'preset:bloom' : wallpaper,
      })
      if (theme.modes.length > 1) appearance.set(theme.mode === 1 ? 'light' : theme.mode === 2 ? 'dark' : 'system')
    }
    void this.#syncBackground()
  }

  /// Fetches the active theme's background again when the theme changed.
  async #syncBackground() {
    const active = this.active
    const key = active && active.theme.background.style === 'image' ? themeValue(active.pkg.installationId, active.theme) : null
    if (key === this.#backgroundFor) return
    this.#backgroundFor = key
    let url: string | null = null
    if (active && key) {
      try {
        url = await deskApi.themeBackgroundUrl(this.#entry, active.pkg.installationId, active.theme.variant?.key ?? null)
      } catch (e) {
        if (!(e instanceof ApiError)) throw e
      }
    }
    // Another theme was chosen while this one loaded.
    if (this.#backgroundFor !== key) {
      if (url) URL.revokeObjectURL(url)
      return
    }
    if (this.backgroundUrl) URL.revokeObjectURL(this.backgroundUrl)
    this.backgroundUrl = url
  }

  /// Follows a preferences change made elsewhere (another tab).
  preferencesChanged() {
    void this.#syncBackground()
  }

  close() {
    if (this.backgroundUrl) URL.revokeObjectURL(this.backgroundUrl)
    this.backgroundUrl = null
    this.#backgroundFor = null
  }
}
