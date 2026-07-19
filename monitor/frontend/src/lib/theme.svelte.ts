/// Theme selection: light / dark / system, persisted in localStorage.
/// The shared theme tokens (@serverbox/webui/theme.css) follow the system via
/// media query by default; an explicit `.dark` / `.light` class on <html>
/// overrides it (pre-paint init lives in index.html).

export type Theme = 'light' | 'dark' | 'system'

const ORDER: Theme[] = ['system', 'light', 'dark']

class ThemeStore {
  current = $state<Theme>(this.#stored())

  constructor() {
    this.#apply()
  }

  #stored(): Theme {
    const v = window.localStorage.getItem('theme')
    return v === 'light' || v === 'dark' ? v : 'system'
  }

  #apply() {
    const cls = document.documentElement.classList
    cls.toggle('dark', this.current === 'dark')
    cls.toggle('light', this.current === 'light')
  }

  cycle() {
    this.current = ORDER[(ORDER.indexOf(this.current) + 1) % ORDER.length]
    window.localStorage.setItem('theme', this.current)
    this.#apply()
  }
}

export const theme = new ThemeStore()
