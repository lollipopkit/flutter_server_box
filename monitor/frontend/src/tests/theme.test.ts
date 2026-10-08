import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { crossfade, theme } from '../lib/theme.svelte'
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

describe('crossfade', () => {
  let desk: HTMLElement
  const start = vi.fn((update: () => void) => update())
  beforeEach(() => {
    desk = document.createElement('div')
    desk.className = 'lk desk-root'
    desk.style.setProperty('--dur-window', '450ms')
    document.body.append(desk)
    Object.assign(document, { startViewTransition: start })
    start.mockClear()
    theme.lock(null)
    theme.set('light')
    start.mockClear()
  })
  afterEach(() => {
    desk.remove()
    delete (document as { startViewTransition?: unknown }).startViewTransition
  })

  it('fades a mode change that shows, at the design system pace', () => {
    theme.set('dark')
    expect(start).toHaveBeenCalledTimes(1)
    expect(theme.dark).toBe(true)
    expect(document.documentElement.style.getPropertyValue('--appearance-fade')).toBe('450ms')
  })

  it('does not fade a choice that looks the same, or while a theme holds the mode', () => {
    theme.set('light')
    theme.lock('dark')
    theme.set('dark')
    expect(start).not.toHaveBeenCalled()
    theme.lock(null)
  })

  it('folds a change made inside another into it', () => {
    crossfade(() => theme.set('dark'))
    expect(start).toHaveBeenCalledTimes(1)
    expect(theme.dark).toBe(true)
  })

  it('changes at once without a desk on screen', () => {
    desk.remove()
    theme.set('dark')
    expect(start).not.toHaveBeenCalled()
    expect(theme.dark).toBe(true)
  })
})
