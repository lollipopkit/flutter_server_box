import { describe, it, expect, beforeEach } from 'vitest'
import { theme } from '../lib/theme.svelte'

describe('theme', () => {
  beforeEach(() => {
    window.localStorage.removeItem('theme')
    document.documentElement.classList.remove('dark')
  })

  it('cycles system -> light -> dark and persists', () => {
    // jsdom has no matchMedia, so `system` resolves to light
    while (theme.current !== 'system') theme.cycle()
    expect(document.documentElement.classList.contains('dark')).toBe(false)

    theme.cycle()
    expect(theme.current).toBe('light')
    expect(window.localStorage.getItem('theme')).toBe('light')
    expect(document.documentElement.classList.contains('dark')).toBe(false)

    theme.cycle()
    expect(theme.current).toBe('dark')
    expect(window.localStorage.getItem('theme')).toBe('dark')
    expect(document.documentElement.classList.contains('dark')).toBe(true)

    theme.cycle()
    expect(theme.current).toBe('system')
    expect(document.documentElement.classList.contains('dark')).toBe(false)
  })
})
