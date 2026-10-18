import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { api, getCapabilitiesFor, loginTo } from '../lib/api'
import { PROTOCOL, PROTOCOL_HEADER } from '../lib/protocol'
import { servers } from '../lib/servers.svelte'

describe('protocol', () => {
  let sent: Headers[]

  beforeEach(() => {
    for (const entry of [...servers.list]) servers.remove(entry.id)
    servers.add('https://agent.example')
    servers.login('token', 'admin')
    sent = []
    vi.stubGlobal('fetch', vi.fn(async (_: string, init?: RequestInit) => {
      sent.push(new Headers(init?.headers))
      return new Response('{}', { status: 200 })
    }))
  })

  afterEach(() => vi.unstubAllGlobals())

  it('is named on every kind of request', async () => {
    await api.getSettings()
    await api.fsRead('/file')
    await getCapabilitiesFor(servers.current!)
    await loginTo('https://agent.example', { username: 'admin', password: 'pw' })
    expect(sent).toHaveLength(4)
    for (const headers of sent) expect(headers.get(PROTOCOL_HEADER)).toBe(String(PROTOCOL))
  })

  it('a 426 says the panel is the one to update', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('{"error":"client_too_old"}', { status: 426 })))
    await expect(api.getSettings()).rejects.toMatchObject({ status: 426, code: 'client_too_old' })
  })
})
