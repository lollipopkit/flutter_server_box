import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { api } from '../lib/api'
import { servers } from '../lib/servers.svelte'

describe.each([
  ['JSON', () => api.getSettings()],
  ['file bytes', () => api.fsRead('/file')],
] as const)('%s session expiry', (_, request) => {
  beforeEach(() => {
    for (const entry of [...servers.list]) servers.remove(entry.id)
    servers.add('https://first.example')
    servers.login('old-token', 'admin')
  })

  afterEach(() => vi.unstubAllGlobals())

  function pending401() {
    let finish!: (response: Response) => void
    vi.stubGlobal('fetch', vi.fn(() => new Promise<Response>((resolve) => { finish = resolve })))
    const result = request().catch((error: unknown) => error)
    return async () => {
      finish(new Response(null, { status: 401 }))
      expect(await result).toMatchObject({ status: 401 })
    }
  }

  it('expires only the server that sent the request', async () => {
    const first = servers.currentId
    const finish = pending401()
    servers.add('https://second.example')
    servers.login('second-token', 'admin')
    await finish()
    expect(servers.current?.token).toBe('second-token')
    expect(servers.list.find((entry) => entry.id === first)?.token).toBeNull()
  })

  it('preserves a session renewed while the request was pending', async () => {
    const finish = pending401()
    servers.login('new-token', 'admin')
    await finish()
    expect(servers.current?.token).toBe('new-token')
  })

  it('does not log out a replacement for a removed server', async () => {
    const finish = pending401()
    servers.remove(servers.currentId)
    servers.add('https://first.example')
    servers.login('replacement-token', 'admin')
    await finish()
    expect(servers.current?.token).toBe('replacement-token')
  })

  it('preserves the session when the endpoint changes', async () => {
    const finish = pending401()
    servers.update(servers.currentId, 'https://replacement.example')
    servers.login('old-token', 'admin')
    await finish()
    expect(servers.current?.token).toBe('old-token')
  })
})

// The agent nests the figures under `estimate`; the page reads one flat object.
// Returned as the agent sends it, the page drew "about undefined minutes".
describe('estimateBenchmark', () => {
  beforeEach(() => {
    for (const entry of [...servers.list]) servers.remove(entry.id)
    servers.add('https://first.example')
    servers.login('token', 'admin')
  })

  afterEach(() => vi.unstubAllGlobals())

  it('flattens the agent answer into the page shape', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        Response.json({
          estimate: { minutes: 14, traffic_bytes: 90, required_free_bytes: null },
          system_info_only: true,
        }),
      ),
    )
    expect(await api.estimateBenchmark({} as never)).toEqual({
      minutes: 14,
      traffic_bytes: 90,
      required_free_bytes: null,
      system_info_only: true,
    })
  })
})
