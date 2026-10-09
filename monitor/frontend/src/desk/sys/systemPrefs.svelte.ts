/// The system's preferences an app follows, per browser (localStorage):
/// how often live figures are read again (and whether at all), how dense a
/// table is, how large text is drawn, whether motion is reduced, whether a
/// notification shows a banner, and what the desk does when it starts.
/// Settings changes them; an app only reads them.

export type RefreshSeconds = 1 | 2 | 5
export type Density = 'compact' | 'comfortable'
export type TextSize = 's' | 'm' | 'l'
export type StartApp = 'status' | 'process' | 'files' | 'none'

export interface SystemPrefsValue {
  autoRefresh: boolean
  refreshSeconds: RefreshSeconds
  density: Density
  textSize: TextSize
  reduceMotion: boolean
  banners: boolean
  openOnStart: StartApp
  restoreWindows: boolean
}

const KEY = 'desk.system'

const DEFAULTS: SystemPrefsValue = {
  autoRefresh: true,
  refreshSeconds: 2,
  density: 'compact',
  textSize: 'm',
  reduceMotion: false,
  banners: true,
  openOnStart: 'status',
  restoreWindows: true,
}

function pick<T>(value: unknown, allowed: readonly T[], fallback: T): T {
  return allowed.find((a) => a === value) ?? fallback
}

function load(): SystemPrefsValue {
  try {
    const raw = JSON.parse(window.localStorage.getItem(KEY) ?? '{}') as Partial<Record<keyof SystemPrefsValue, unknown>>
    return {
      autoRefresh: raw.autoRefresh !== false,
      refreshSeconds: pick(raw.refreshSeconds, [1, 2, 5] as const, DEFAULTS.refreshSeconds),
      density: pick(raw.density, ['compact', 'comfortable'] as const, DEFAULTS.density),
      textSize: pick(raw.textSize, ['s', 'm', 'l'] as const, DEFAULTS.textSize),
      reduceMotion: raw.reduceMotion === true,
      banners: raw.banners !== false,
      openOnStart: pick(raw.openOnStart, ['status', 'process', 'files', 'none'] as const, DEFAULTS.openOnStart),
      restoreWindows: raw.restoreWindows !== false,
    }
  } catch {
    return { ...DEFAULTS }
  }
}

/// How much larger or smaller a window's content is drawn for [size].
export const TEXT_SCALE: Record<TextSize, number> = { s: 0.92, m: 1, l: 1.12 }

class SystemPrefs {
  #value = $state<SystemPrefsValue>(load())

  get value(): Readonly<SystemPrefsValue> {
    return this.#value
  }

  /// Milliseconds between two readings of a live figure.
  get refreshMs(): number {
    return this.#value.refreshSeconds * 1000
  }

  set(patch: Partial<SystemPrefsValue>) {
    this.#value = { ...this.#value, ...patch }
    try {
      window.localStorage.setItem(KEY, JSON.stringify(this.#value))
    } catch {
      // Private mode: it lasts the tab.
    }
  }
}

export const systemPrefs = new SystemPrefs()
