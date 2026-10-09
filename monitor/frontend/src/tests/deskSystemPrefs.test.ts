import { beforeEach, describe, expect, it, vi } from 'vitest'

describe('system preferences', () => {
  beforeEach(() => {
    window.localStorage.clear()
    vi.resetModules()
  })

  it('starts from the defaults and refuses what it does not know', async () => {
    window.localStorage.setItem('desk.system', JSON.stringify({ refreshSeconds: 3, density: 'airy', textSize: 'xl', openOnStart: 'terminal', banners: 0 }))
    const { systemPrefs } = await import('../desk/sys/systemPrefs.svelte')
    expect(systemPrefs.value).toMatchObject({ refreshSeconds: 2, density: 'compact', textSize: 'm', openOnStart: 'status', banners: true })
    expect(systemPrefs.refreshMs).toBe(2000)
  })

  it('keeps a change for the next page', async () => {
    const { systemPrefs } = await import('../desk/sys/systemPrefs.svelte')
    systemPrefs.set({ refreshSeconds: 5, autoRefresh: false, openOnStart: 'none' })
    vi.resetModules()
    const again = (await import('../desk/sys/systemPrefs.svelte')).systemPrefs
    expect(again.value).toMatchObject({ refreshSeconds: 5, autoRefresh: false, openOnStart: 'none' })
  })
})
