/// Theme selection: light / dark / system, persisted in localStorage.
/// The shared theme tokens (@serverbox/webui/theme.css) follow the system via
/// media query by default; an explicit `.dark` / `.light` class on <html>
/// overrides it (pre-paint init lives in index.html). The theme in effect is
/// also `data-theme="light|dark"` on <html>, which the desk's design system
/// (`desk/lk/`) keys its dark palette on.

import { flushSync } from 'svelte'

export type Theme = 'light' | 'dark' | 'system'

const ORDER: Theme[] = ['system', 'light', 'dark']

const SYSTEM_DARK = '(prefers-color-scheme: dark)'

type TransitionDocument = Document & { startViewTransition?: (update: () => void) => unknown }

/// Set while a crossfade's change runs.
let fading = false

/// Runs [change] as one crossfade of the whole page from how it looks to how
/// it looks after, so a gradient wallpaper, glass and text change together
/// (a per-property `transition` cannot interpolate gradients). Paced by the
/// design system's `--dur-window` / `--ease-in-out`, which reduced motion
/// shortens; without the View Transitions API, a hidden tab or no desk on
/// screen, the change is immediate.
export function crossfade(change: () => void) {
  const doc = document as TransitionDocument
  const lk = document.querySelector('.desk-root') ?? document.querySelector('.lk')
  // A change made inside another is part of that one's crossfade.
  if (fading || !doc.startViewTransition || !lk || document.visibilityState !== 'visible') {
    change()
    return
  }
  const style = getComputedStyle(lk)
  const root = document.documentElement.style
  root.setProperty('--appearance-fade', style.getPropertyValue('--dur-window').trim() || '0ms')
  root.setProperty('--appearance-ease', style.getPropertyValue('--ease-in-out').trim() || 'ease')
  doc.startViewTransition(() => {
    fading = true
    try {
      change()
      // What follows from the change (the desk's theme tokens, its
      // wallpaper) is drawn before the new state is captured.
      flushSync()
    } finally {
      fading = false
    }
  })
}

class ThemeStore {
  current = $state<Theme>(this.#stored())
  /// Whether the system asks for dark, followed live.
  #systemDark = $state(window.matchMedia?.(SYSTEM_DARK).matches ?? false)
  /// The one mode a desk's theme supports, which wins over the choice while
  /// that theme is drawn (`lock`).
  locked = $state<'light' | 'dark' | null>(null)
  /// Moves whenever what the page is drawn with may have changed: the mode,
  /// or the desk's theme tokens (`touch`). For what reads colours from the
  /// document rather than through CSS (a terminal's canvas).
  revision = $state(0)

  constructor() {
    window.matchMedia?.(SYSTEM_DARK).addEventListener?.('change', (e) => {
      const follows = !this.locked && this.current === 'system'
      const update = () => {
        this.#systemDark = e.matches
        this.#apply()
      }
      if (follows) crossfade(update)
      else update()
    })
    this.#apply()
  }

  /// The mode in effect: the choice, or the system's under `system`.
  get dark(): boolean {
    if (this.locked) return this.locked === 'dark'
    return this.current === 'dark' || (this.current === 'system' && this.#systemDark)
  }

  /// Holds the mode at [mode] (a theme that declares only one), or lets the
  /// choice apply again (null). The choice itself is kept.
  lock(mode: 'light' | 'dark' | null) {
    if (this.locked === mode) return
    this.locked = mode
    this.#apply()
  }

  #stored(): Theme {
    const v = window.localStorage.getItem('theme')
    return v === 'light' || v === 'dark' ? v : 'system'
  }

  /// Says the desk's tokens changed (another installed theme), once they are
  /// on the page.
  touch() {
    this.revision++
  }

  #apply() {
    this.revision++
    const cls = document.documentElement.classList
    const mode = this.locked ?? this.current
    cls.toggle('dark', mode === 'dark')
    cls.toggle('light', mode === 'light')
    document.documentElement.dataset.theme = this.dark ? 'dark' : 'light'
  }

  cycle() {
    this.set(ORDER[(ORDER.indexOf(this.current) + 1) % ORDER.length])
  }

  set(value: Theme) {
    window.localStorage.setItem('theme', value)
    const dark = this.dark
    const update = () => {
      this.current = value
      this.#apply()
    }
    // Only a change that shows (not light → system on a light system).
    if (this.locked || dark === (value === 'dark' || (value === 'system' && this.#systemDark))) update()
    else crossfade(update)
  }
}

export const theme = new ThemeStore()
