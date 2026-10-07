/// The desk terminal opens a local shell, rejoins its stored session, and
/// keeps tmux targets available without offering SSH credentials.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'

const mocks = vi.hoisted(() => ({
  getTmux: vi.fn(),
  issueWsTicket: vi.fn(async () => ({ ticket: 'id.secret', expires_in: 30 })),
  disablePasswordlessTerminal: vi.fn(async () => undefined),
}))

vi.mock('../lib/xterm', () => ({
  mountTerminal: vi.fn(async () => ({
    renderer: {
      write: (_data: Uint8Array, done: () => void) => done(),
      reset() {},
      cols: 80,
      rows: 24,
    },
    setTheme() {},
    setLook() {},
    focus() {},
    dispose() {},
  })),
}))

vi.mock('../lib/api', () => {
  class ApiError extends Error {
    status?: number
    code?: string
    constructor(message: string, status?: number, code?: string) {
      super(message)
      this.status = status
      this.code = code
    }
  }
  return {
    ApiError,
    api: {
      getTmux: mocks.getTmux,
      issueWsTicket: mocks.issueWsTicket,
      disablePasswordlessTerminal: mocks.disablePasswordlessTerminal,
    },
  }
})

vi.mock('../lib/servers.svelte', () => ({
  servers: {
    currentId: 'local',
    list: [{ id: 'local', url: '', token: 't', username: 'admin' }],
  },
  displayName: (e: { url: string; id: string }) => e.url || e.id,
}))

vi.mock('../lib/capabilities.svelte', () => ({
  capabilitiesStore: { byServer: {}, clear: vi.fn() },
}))

vi.mock('../lib/theme.svelte', () => ({ theme: { current: 'light' } }))
vi.mock('../lib/terminalSurface.svelte', () => ({ terminalSurface: { current: '#ffffff' } }))

import Terminal from '../desk/apps/terminal/TerminalApp.svelte'
import TerminalWindowHarness from './fixtures/TerminalWindowHarness.svelte'
import { capabilitiesStore } from '../lib/capabilities.svelte'

class FakeSocket {
  static instances: FakeSocket[] = []
  static readonly OPEN = 1

  readyState = FakeSocket.OPEN
  sent: unknown[] = []
  onopen: (() => void) | null = null
  onmessage: ((e: { data: string | ArrayBuffer }) => void) | null = null
  onclose: (() => void) | null = null
  onerror: (() => void) | null = null
  binaryType = 'arraybuffer'

  constructor(
    public url: string,
    public protocols?: string | string[],
  ) {
    FakeSocket.instances.push(this)
  }

  send(payload: string | Uint8Array) {
    if (typeof payload === 'string') this.sent.push(JSON.parse(payload))
  }

  close() {
    this.readyState = 3
    this.onclose?.()
  }

  control(msg: unknown) {
    this.onmessage?.({ data: JSON.stringify(msg) })
  }
}

function setCapabilities({ shell = true, ssh = true, features = ['tmux'], admin = true } = {}) {
  ;(capabilitiesStore as unknown as { byServer: Record<string, unknown> }).byServer['local'] = {
    platform: 'linux',
    features,
    me: { username: 'admin', admin },
    grants: {
      shell: { ok: shell, why: shell ? undefined : 'not_granted' },
      ssh_terminal: { ok: ssh, why: ssh ? undefined : 'not_granted' },
      files: { ok: false, why: 'not_granted' },
      connect: { ok: true },
      listen: { ok: true },
    },
  }
}

const SESSION = {
  id: '$1',
  name: 'work',
  windows: 2,
  attached: false,
  created: null,
  last_attached: null,
  activity: 1767261600,
}

function sessionMenu() {
  return screen.getByRole('button', { name: 'tmux sessions' })
}

async function started(index = 0): Promise<FakeSocket> {
  await waitFor(() => expect(FakeSocket.instances.length).toBeGreaterThan(index))
  const socket = FakeSocket.instances[index]
  socket.onopen?.()
  await waitFor(() => expect(socket.sent.length).toBeGreaterThan(0))
  return socket
}

beforeEach(() => {
  FakeSocket.instances = []
  mocks.getTmux.mockReset()
  mocks.issueWsTicket.mockClear()
  mocks.disablePasswordlessTerminal.mockReset()
  mocks.disablePasswordlessTerminal.mockResolvedValue(undefined)
  mocks.getTmux.mockResolvedValue({ available: true, sessions: [SESSION], error: null })
  window.localStorage.clear()
  window.sessionStorage.clear()
  vi.stubGlobal('WebSocket', FakeSocket)
  setCapabilities()
})

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
})

describe('desk terminal app', () => {
  it('ends its shell when its window closes, and keeps it when only unmounted', async () => {
    const state = { closed: false }
    const kept = render(TerminalWindowHarness, { window: state })
    const first = await started()
    first.control({ type: 'ready', session: 'kept-handle', since: 0 })
    kept.unmount()
    // Unmounted with the window still there (suspended): no close frame.
    expect(first.sent).not.toContainEqual({ type: 'close' })

    const ended = render(TerminalWindowHarness, { window: state })
    const second = await started(1)
    second.control({ type: 'ready', session: 'kept-handle', since: 0 })
    state.closed = true
    ended.unmount()
    expect(second.sent).toContainEqual({ type: 'close' })
  })

  it('opens one local shell automatically without a target', async () => {
    render(Terminal)

    const socket = await started()
    expect(mocks.issueWsTicket).toHaveBeenCalledTimes(1)
    expect(socket.sent[0]).toMatchObject({
      type: 'open',
      auth: { kind: 'local' },
    })
    expect(socket.sent[0]).not.toHaveProperty('target')
    expect(screen.queryByRole('button', { name: 'Open a terminal' })).toBeNull()
  })

  it('reattaches a stored handle instead of opening a fresh shell', async () => {
    window.sessionStorage.setItem('terminal.session', JSON.stringify({ handle: 'saved-handle', rendered: 17 }))
    render(Terminal)

    const socket = await started()
    expect(socket.sent[0]).toEqual({ type: 'attach', session: 'saved-handle', since: 0, cols: 80, rows: 24 })
  })

  it('does not open a socket for ssh_terminal-only roles', async () => {
    setCapabilities({ shell: false, ssh: true, features: [] })
    render(Terminal)

    expect(await screen.findByText("This account's role does not include the shell.")).toBeInTheDocument()
    expect(FakeSocket.instances).toHaveLength(0)
    expect(mocks.issueWsTicket).not.toHaveBeenCalled()
    expect(screen.queryByLabelText(/SSH|password|private key/i)).toBeNull()
    expect(screen.queryByPlaceholderText('root')).toBeNull()
  })

  it('ends without reopening, then New session opens a fresh local shell', async () => {
    render(Terminal)
    const first = await started()
    first.control({ type: 'ready', session: 'first-handle', since: 0 })

    await fireEvent.click(await screen.findByRole('button', { name: 'End session' }))
    expect(FakeSocket.instances).toHaveLength(1)
    expect(await screen.findByText('Session ended')).toBeInTheDocument()

    await fireEvent.click(screen.getByRole('button', { name: 'New session' }))
    const second = await started(1)
    expect(second.sent[0]).toMatchObject({ type: 'open', auth: { kind: 'local' } })
    expect(second.sent[0]).not.toHaveProperty('target')
  })

  it('lists tmux sessions on demand and attaches the selected session', async () => {
    render(Terminal)
    const first = await started()
    first.control({ type: 'ready', session: 'first-handle', since: 0 })
    await fireEvent.click(sessionMenu())

    expect(await screen.findByText('work')).toBeInTheDocument()
    expect(screen.getByText(/windows: 2/)).toBeInTheDocument()
    expect(mocks.getTmux).toHaveBeenCalledTimes(1)
    await fireEvent.click(screen.getByRole('menuitem', { name: /work/ }))

    const socket = await started(1)
    expect(socket.sent[0]).toMatchObject({
      type: 'open',
      auth: { kind: 'local' },
      target: { kind: 'tmux', session: '$1' },
    })
  })

  it('creates a tmux session with a trimmed name from the dialog', async () => {
    render(Terminal)
    const first = await started()
    first.control({ type: 'ready', session: 'first-handle', since: 0 })
    await fireEvent.click(sessionMenu())
    await screen.findByText('work')
    await fireEvent.click(screen.getByRole('menuitem', { name: /New tmux session/ }))
    await fireEvent.input(screen.getByPlaceholderText('Session name'), { target: { value: ' lab ' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Create' }))

    const socket = await started(1)
    expect(socket.sent[0]).toMatchObject({
      type: 'open',
      auth: { kind: 'local' },
      target: { kind: 'tmux_new', name: 'lab' },
    })
  })

  it('phrases a refused tmux name from its issue code', async () => {
    render(Terminal)
    const first = await started()
    first.control({ type: 'ready', session: 'first-handle', since: 0 })
    await fireEvent.click(sessionMenu())
    await screen.findByText('work')
    await fireEvent.click(screen.getByRole('menuitem', { name: /New tmux session/ }))
    await fireEvent.input(screen.getByPlaceholderText('Session name'), { target: { value: 'a:b' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Create' }))
    const socket = await started(1)
    socket.control({
      type: 'error',
      code: 'invalid_input',
      issue: 'name_separator',
      message: "the session name contains ':' or '.'",
    })

    expect(await screen.findByText(/cannot contain/i)).toBeInTheDocument()
  })

  it('shows tmux listing failures in the toolbar popover', async () => {
    mocks.getTmux.mockResolvedValue({
      available: true,
      sessions: [],
      error: 'error connecting to /tmp/tmux-1000/default (Permission denied)',
    })
    render(Terminal)
    await fireEvent.click(sessionMenu())

    expect(await screen.findByText('Could not list tmux sessions')).toBeInTheDocument()
    expect(screen.getByText('error connecting to /tmp/tmux-1000/default (Permission denied)')).toBeInTheDocument()
  })

  it('shows the first-time notice and keeps it dismissed for this browser', async () => {
    render(Terminal)

    expect(await screen.findByText('This panel login can open a shell')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: 'Keep it on' }))
    expect(screen.queryByText('This panel login can open a shell')).toBeNull()
    expect(window.localStorage.getItem('terminal.fullAccessNoticeSeen')).toBe('1')
  })

  it('closes the shell and falls into the no-permission state when access is disabled', async () => {
    render(Terminal)
    const socket = await started()
    socket.control({ type: 'ready', session: 'live-handle', since: 0 })
    mocks.disablePasswordlessTerminal.mockResolvedValue(undefined)

    await fireEvent.click(await screen.findByRole('button', { name: 'Turn it off' }))

    expect(mocks.disablePasswordlessTerminal).toHaveBeenCalledOnce()
    expect(await screen.findByText('Your role on this agent does not include this. Ask one of its administrators.')).toBeInTheDocument()
    expect(sessionStorage.getItem('terminal.session')).toBeNull()
    expect(FakeSocket.instances).toHaveLength(1)
  })
})
