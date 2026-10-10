import { describe, it, expect, vi, afterEach } from 'vitest'
import { panelBuild } from '../lib/panelBuild.svelte'
import { servers } from '../lib/servers.svelte'

afterEach(() => {
  vi.unstubAllGlobals()
  panelBuild.stale = false
})

describe('the panel build', () => {
  it('is stale once the agent serves another build', async () => {
    servers.servedByAgent = true
    const fetch = vi.fn().mockResolvedValue(new Response('test\n'))
    vi.stubGlobal('fetch', fetch)
    await panelBuild.check()
    expect(fetch).toHaveBeenCalledWith('/build.txt', { cache: 'no-store' })
    expect(panelBuild.stale).toBe(false)
    fetch.mockResolvedValue(new Response('newer\n'))
    await panelBuild.check()
    expect(panelBuild.stale).toBe(true)
  })

  it('asks nothing of a static host', async () => {
    servers.servedByAgent = false
    const fetch = vi.fn()
    vi.stubGlobal('fetch', fetch)
    await panelBuild.check()
    expect(fetch).not.toHaveBeenCalled()
  })
})
