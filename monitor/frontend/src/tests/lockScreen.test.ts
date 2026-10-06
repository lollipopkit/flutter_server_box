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

  it('signs in to the chosen server and unlocks it', async () => {
    const id = addServer('https://a.example')
    mockedLogin.mockResolvedValue({ token: 'tok' })
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    await fireEvent.input(screen.getByLabelText('Username'), { target: { value: ' admin ' } })
    await fireEvent.input(screen.getByLabelText('Password'), { target: { value: 'pw' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    await waitFor(() => expect(onunlock).toHaveBeenCalledWith(id))
    expect(mockedLogin).toHaveBeenCalledWith('https://a.example', { username: 'admin', password: 'pw' })
    expect(servers.list.find((s) => s.id === id)?.token).toBe('tok')
  })

  it('says why a sign-in failed and stays locked', async () => {
    addServer('https://a.example')
    mockedLogin.mockRejectedValue(new ApiError('Invalid credentials', 401))
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    await fireEvent.input(screen.getByLabelText('Username'), { target: { value: 'x' } })
    await fireEvent.input(screen.getByLabelText('Password'), { target: { value: 'y' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByText('Invalid credentials')).toBeInTheDocument()
    expect(onunlock).not.toHaveBeenCalled()
  })

  it('a server already signed in to only needs unlocking', async () => {
    const id = addServer('https://a.example', 'tok')
    const onunlock = vi.fn()
    render(LockScreen, { onunlock })

    await fireEvent.click(screen.getByRole('button', { name: /Unlock/ }))
    expect(onunlock).toHaveBeenCalledWith(id)
    expect(mockedLogin).not.toHaveBeenCalled()
  })

  it('connects a new server only when it answers', async () => {
    addServer('https://a.example')
    render(LockScreen, { onunlock: vi.fn() })
    await fireEvent.click(screen.getByRole('button', { name: 'Connect…' }))

    mockedTest.mockResolvedValue(false)
    await fireEvent.input(screen.getByLabelText('Server URL'), { target: { value: 'https://b.example' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Connect' }))
    expect(await screen.findByText('No server answered at that address')).toBeInTheDocument()
    expect(servers.list).toHaveLength(1)

    mockedTest.mockResolvedValue(true)
    await fireEvent.click(screen.getByRole('button', { name: 'Connect' }))
    await waitFor(() => expect(servers.list.map((s) => s.url)).toContain('https://b.example'))
  })

  it('offers neither connecting nor removing on the panel an agent serves', () => {
    addServer('https://a.example')
    servers.servedByAgent = true
    render(LockScreen, { onunlock: vi.fn() })
    expect(screen.queryByRole('button', { name: 'Connect…' })).toBeNull()
    expect(screen.queryByRole('button', { name: 'Remove server' })).toBeNull()
  })
})
