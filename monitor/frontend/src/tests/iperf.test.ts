import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import IperfModal from '../desk/apps/status/IperfModal.svelte'
import { servers } from '../lib/servers.svelte'

/// The dialog mounts the shared terminal once Start is pressed; xterm is
/// stubbed so this test is about the frame that terminal sends.
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

/// Fills the form and presses Start, leaving the socket open for the caller.
async function started(): Promise<FakeSocket> {
  render(IperfModal, { onclose: () => {} })
  await fireEvent.input(screen.getByPlaceholderText('example.com'), {
    target: { value: 'example.com' },
  })
  await fireEvent.input(screen.getByPlaceholderText('5201'), {
    target: { value: '5201' },
  })
  await fireEvent.click(screen.getByRole('button', { name: /^start$/i }))
  await vi.waitFor(() => expect(FakeSocket.instances.length).toBe(1))
  const socket = FakeSocket.instances[0]
  socket.onopen?.()
  return socket
}

describe('IperfModal', () => {
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

  it('starts an iperf client for the host and port typed', async () => {
    const socket = await started()
    expect(socket.sent[0]).toMatchObject({
      type: 'open',
      auth: { kind: 'local' },
      target: { kind: 'iperf', host: 'example.com', port: 5201 },
    })
  })

  it('shows an invalid-input refusal translated', async () => {
    const socket = await started()
    socket.control({
      type: 'error',
      code: 'invalid_input',
      message: 'the host is not an IPv4/IPv6 address or a domain name',
      issue: 'invalid_host',
    })
    expect(await screen.findByText(/invalid host format/i)).toBeInTheDocument()
  })

  it('keeps the dialog open and shows the exit status when the session ends', async () => {
    const socket = await started()
    socket.control({ type: 'ready', session: 'abc.def', since: 0 })
    socket.control({ type: 'exit', status: 127 })

    expect(await screen.findByText(/127/)).toBeInTheDocument()
    // The dialog is still there — the output above it is worth reading.
    expect(screen.getByRole('dialog')).toBeInTheDocument()
  })
})
