import { get } from 'svelte/store'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { LL } from '../i18n/i18n-svelte'
import {
  accessMessage,
  accessProblem,
  canAct,
  dashboardAccess,
  filesAccess,
  machineAccess,
  terminalAccess,
  whyText,
} from '../lib/access'
import { api, ApiError, loginTo } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { Capabilities } from '../types'

/// Capabilities with nothing about the platform worth reading: these tests
/// are about access only.
function caps(extra: Partial<Capabilities>): Capabilities {
  return { platform: 'linux', ...extra } as Capabilities
}

const secure = caps({ access: { ok: true }, features: ['power'] })
const plaintext = caps({ access: { ok: false, why: 'insecure_transport' }, features: ['power'] })

describe('the account endpoints', () => {
  let fetchMock: ReturnType<typeof vi.fn>

  beforeEach(() => {
    for (const entry of [...servers.list]) servers.remove(entry.id)
    servers.add('https://agent.example')
    servers.login('token')
    fetchMock = vi.fn()
    vi.stubGlobal('fetch', fetchMock)
  })

  afterEach(() => vi.unstubAllGlobals())

  function answer(status: number, body?: unknown) {
    fetchMock.mockResolvedValueOnce(
      new Response(body === undefined ? null : JSON.stringify(body), { status }),
    )
  }

  it('signs in with the password alone, then with the device token it was given', async () => {
    window.localStorage.removeItem('servers.devices.v1')
    answer(200, { token: 't', device: 'sbd_1' })
    await loginTo('https://agent.example', { password: 'pw' })
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(url).toBe('https://agent.example/api/v1/login')
    expect(JSON.parse(init.body as string)).toEqual({ password: 'pw' })

    answer(200, { token: 't' })
    await loginTo('https://agent.example', { password: 'pw' })
    const [, again] = fetchMock.mock.calls[1] as [string, RequestInit]
    expect(JSON.parse(again.body as string)).toEqual({ password: 'pw', device: 'sbd_1' })
    // Another agent gets none of it.
    answer(200, { token: 't' })
    await loginTo('https://other.example', { password: 'pw' })
    const [, other] = fetchMock.mock.calls[2] as [string, RequestInit]
    expect(JSON.parse(other.body as string)).toEqual({ password: 'pw' })
  })

  it('reads a code and a message from an error, and maps the code', async () => {
    answer(403, { error: 'reauth', message: 'current password is wrong' })
    const error = await api.changeMyPassword('wrong', 'new-password').catch((e: unknown) => e)
    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({ status: 403, code: 'reauth', message: 'current password is wrong' })
    expect(accessProblem(error)).toBe('reauth')
    expect(accessMessage(error, get(LL))).toBe(get(LL).accessErrReauth())
  })

  it('says why a plaintext link is refused', async () => {
    answer(403, { error: 'forbidden', message: 'insecure_transport' })
    const error = await api.changeMyPassword('old-password', 'new-password').catch((e: unknown) => e)
    expect(accessProblem(error)).toBe('forbidden')
    expect(accessMessage(error, get(LL))).toBe(get(LL).whyInsecureTransport())
  })

  it('keeps the older endpoints’ error, which is the message itself', async () => {
    answer(400, { error: 'interval must be positive' })
    const error = await api.getSettings().catch((e: unknown) => e)
    expect(error).toMatchObject({ message: 'interval must be positive', code: undefined })
    // Nothing to map: the agent's own words are the best there are.
    expect(accessMessage(error, get(LL))).toBe('interval must be positive')
  })

  it('accepts a 204 with no body', async () => {
    answer(204)
    await expect(api.changeMyPassword('old-password', 'new-password')).resolves.toBeUndefined()
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(url).toBe('https://agent.example/api/v1/me/password')
    expect(init.method).toBe('PUT')
    expect(JSON.parse(init.body as string)).toEqual({
      current_password: 'old-password',
      new_password: 'new-password',
    })
  })
})

describe('what the account may do over this link', () => {
  it('acts only where the agent says so', () => {
    expect(canAct(undefined)).toBe(false)
    expect(canAct(secure)).toBe(true)
    expect(canAct(plaintext)).toBe(false)
  })

  it('offers a machine page the agent serves, over a link the account may act on', () => {
    expect(machineAccess(secure, 'power')).toBe(true)
    expect(machineAccess(plaintext, 'power')).toBe(false)
    expect(machineAccess(secure, 'process')).toBe(false)
    expect(machineAccess(undefined, 'power')).toBe(false)
  })

  it('does not read capabilities not yet in as a refusal for the terminal and files', () => {
    expect(terminalAccess(undefined)).toEqual({ available: true, why: undefined })
    expect(filesAccess(secure)).toEqual({ available: true, why: undefined })
    const refused = terminalAccess(plaintext)
    expect(refused).toEqual({ available: false, why: 'insecure_transport' })
    expect(whyText(refused.why, get(LL))).toBe(get(LL).whyInsecureTransport())
    // A watch token's `{ok: false}` names no reason.
    expect(whyText(terminalAccess(caps({ access: { ok: false } })).why, get(LL))).toBe(get(LL).whyReadOnly())
  })

  it('tells the dashboard whether it can only watch', () => {
    expect(dashboardAccess(undefined)).toEqual({ terminal: false, files: false, viewOnly: false })
    expect(dashboardAccess(secure)).toEqual({ terminal: true, files: true, viewOnly: false })
    expect(dashboardAccess(plaintext)).toEqual({ terminal: false, files: false, viewOnly: true })
  })
})

/// `GET /api/v1/capabilities` as the agent answers it over a plaintext link
/// — the fixture the agent's own `permissions_api.rs` checks against its
/// answer, so the panel's reading of the contract is checked against what it
/// sends.
describe('a capabilities answer from the agent', () => {
  it('reads that only reading is left', async () => {
    const real = (await import('../../../../test/fixtures/monitor/capabilities_insecure.json')).default as unknown as Capabilities
    expect(canAct(real)).toBe(false)
    expect(terminalAccess(real)).toEqual({ available: false, why: 'insecure_transport' })
    expect(machineAccess(real, 'power')).toBe(false)
    expect(dashboardAccess(real).viewOnly).toBe(true)
  })
})
