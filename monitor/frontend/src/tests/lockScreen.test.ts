import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import LockScreen from '../desk/lock/LockScreen.svelte'
import { ApiError, loginTo, testConnection } from '../lib/api'
import { servers } from '../lib/servers.svelte'

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
    if (token) servers.setSession(servers.currentId, token, 'admin')
    return servers.currentId
  }

  async function fill(label: string, value: string) {
    await fireEvent.input(screen.getByLabelText(label), { target: { value } })
  }

  it('signs in to the chosen server, remembers the account, and unlocks it', async () => {
    const id = addServer('https://a.example')
    mockedLogin.mockResolvedValue({ token: 'tok' })
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    await fill('Username', ' admin ')
    await fill('Password', 'pw')
    await fireEvent.click(screen.getByRole('button', { name: /^Sign in/ }))

    await waitFor(() => expect(onunlock).toHaveBeenCalledWith(id))
    expect(mockedLogin).toHaveBeenCalledWith('https://a.example', { username: 'admin', password: 'pw' })
    expect(servers.list.find((s) => s.id === id)?.token).toBe('tok')
    expect(servers.accountsOf(id).map((a) => a.username)).toEqual(['admin'])
  })

  it('says why a sign-in failed and stays locked', async () => {
    addServer('https://a.example')
    mockedLogin.mockRejectedValue(new ApiError('Invalid credentials', 401))
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    await fill('Username', 'x')
    await fill('Password', 'y')
    await fireEvent.click(screen.getByRole('button', { name: /^Sign in/ }))

    expect(await screen.findByText('Wrong username or password')).toBeInTheDocument()
    expect(onunlock).not.toHaveBeenCalled()
  })

  it('a server already signed in to only needs unlocking', async () => {
    const id = addServer('https://a.example', 'tok')
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    await fireEvent.click(screen.getByRole('button', { name: /^Unlock/ }))
    await waitFor(() => expect(onunlock).toHaveBeenCalledWith(id))
    expect(mockedLogin).not.toHaveBeenCalled()
  })

  it('a remembered account without a session asks only for its password', async () => {
    const id = addServer('https://a.example')
    servers.signIn(id, 'deploy', 'old', true)
    servers.logout(id)
    mockedLogin.mockResolvedValue({ token: 'new' })
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    expect(screen.queryByLabelText('Username')).toBeNull()
    expect(screen.getByPlaceholderText("deploy's password")).toBeInTheDocument()
    await fill('Password', 'pw')
    await fireEvent.click(screen.getByRole('button', { name: /^Sign in/ }))

    await waitFor(() => expect(onunlock).toHaveBeenCalledWith(id))
    expect(mockedLogin).toHaveBeenCalledWith('https://a.example', { username: 'deploy', password: 'pw' })
  })

  it('connects and signs in to a new server only when it answers', async () => {
    addServer('https://a.example')
    mockedLogin.mockResolvedValue({ token: 'tok' })
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })
    await fireEvent.click(screen.getByRole('button', { name: 'Connect to another instance' }))

    mockedTest.mockResolvedValue(false)
    await fill('Server URL', 'https://b.example')
    await fill('Username', 'admin')
    await fill('Password', 'pw')
    await fireEvent.click(screen.getByRole('button', { name: /^Connect and sign in/ }))
    expect(await screen.findByText('No server answered at that address')).toBeInTheDocument()
    expect(servers.list).toHaveLength(1)

    mockedTest.mockResolvedValue(true)
    await fireEvent.click(screen.getByRole('button', { name: /^Connect and sign in/ }))
    await waitFor(() => expect(servers.list.map((s) => s.url)).toContain('https://b.example'))
    const added = servers.list.find((s) => s.url === 'https://b.example')!
    await waitFor(() => expect(onunlock).toHaveBeenCalledWith(added.id))
  })

  it('lists several servers and switches between them with the arrow keys', async () => {
    addServer('https://a.example')
    addServer('https://b.example')
    render(LockScreen, { onunlock: vi.fn() })

    expect(screen.getByText('Instances')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Connect a new instance/ })).toBeInTheDocument()
    expect(screen.getAllByText('b.example').length).toBeGreaterThan(0)
    await fireEvent.keyDown(window, { key: 'ArrowDown' })
    // Past the last server: a new one.
    expect(await screen.findByText('New instance')).toBeInTheDocument()
  })

  it('offers neither connecting nor removing on the panel an agent serves', () => {
    addServer('https://a.example')
    servers.servedByAgent = true
    render(LockScreen, { onunlock: vi.fn() })
    expect(screen.queryByRole('button', { name: /Connect/ })).toBeNull()
    expect(screen.queryByRole('button', { name: 'Remove server' })).toBeNull()
  })
})
