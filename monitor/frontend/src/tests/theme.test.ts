import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { crossfade, theme } from '../lib/theme.svelte'
import { terminalSurface } from '../lib/terminalSurface.svelte'

describe('theme', () => {
  beforeEach(() => {
    window.localStorage.removeItem('theme')
  })

  it('cycles system -> light -> dark, marking the mode in effect', () => {
    const root = document.documentElement
    const system = window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    while (theme.current !== 'system') theme.cycle()
    expect(root.dataset.theme).toBe(system)

    theme.cycle()
    expect(theme.current).toBe('light')
    expect(window.localStorage.getItem('theme')).toBe('light')
    expect(root.dataset.theme).toBe('light')

    theme.cycle()
    expect(theme.current).toBe('dark')
    expect(window.localStorage.getItem('theme')).toBe('dark')
    expect(root.dataset.theme).toBe('dark')

    theme.cycle()
    expect(theme.current).toBe('system')
    expect(root.dataset.theme).toBe(system)
  })

  it('gives the terminals a surface matching the terminal theme', () => {
    // The strip below a terminal's last row is filled with this, so it has to
    // be the colour xterm draws the rows in, not a colour of the panel's.
    theme.set('light')
    expect(terminalSurface.current).toBe('#ffffff')
    theme.set('dark')
    expect(terminalSurface.current).toBe('#0e0a0c')
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
