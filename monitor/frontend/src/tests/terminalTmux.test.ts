/// The terminal page's tmux block: the sessions `/tmux` answers with, what
/// Attach and New session send, and how a refusal is phrased.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'

const mocks = vi.hoisted(() => ({
  getTmux: vi.fn(),
  issueWsTicket: vi.fn(async () => ({ ticket: 'id.secret', expires_in: 30 })),
}))

vi.mock('../lib/xterm', () => ({
  terminalBackground: () => '#ffffff',
  mountTerminal: vi.fn(async () => ({
    renderer: {
      write: (_data: Uint8Array, done: () => void) => done(),
      reset() {},
      cols: 80,
      rows: 24,
    },
    setTheme() {},
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
      disablePasswordlessTerminal: vi.fn(),
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

vi.mock('../lib/layout.svelte', () => ({
  layout: { view: 'terminal', navigate: vi.fn(), back: vi.fn(), mobileOpen: false },
}))

vi.mock('../lib/snippetRun.svelte', () => ({
  snippetRun: { waiting: null, take: vi.fn(), clear: vi.fn() },
}))

vi.mock('../lib/theme.svelte', () => ({ theme: { current: 'light' } }))
vi.mock('../lib/terminalSurface.svelte', () => ({ terminalSurface: { current: '#ffffff' } }))

import Terminal from '../pages/Terminal.svelte'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { fmtEpochSeconds } from '../lib/format'

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
    this.onclose?.()
  }

  control(msg: unknown) {
    this.onmessage?.({ data: JSON.stringify(msg) })
  }
}

function setCapabilities(features: string[]) {
  ;(capabilitiesStore as unknown as { byServer: Record<string, unknown> }).byServer['local'] = {
    platform: 'linux',
    features,
    me: { username: 'admin', admin: true },
    grants: {
      shell: { ok: true },
      ssh_terminal: { ok: true },
      files: { ok: false, why: 'not_granted' },
      connect: { ok: true },
      listen: { ok: true },
    },
  }
}

/// Seconds since the epoch, as `/tmux` sends the times.
const ACTIVITY = 1767261600

const SESSION = {
  id: '$1',
  name: 'work',
  windows: 2,
  attached: false,
  created: null,
  last_attached: null,
  activity: ACTIVITY,
}

/// The socket a press started, after the terminal has mounted.
async function started(): Promise<FakeSocket> {
  await vi.waitFor(() => expect(FakeSocket.instances.length).toBe(1))
  const socket = FakeSocket.instances[0]
  socket.onopen?.()
  return socket
}

beforeEach(() => {
  FakeSocket.instances = []
  mocks.getTmux.mockReset()
  mocks.issueWsTicket.mockClear()
  mocks.getTmux.mockResolvedValue({ available: true, sessions: [SESSION] })
  window.localStorage.clear()
  window.sessionStorage.clear()
  vi.stubGlobal('WebSocket', FakeSocket)
  setCapabilities(['tmux'])
})

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
})

describe('the terminal page tmux block', () => {
  it('lists the sessions and attaches with the session id', async () => {
    render(Terminal)

    expect(await screen.findByText('work')).toBeInTheDocument()
    // The activity is epoch seconds from the agent, formatted here.
    expect(screen.getByText(fmtEpochSeconds(ACTIVITY))).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: 'Attach' }))

    const socket = await started()
    expect(socket.sent[0]).toMatchObject({
      type: 'open',
      auth: { kind: 'local' },
      target: { kind: 'tmux', session: '$1' },
    })
  })

  it('starts a new session with the typed name', async () => {
    render(Terminal)

    await fireEvent.input(await screen.findByPlaceholderText('Session name'), {
      target: { value: 'lab' },
    })
    await fireEvent.click(screen.getByRole('button', { name: 'Create' }))

    const socket = await started()
    expect(socket.sent[0]).toMatchObject({
      type: 'open',
      auth: { kind: 'local' },
      target: { kind: 'tmux_new', name: 'lab' },
    })
  })

  it('shows nothing extra without the feature', async () => {
    setCapabilities([])
    render(Terminal)

    await screen.findByRole('button', { name: 'Open a terminal' })
    expect(mocks.getTmux).not.toHaveBeenCalled()
    expect(screen.queryByText('tmux sessions')).toBeNull()
    expect(screen.queryByRole('button', { name: 'Create' })).toBeNull()
  })

  it('shows nothing extra where tmux is not installed', async () => {
    mocks.getTmux.mockResolvedValue({ available: false, sessions: [] })
    render(Terminal)

    await screen.findByRole('button', { name: 'Open a terminal' })
    await vi.waitFor(() => expect(mocks.getTmux).toHaveBeenCalled())
    expect(screen.queryByText('tmux sessions')).toBeNull()
  })

  it('phrases a refused name from the issue', async () => {
    render(Terminal)

    await fireEvent.input(await screen.findByPlaceholderText('Session name'), {
      target: { value: 'a:b' },
    })
    await fireEvent.click(screen.getByRole('button', { name: 'Create' }))
    const socket = await started()
    socket.control({
      type: 'error',
      code: 'invalid_input',
      issue: 'name_separator',
      message: 'the session name contains \':\' or \'.\'',
    })

    expect(await screen.findByText(/cannot contain/i)).toBeInTheDocument()
  })

  it('phrases a machine with no tmux', async () => {
    render(Terminal)

    await fireEvent.click(await screen.findByRole('button', { name: 'Attach' }))
    const socket = await started()
    socket.control({
      type: 'error',
      code: 'no_tmux',
      message: 'This machine has no tmux to attach to',
    })

    expect(await screen.findByText(/tmux is not installed/i)).toBeInTheDocument()
  })
})
