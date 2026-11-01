import { get } from 'svelte/store'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import LockScreen from '../desk/lock/LockScreen.svelte'
import { ApiError, loginTo, testConnection } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import { LL } from '../i18n/i18n-svelte'

const ll = get(LL)

// Partial mock: ApiError stays real so instanceof narrowing works.
vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  loginTo: vi.fn(),
  testConnection: vi.fn(),
  getCapabilitiesFor: vi.fn(async () => {
    throw new Error('not in this test')
  }),
  getStatusFor: vi.fn(async () => {
    throw new Error('not in this test')
  }),
}))
const mockedLogin = vi.mocked(loginTo)
const mockedTest = vi.mocked(testConnection)

// jsdom has no Web Animations API, which the transitions reach for.
Element.prototype.animate ??= function (this: Element) {
  return { cancel() {}, playState: 'idle' } as unknown as Animation
}

describe('LockScreen', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    for (const s of [...servers.list]) servers.remove(s.id)
    servers.servedByAgent = false
  })

  function addServer(url: string, token: string | null = null) {
    servers.add(url)
    if (token) servers.setSession(servers.currentId, token)
    return servers.currentId
  }

  async function fill(label: string, value: string) {
    await fireEvent.input(screen.getByLabelText(label), { target: { value } })
  }

  it('signs in to the chosen server with its password alone, and unlocks it', async () => {
    const id = addServer('https://a.example')
    mockedLogin.mockResolvedValue({ token: 'tok' })
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    expect(screen.queryByLabelText(ll.username())).toBeNull()
    await fill(ll.password(), 'pw')
    await fireEvent.click(screen.getByRole('button', { name: (name) => name.startsWith(ll.signIn()) }))

    await waitFor(() => expect(onunlock).toHaveBeenCalledWith(id))
    expect(mockedLogin).toHaveBeenCalledWith('https://a.example', { password: 'pw' })
    expect(servers.list.find((s) => s.id === id)?.token).toBe('tok')
  })

  it('says why a sign-in failed and stays locked', async () => {
    addServer('https://a.example')
    mockedLogin.mockRejectedValue(new ApiError('Invalid credentials', 401))
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    await fill(ll.password(), 'y')
    await fireEvent.click(screen.getByRole('button', { name: (name) => name.startsWith(ll.signIn()) }))

    expect(await screen.findByText(ll.accessErrReauth())).toBeInTheDocument()
    expect(onunlock).not.toHaveBeenCalled()
  })

  it('a server already signed in to only needs unlocking', async () => {
    const id = addServer('https://a.example', 'tok')
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    await fireEvent.click(screen.getByRole('button', { name: (name) => name.startsWith(ll.deskUnlock()) }))
    await waitFor(() => expect(onunlock).toHaveBeenCalledWith(id))
    expect(mockedLogin).not.toHaveBeenCalled()
  })

  it('connects and signs in to a new server only when it answers', async () => {
    addServer('https://a.example')
    mockedLogin.mockResolvedValue({ token: 'tok' })
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })
    await fireEvent.click(screen.getByRole('button', { name: ll.lockConnectOther() }))

    mockedTest.mockResolvedValue(false)
    await fill(ll.serverUrlLabel(), 'https://b.example')
    await fill(ll.password(), 'pw')
    await fireEvent.click(screen.getByRole('button', { name: (name) => name.startsWith(ll.lockConnectAndSignIn()) }))
    expect(await screen.findByText(ll.deskUnreachable())).toBeInTheDocument()
    expect(servers.list).toHaveLength(1)

    mockedTest.mockResolvedValue(true)
    await fireEvent.click(screen.getByRole('button', { name: (name) => name.startsWith(ll.lockConnectAndSignIn()) }))
    await waitFor(() => expect(servers.list.map((s) => s.url)).toContain('https://b.example'))
    const added = servers.list.find((s) => s.url === 'https://b.example')!
    await waitFor(() => expect(onunlock).toHaveBeenCalledWith(added.id))
  })

  it('lists several servers and switches between them with the arrow keys', async () => {
    addServer('https://a.example')
    addServer('https://b.example')
    render(LockScreen, { onunlock: vi.fn() })

    expect(screen.getByText(ll.lockInstances())).toBeInTheDocument()
    expect(screen.getByRole('button', { name: (name) => name.includes(ll.lockConnectNew()) })).toBeInTheDocument()
    expect(screen.getAllByText('b.example').length).toBeGreaterThan(0)
    await fireEvent.keyDown(window, { key: 'ArrowDown' })
    // Past the last server: a new one.
    expect(await screen.findByText(ll.lockNewInstance())).toBeInTheDocument()
  })

  it('offers neither connecting nor removing on the panel an agent serves', () => {
    addServer('https://a.example')
    servers.servedByAgent = true
    render(LockScreen, { onunlock: vi.fn() })
    expect(screen.queryByRole('button', { name: (name) => [ll.lockConnectOther(), ll.lockConnectNew(), ll.lockConnectAndSignIn()].some((c) => name.includes(c)) })).toBeNull()
    expect(screen.queryByRole('button', { name: ll.removeServer() })).toBeNull()
  })
})
