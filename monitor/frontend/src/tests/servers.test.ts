/// What the server list starts as, and what happens to that assumption.
///
/// It starts holding one entry for the origin the panel was served from. On an
/// agent that is right; hosted statically it is a server that cannot exist, and
/// it used to sit there reporting "Connected" — the origin answers /health with
/// index.html, 200.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

async function freshStore() {
  vi.resetModules()
  return (await import('../lib/servers.svelte')).servers
}

function serveHtml() {
  vi.stubGlobal(
    'fetch',
    vi.fn(
      async () =>
        new Response('<!doctype html><html></html>', {
          status: 200,
          headers: { 'content-type': 'text/html' },
        }),
    ),
  )
}

function serveAgent() {
  vi.stubGlobal(
    'fetch',
    vi.fn(async () => new Response(JSON.stringify({ status: 'healthy' }), { status: 200 })),
  )
}

describe('servers', () => {
  beforeEach(() => {
    window.localStorage.clear()
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('starts by assuming the origin is an agent', async () => {
    const servers = await freshStore()

    expect(servers.list).toHaveLength(1)
    expect(servers.current?.url).toBe('')
    expect(servers.empty).toBe(false)
  })

  it('drops that entry once the origin turns out to be a static host', async () => {
    serveHtml()
    const servers = await freshStore()

    await servers.confirmSameOrigin()

    expect(servers.empty).toBe(true)
    expect(servers.current).toBeUndefined()
    expect(servers.authenticated).toBe(false)
  })

  it('keeps it when the origin really is an agent', async () => {
    serveAgent()
    const servers = await freshStore()

    await servers.confirmSameOrigin()

    expect(servers.list).toHaveLength(1)
  })

  it('keeps it when the origin answers nothing, which is a restart', async () => {
    // The distinction the panel turns on: only a well-formed answer from
    // something that is not an agent is grounds for dropping an entry, since
    // dropping it discards a saved session.
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new TypeError('failed to fetch')
      }),
    )
    const servers = await freshStore()

    await servers.confirmSameOrigin()

    expect(servers.list).toHaveLength(1)
  })

  it('leaves the assumption alone once a real server has been added', async () => {
    serveHtml()
    const servers = await freshStore()
    servers.add('https://agent.example')

    await servers.confirmSameOrigin()

    // Two entries, so the list is no longer just the guess — whatever the user
    // has done with it since is theirs.
    expect(servers.list).toHaveLength(2)
  })

  it('the last server can be removed, which the empty state needs', async () => {
    const servers = await freshStore()
    servers.remove(servers.list[0].id)

    expect(servers.empty).toBe(true)
    expect(servers.currentId).toBe('')
  })
})
