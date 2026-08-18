import { describe, it, expect, beforeEach } from 'vitest'
import { theme } from '../lib/theme.svelte'

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
})
