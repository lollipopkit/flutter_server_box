import { beforeEach, describe, expect, it, vi } from 'vitest'

describe('shell preferences', () => {
  beforeEach(() => {
    window.localStorage.clear()
    vi.resetModules()
  })

  it('starts from the defaults and refuses what it does not know', async () => {
    window.localStorage.setItem('desk.shell', JSON.stringify({ dockPosition: 'top', dockSize: 99, titlebar: 'solid', dockAutoHide: 'yes', iconShape: 'star' }))
    const { shellPrefs } = await import('../desk/shellPrefs.svelte')
    expect(shellPrefs.dockPosition).toBe('left')
    expect(shellPrefs.dockSize).toBe(44)
    expect(shellPrefs.titlebar).toBe('glass')
    expect(shellPrefs.dockAutoHide).toBe(false)
    expect(shellPrefs.iconShape).toBe('circle')
  })

  it('keeps the squircle once picked', async () => {
    window.localStorage.setItem('desk.shell', JSON.stringify({ iconShape: 'squircle' }))
    const { shellPrefs } = await import('../desk/shellPrefs.svelte')
    expect(shellPrefs.iconShape).toBe('squircle')
  })

  it('keeps room for the dock on its side, none when it hides', async () => {
    const { shellPrefs } = await import('../desk/shellPrefs.svelte')
    expect(shellPrefs.dockReserve(false)).toEqual({ left: 78, right: 0, bottom: 0 })
    shellPrefs.set({ dockPosition: 'right', dockSize: 54 })
    expect(shellPrefs.dockReserve(false)).toEqual({ left: 0, right: 88, bottom: 0 })
    // A phone keeps it at the bottom whatever was chosen.
    expect(shellPrefs.dockAt(true)).toBe('bottom')
    expect(shellPrefs.dockReserve(true).bottom).toBeGreaterThan(0)
    shellPrefs.set({ dockAutoHide: true })
    expect(shellPrefs.dockReserve(false)).toEqual({ left: 0, right: 0, bottom: 0 })
    expect(JSON.parse(window.localStorage.getItem('desk.shell')!)).toMatchObject({ dockPosition: 'right', dockSize: 54, dockAutoHide: true })
  })
})
