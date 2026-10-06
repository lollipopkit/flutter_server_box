import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, cleanup } from '@testing-library/svelte'
import TargetTerminal from '../components/TargetTerminal.svelte'
import { servers } from '../lib/servers.svelte'
import { mountTerminal } from '../lib/xterm'

/// The component mounts xterm through `lib/xterm`; stubbed so this test is
/// about the session it drives, not about a DOM renderer.
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
    focus: vi.fn(),
    dispose() {},
  })),
}))

const ticketMock = vi.fn(async () => ({ ticket: 'id.secret', expires_in: 30 }))

vi.mock('../lib/api', () => {
  class ApiError extends Error {
    status?: number
    constructor(message: string, status?: number) {
      super(message)
      this.status = status
    }
  }
  return {
    ApiError,
    api: { issueWsTicket: (...args: unknown[]) => ticketMock(...(args as [])) },
  }
})

/// Only the surface `TerminalSession` uses.
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

describe('TargetTerminal', () => {
  beforeEach(() => {
    FakeSocket.instances = []
    ticketMock.mockClear()
    vi.stubGlobal('WebSocket', FakeSocket)
    servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
    servers.currentId = 'local'
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
  })

  it('opens a container shell for the target, and closes it when the dialog goes away', async () => {
    // `target` is also a Svelte mount option, so the prop goes under `props`.
    const { unmount } = render(TargetTerminal, {
      props: { target: { kind: 'container', id: 'abc' } },
    })
    await vi.waitFor(() => expect(FakeSocket.instances.length).toBe(1))
    const socket = FakeSocket.instances[0]
    socket.onopen?.()

    expect(socket.sent[0]).toMatchObject({
      type: 'open',
      auth: { kind: 'local' },
      target: { kind: 'container', id: 'abc' },
    })
    socket.control({ type: 'ready', session: 'abc.def', since: 0 })

    unmount()
    // The agent is told, rather than left holding the shell until it times out.
    expect(socket.sent.at(-1)).toMatchObject({ type: 'close' })
  })

  it('focuses the terminal once the session is running', async () => {
    render(TargetTerminal, {
      props: { target: { kind: 'container', id: 'abc' } },
    })
    await vi.waitFor(() => expect(FakeSocket.instances.length).toBe(1))
    const socket = FakeSocket.instances[0]
    const handle = await vi.mocked(mountTerminal).mock.results[0].value

    // The button that opened the dialog keeps focus until the shell is up —
    // a keystroke before that has nowhere to go.
    socket.onopen?.()
    expect(handle.focus).not.toHaveBeenCalled()

    socket.control({ type: 'ready', session: 'abc.def', since: 0 })
    await vi.waitFor(() => expect(handle.focus).toHaveBeenCalled())
  })
})
