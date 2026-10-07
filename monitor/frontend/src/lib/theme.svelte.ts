/// Theme selection: light / dark / system, persisted in localStorage.
/// The shared theme tokens (@serverbox/webui/theme.css) follow the system via
/// media query by default; an explicit `.dark` / `.light` class on <html>
/// overrides it (pre-paint init lives in index.html). The theme in effect is
/// also `data-theme="light|dark"` on <html>, which the desk's design system
/// (`desk/lk/`) keys its dark palette on.

export type Theme = 'light' | 'dark' | 'system'

const ORDER: Theme[] = ['system', 'light', 'dark']

const SYSTEM_DARK = '(prefers-color-scheme: dark)'

class ThemeStore {
  current = $state<Theme>(this.#stored())
  /// Whether the system asks for dark, followed live.
  #systemDark = $state(window.matchMedia?.(SYSTEM_DARK).matches ?? false)

  constructor() {
    window.matchMedia?.(SYSTEM_DARK).addEventListener?.('change', (e) => {
      this.#systemDark = e.matches
      this.#apply()
    })
    this.#apply()
  }

  /// The mode in effect: the choice, or the system's under `system`.
  get dark(): boolean {
    return this.current === 'dark' || (this.current === 'system' && this.#systemDark)
  }

  #stored(): Theme {
    const v = window.localStorage.getItem('theme')
    return v === 'light' || v === 'dark' ? v : 'system'
  }

  #apply() {
    const cls = document.documentElement.classList
    cls.toggle('dark', this.current === 'dark')
    cls.toggle('light', this.current === 'light')
    document.documentElement.dataset.theme = this.dark ? 'dark' : 'light'
  }

  cycle() {
    this.set(ORDER[(ORDER.indexOf(this.current) + 1) % ORDER.length])
  }

  set(value: Theme) {
    this.current = value
    window.localStorage.setItem('theme', value)
    this.#apply()
  }
}

export const theme = new ThemeStore()
