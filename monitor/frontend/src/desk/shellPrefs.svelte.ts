/// How the desk's chrome looks in this browser: where the dock sits, whether
/// it hides, its icon size, and the apps' icon shape. Per browser (a phone and a desktop want different docks), kept in
/// localStorage; what follows the account lives in `prefs.svelte.ts`.

import { readLocalJson, writeLocalJson } from '../lib/localJson'

export type DockPosition = 'left' | 'bottom' | 'right'
/// An app icon's outline: a circle, or the design system's squircle.
export type IconShape = 'circle' | 'squircle'

export const DOCK_SIZES = [36, 44, 54] as const
export type DockSize = (typeof DOCK_SIZES)[number]

interface Stored {
  dockPosition: DockPosition
  dockAutoHide: boolean
  dockSize: DockSize
  /// A dot under a running app's icon.
  dockRunDots: boolean
  iconShape: IconShape
}

const KEY = 'desk.shell'

const DEFAULTS: Stored = { dockPosition: 'left', dockAutoHide: false, dockSize: 44, dockRunDots: true, iconShape: 'circle' }

function load(): Stored {
  const raw = readLocalJson<Stored>(KEY)
  return {
    dockPosition: (['left', 'bottom', 'right'] as const).find((p) => p === raw.dockPosition) ?? DEFAULTS.dockPosition,
    dockAutoHide: raw.dockAutoHide === true,
    dockSize: DOCK_SIZES.find((s) => s === raw.dockSize) ?? DEFAULTS.dockSize,
    dockRunDots: raw.dockRunDots !== false,
    iconShape: raw.iconShape === 'squircle' ? 'squircle' : 'circle',
  }
}

class ShellPrefs {
  #value = $state<Stored>(load())

  get dockPosition(): DockPosition {
    return this.#value.dockPosition
  }
  get dockAutoHide(): boolean {
    return this.#value.dockAutoHide
  }
  get dockSize(): DockSize {
    return this.#value.dockSize
  }
  get dockRunDots(): boolean {
    return this.#value.dockRunDots
  }
  get iconShape(): IconShape {
    return this.#value.iconShape
  }

  /// Where the dock is: on a phone ([compact]) always at the bottom.
  dockAt(compact: boolean): DockPosition {
    return compact ? 'bottom' : this.dockPosition
  }

  /// What the dock keeps from the windows on its side, in px (its icons, its
  /// padding and its distance from the edge): nothing when it hides itself.
  dockReserve(compact: boolean): { left: number; right: number; bottom: number } {
    const r = compact ? 67 : this.dockAutoHide ? 0 : this.dockSize + 34
    const p = this.dockAt(compact)
    return { left: p === 'left' ? r : 0, right: p === 'right' ? r : 0, bottom: p === 'bottom' ? r : 0 }
  }

  set(patch: Partial<Stored>) {
    this.#value = { ...this.#value, ...patch }
    writeLocalJson(KEY, this.#value)
  }
}

export const shellPrefs = new ShellPrefs()
