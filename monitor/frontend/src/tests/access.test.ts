import { get } from 'svelte/store'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { LL } from '../i18n/i18n-svelte'
import {
  accessMessage,
  accessProblem,
  dashboardAccess,
  draftFromRole,
  emptyDraft,
  filesAccess,
  isAdmin,
  parsePorts,
  roleFromDraft,
  terminalAccess,
  whyText,
} from '../lib/access'
import { api, ApiError } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { Capabilities, CallerGrants, Role } from '../types'

/// Capabilities with nothing about the platform worth reading: these tests
/// are about access only.
function caps(extra: Partial<Capabilities>): Capabilities {
  return { platform: 'linux', ...extra } as Capabilities
}

const off = { ok: false, why: 'not_granted' } as const

function grants(over: Partial<CallerGrants>): CallerGrants {
  return {
    shell: off,
    ssh_terminal: off,
    files: off,
    connect: off,
    listen: off,
    ...over,
  }
}

describe('the account and role endpoints', () => {
  let fetchMock: ReturnType<typeof vi.fn>

  beforeEach(() => {
    for (const entry of [...servers.list]) servers.remove(entry.id)
    servers.add('https://agent.example')
    servers.login('token', 'admin')
    fetchMock = vi.fn()
    vi.stubGlobal('fetch', fetchMock)
  })

  afterEach(() => vi.unstubAllGlobals())

  function answer(status: number, body?: unknown) {
    fetchMock.mockResolvedValueOnce(
      new Response(body === undefined ? null : JSON.stringify(body), { status }),
    )
  }

  it('reads a code and a message from an error, and maps the code', async () => {
    answer(403, { error: 'reauth', message: 'current password is wrong' })
    const error = await api.listUsers().catch((e: unknown) => e)
    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({ status: 403, code: 'reauth', message: 'current password is wrong' })
    expect(accessProblem(error)).toBe('reauth')
    expect(accessMessage(error, get(LL))).toBe(get(LL).accessErrReauth())
  })

  it.each([
    ['last_admin', 409],
    ['conflict', 409],
    ['forbidden', 403],
  ] as const)('%s has a sentence of its own', async (code, status) => {
    answer(status, { error: code, message: 'raw' })
    const error = await api.deleteRole('ops', 'pw').catch((e: unknown) => e)
    expect(accessProblem(error)).toBe(code)
    expect(accessMessage(error, get(LL))).not.toBe('raw')
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

  it('carries the administrator’s password, and escapes the name in the path', async () => {
    answer(204)
    await api.deleteUser('a/b', 'admin-pw')
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(url).toBe('https://agent.example/api/v1/users/a%2Fb')
    expect(init.method).toBe('DELETE')
    expect(JSON.parse(init.body as string)).toEqual({ current_password: 'admin-pw' })
  })

  it('sends a changed role alone, the rest kept', async () => {
    answer(200, { username: 'alice', role: 'viewer', created_at: null, last_login: null })
    await api.updateUser('alice', { role: 'viewer' }, 'pw')
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(JSON.parse(init.body as string)).toEqual({ role: 'viewer', current_password: 'pw' })
  })

  it('wraps a role in `role`, beside the password', async () => {
    const role: Role = {
      name: 'desktop',
      admin: false,
      builtin: false,
      grants: { shell: false, ssh_terminal: false, files: null, connect: { allow: [] }, listen: null },
    }
    answer(200, role)
    await api.updateRole(role, 'pw')
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(url).toBe('https://agent.example/api/v1/roles/desktop')
    expect(JSON.parse(init.body as string)).toEqual({ role, current_password: 'pw' })
  })
})

describe('what a page offers', () => {
  it('an agent before roles: everyone administers it', () => {
    expect(isAdmin(undefined)).toBeUndefined()
    expect(isAdmin(caps({}))).toBe(true)
    expect(isAdmin(caps({ me: { username: 'a', role: 'viewer', admin: false } }))).toBe(false)
  })

  it('an agent before roles answers as it did', () => {
    // Silence is not a refusal on the pages themselves...
    expect(terminalAccess(caps({})).available).toBe(true)
    expect(filesAccess(caps({}))).toEqual({ available: true, write: true })
    // ...while the dashboard offers only what it was told about.
    expect(dashboardAccess(caps({}))).toEqual({ terminal: false, files: false, viewOnly: true })

    const legacy = caps({ remote_access: { terminal: true, full_access: true, files: false } })
    expect(terminalAccess(legacy)).toEqual({ available: true, direct: true, ssh: true })
    expect(filesAccess(legacy).available).toBe(false)
    expect(dashboardAccess(legacy)).toEqual({ terminal: true, files: false, viewOnly: false })
  })

  it('the terminal: either kind opens it, and the SSH form needs its own grant', () => {
    const direct = terminalAccess(caps({ grants: grants({ shell: { ok: true } }) }))
    expect(direct).toMatchObject({ available: true, direct: true, ssh: false })

    const sshOnly = terminalAccess(caps({ grants: grants({ ssh_terminal: { ok: true } }) }))
    expect(sshOnly).toMatchObject({ available: true, direct: false, ssh: true })

    const none = terminalAccess(
      caps({
        grants: grants({ ssh_terminal: { ok: false, why: 'insecure_transport' } }),
      }),
    )
    expect(none).toMatchObject({ available: false, why: 'insecure_transport' })
    expect(whyText(none.why, get(LL))).toBe(get(LL).whyInsecureTransport())
  })

  it('files: a read-only role browses and writes nothing', () => {
    expect(filesAccess(caps({ grants: grants({ files: { ok: true, mode: 'read' } }) }))).toEqual({
      available: true,
      write: false,
      why: undefined,
    })
    expect(filesAccess(caps({ grants: grants({ files: { ok: true, mode: 'write' } }) })).write).toBe(true)
    const unset = filesAccess(caps({ grants: grants({ files: { ok: false, why: 'not_configured' } }) }))
    expect(unset).toMatchObject({ available: false, write: false, why: 'not_configured' })
  })

  it('the dashboard: forwards alone are not view-only', () => {
    expect(dashboardAccess(caps({ grants: grants({}) })).viewOnly).toBe(true)
    const forwards = dashboardAccess(caps({ grants: grants({ connect: { ok: true, allow: [] } }) }))
    expect(forwards).toEqual({ terminal: false, files: false, viewOnly: false })
  })
})

describe('the role editor', () => {
  it('stores a switched-off grant as null, whatever its fields say', () => {
    const draft = {
      ...emptyDraft(),
      name: 'desktop',
      connect: false,
      connectAllow: '127.0.0.1:3389',
      listen: false,
      listenPorts: 'not a port',
    }
    expect(roleFromDraft(draft)).toEqual({
      name: 'desktop',
      admin: false,
      builtin: false,
      grants: { shell: false, ssh_terminal: false, files: null, connect: null, listen: null },
    })
  })

  it('splits destinations on lines and commas, and an empty list allows any', () => {
    const some = roleFromDraft({
      ...emptyDraft(),
      name: 'desktop',
      connect: true,
      connectAllow: ' 127.0.0.1:3389 \n\n10.0.0.0/8, [::1]:22 ',
    })
    expect(some).toMatchObject({
      grants: { connect: { allow: ['127.0.0.1:3389', '10.0.0.0/8', '[::1]:22'] } },
    })
    const any = roleFromDraft({ ...emptyDraft(), name: 'out', connect: true })
    expect(any).toMatchObject({ grants: { connect: { allow: [] } } })
  })

  it('reads ports as any, one, or a range', () => {
    expect(parsePorts('')).toBeNull()
    expect(parsePorts('8080')).toEqual([8080, 8080])
    expect(parsePorts('1024 - 65535')).toEqual([1024, 65535])
    for (const bad of ['0', '65536', '9000-80', 'http', '1-2-3']) {
      expect(parsePorts(bad)).toBe('invalid')
    }
    expect(
      roleFromDraft({ ...emptyDraft(), name: 'fwd', listen: true, listenPublic: true, listenPorts: '' }),
    ).toMatchObject({ grants: { listen: { public: true, ports: null } } })
    expect(
      roleFromDraft({ ...emptyDraft(), name: 'fwd', listen: true, listenPorts: '70000' }),
    ).toEqual({ error: 'ports' })
  })

  it('refuses a name the agent would', () => {
    for (const bad of ['', 'Ops', 'a b', 'x'.repeat(33)]) {
      expect(roleFromDraft({ ...emptyDraft(), name: bad })).toEqual({ error: 'name' })
    }
  })

  it('a role read back is the role saved', () => {
    const role: Role = {
      name: 'ops',
      admin: false,
      builtin: false,
      grants: {
        shell: true,
        ssh_terminal: false,
        files: { mode: 'read' },
        connect: { allow: ['10.0.0.0/8'] },
        listen: { public: false, ports: [8000, 8100] },
      },
    }
    expect(roleFromDraft(draftFromRole(role))).toEqual(role)
    // A single port written as one, not as a range of one.
    const one = { ...role, grants: { ...role.grants, listen: { public: true, ports: [22, 22] as [number, number] } } }
    expect(draftFromRole(one).listenPorts).toBe('22')
    expect(roleFromDraft(draftFromRole(one))).toEqual(one)
  })

  it('keeps the built-in administrator flag as it was', () => {
    const admin: Role = {
      name: 'admin',
      admin: true,
      builtin: true,
      grants: { shell: false, ssh_terminal: false, files: null, connect: null, listen: null },
    }
    expect(roleFromDraft(draftFromRole(admin))).toEqual(admin)
  })
})

/// `GET /api/v1/capabilities` as a real agent answered it, for an account in
/// a `desktop` role on a `read` install with no file roots — so the panel's
/// reading of the contract is checked against what the agent sends.
describe('a capabilities answer captured from the agent', () => {
  it('reads who is asking and what the role can use', async () => {
    const real = (await import('./fixtures/capabilities_desktop_role.json'))
      .default as unknown as Capabilities
    expect(isAdmin(real)).toBe(false)
    expect(terminalAccess(real)).toMatchObject({
      available: false,
      why: 'not_granted',
    })
    expect(filesAccess(real)).toEqual({
      available: false,
      write: false,
      why: 'not_configured',
    })
    // A forward is something to do, so the role is not view-only.
    expect(dashboardAccess(real).viewOnly).toBe(false)
  })
})
