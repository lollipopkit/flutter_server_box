import { describe, it, expect, beforeEach } from 'vitest'
import { theme } from '../lib/theme.svelte'
import { terminalSurface } from '../lib/terminalSurface.svelte'

describe('theme', () => {
  beforeEach(() => {
    window.localStorage.removeItem('theme')
    document.documentElement.classList.remove('dark', 'light')
  })

  it('cycles system -> light -> dark, applying explicit classes only', () => {
    const cls = document.documentElement.classList
    while (theme.current !== 'system') theme.cycle()
    // system preference is handled by the theme CSS media query: no classes
    expect(cls.contains('dark')).toBe(false)
    expect(cls.contains('light')).toBe(false)

    theme.cycle()
    expect(theme.current).toBe('light')
    expect(window.localStorage.getItem('theme')).toBe('light')
    expect(cls.contains('light')).toBe(true)
    expect(cls.contains('dark')).toBe(false)

    theme.cycle()
    expect(theme.current).toBe('dark')
    expect(window.localStorage.getItem('theme')).toBe('dark')
    expect(cls.contains('dark')).toBe(true)
    expect(cls.contains('light')).toBe(false)

    theme.cycle()
    expect(theme.current).toBe('system')
    expect(cls.contains('dark')).toBe(false)
    expect(cls.contains('light')).toBe(false)
  })

  it('gives the terminals a surface matching the terminal theme', () => {
    // The strip below a terminal's last row is filled with this, so it has to
    // be the colour xterm draws the rows in, not a colour of the panel's.
    theme.set('light')
    expect(terminalSurface.current).toBe('#ffffff')
    theme.set('dark')
    expect(terminalSurface.current).toBe('#0b0f14')
    theme.set('system')
  })
})
