/// Theme selection: light / dark / system, persisted in localStorage and
/// applied as a `dark` class on <html> (pre-paint init lives in index.html)

export type Theme = 'light' | 'dark' | 'system'

const ORDER: Theme[] = ['system', 'light', 'dark']

function prefersDark(): boolean {
  // jsdom has no matchMedia; default to light there
  return typeof window.matchMedia === 'function'
    && window.matchMedia('(prefers-color-scheme: dark)').matches
}

class ThemeStore {
  current = $state<Theme>(this.#stored())

  constructor() {
    this.#apply()
    if (typeof window.matchMedia === 'function') {
      window
        .matchMedia('(prefers-color-scheme: dark)')
        .addEventListener('change', () => this.#apply())
    }
  }

  #stored(): Theme {
    const v = window.localStorage.getItem('theme')
    return v === 'light' || v === 'dark' ? v : 'system'
  }

  #apply() {
    const dark = this.current === 'dark' || (this.current === 'system' && prefersDark())
    document.documentElement.classList.toggle('dark', dark)
  }

  cycle() {
    this.current = ORDER[(ORDER.indexOf(this.current) + 1) % ORDER.length]
    window.localStorage.setItem('theme', this.current)
    this.#apply()
  }
}

export const theme = new ThemeStore()
