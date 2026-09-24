/// What the server list starts as, what happens to that assumption, and how
/// many servers the panel holds.
///
/// It starts holding one entry for the origin the panel was served from. On an
/// agent that is right; hosted statically it is a server that cannot exist, and
/// it used to sit there reporting "Connected" — the origin answers /health with
/// index.html, 200. Whether that origin is an agent also decides whether this
/// panel takes a second server: the panel an agent serves is that machine's
/// face, and a server list there is a list of machines it has nothing to do
/// with.

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

function serveNothing() {
  vi.stubGlobal(
    'fetch',
    vi.fn(async () => {
      throw new TypeError('failed to fetch')
    }),
  )
}

describe('servers', () => {
  beforeEach(() => {
    window.localStorage.clear()
    window.sessionStorage.clear()
    // A shipped panel unless a test says otherwise: which of the two halves of
    // `servedByAgent` is in play is the deployment, not the code.
    vi.stubEnv('DEV', false)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.unstubAllEnvs()
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
    serveNothing()
    const servers = await freshStore()

    await servers.confirmSameOrigin()

    expect(servers.list).toHaveLength(1)
  })

  it('leaves a list that is no longer only the assumed entry alone', async () => {
    // A panel that already holds servers of its own keeps them: the assumed
    // entry is only ever the whole list, so a probe answering 'not-an-agent'
    // has nothing of the user's to take away. Only reachable from a build that
    // let a second server be added before this rule existed.
    window.localStorage.setItem(
      'servers.v1',
      JSON.stringify({
        list: [
          { id: 'local', url: '', token: null, username: null },
          { id: 'other', url: 'https://agent.example', token: null, username: null },
        ],
        currentId: 'other',
      }),
    )
    serveHtml()
    const servers = await freshStore()

    await servers.confirmSameOrigin()

    expect(servers.list).toHaveLength(2)
  })

  it('refuses a second server on the panel an agent serves', async () => {
    serveAgent()
    const servers = await freshStore()

    await servers.confirmSameOrigin()
    servers.add('https://other.example')

    expect(servers.servedByAgent).toBe(true)
    expect(servers.list).toHaveLength(1)
    expect(servers.current?.url).toBe('')
  })

  it('refuses it while that agent is down', async () => {
    // 'unreachable' is the case that makes this correct rather than convenient:
    // the page was loaded *from* the agent, so the panel is the agent's own
    // whatever the probe answers, and an agent mid-restart is not one the panel
    // has stopped belonging to.
    serveNothing()
    const servers = await freshStore()

    await servers.confirmSameOrigin()
    servers.add('https://other.example')

    expect(servers.servedByAgent).toBe(true)
    expect(servers.list).toHaveLength(1)
  })

  it('refuses one before the origin has answered', async () => {
    // Between the page loading and the probe's answer the panel is assumed to
    // be the agent's own. Adding there would put a second server on it in the
    // one deployment that must not have one; the affordance returns to every
    // other within a frame.
    serveHtml()
    const servers = await freshStore()

    servers.add('https://agent.example')
    expect(servers.list).toHaveLength(1)

    await servers.confirmSameOrigin()
    servers.add('https://agent.example')

    expect(servers.servedByAgent).toBe(false)
    expect(servers.list).toHaveLength(1)
    expect(servers.current?.url).toBe('https://agent.example')
  })

  it('takes servers on a panel the origin does not answer for', async () => {
    // Pages, and any other host serving the same `dist`.
    serveHtml()
    const servers = await freshStore()

    await servers.confirmSameOrigin()
    servers.add('https://agent.example')

    expect(servers.servedByAgent).toBe(false)
    expect(servers.current?.url).toBe('https://agent.example')
  })

  it('takes them on the dev server, which the probe cannot answer for', async () => {
    // `npm run dev` proxies /api to the agent `make monitor-dev` starts, so the
    // probe reaches that agent and answers as though this were its own panel.
    // The dev server is not one agent's panel, though: reaching a second agent
    // is what it is for.
    vi.stubEnv('DEV', true)
    serveAgent()
    const servers = await freshStore()

    await servers.confirmSameOrigin()
    servers.add('https://agent.example')

    expect(servers.servedByAgent).toBe(false)
    expect(servers.list).toHaveLength(2)
  })

  it('the last server can be removed, which the empty state needs', async () => {
    const servers = await freshStore()
    servers.remove(servers.list[0].id)

    expect(servers.empty).toBe(true)
    expect(servers.currentId).toBe('')
  })

  it('keeps bearer sessions out of localStorage', async () => {
    const servers = await freshStore()
    servers.login('secret-token', 'admin')

    const persisted = JSON.parse(window.localStorage.getItem('servers.v1')!)
    expect(persisted.list[0].token).toBeNull()
    expect(window.localStorage.getItem('token')).toBeNull()

    const sessions = JSON.parse(window.sessionStorage.getItem('servers.sessions.v1')!)
    expect(sessions.local).toEqual({ token: 'secret-token', username: 'admin' })
  })

  it('migrates legacy localStorage credentials into the tab session', async () => {
    window.localStorage.setItem('token', 'legacy-token')
    window.localStorage.setItem('username', 'legacy-user')

    const servers = await freshStore()

    expect(servers.current?.token).toBe('legacy-token')
    expect(window.localStorage.getItem('token')).toBeNull()
    expect(window.localStorage.getItem('username')).toBeNull()
    const sessions = JSON.parse(window.sessionStorage.getItem('servers.sessions.v1')!)
    expect(sessions.local).toEqual({ token: 'legacy-token', username: 'legacy-user' })
  })
})
