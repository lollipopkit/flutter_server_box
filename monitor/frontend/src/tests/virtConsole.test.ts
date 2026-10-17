import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import { flushSync } from 'svelte'
import VirtConsole from '../components/VirtConsole.svelte'
import { api } from '../lib/api'
import { openConsoleSocket } from '../lib/virtConsole'
import { theme } from '../lib/theme.svelte'
import { screenReader } from '../lib/screenReader.svelte'
import type { VirtConsoleAnswer, VirtGuest } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { virtConsole: vi.fn() },
}))
vi.mock('../lib/virtConsole', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/virtConsole')>()),
  openConsoleSocket: vi.fn(),
}))

const terminals: FakeTerminal[] = []
class FakeTerminal {
  options: Record<string, unknown>
  cols = 80
  rows = 24
  dispose = vi.fn()
  constructor(options: Record<string, unknown>) {
    this.options = { ...options }
    terminals.push(this)
  }
  loadAddon() {}
  open() {}
  onData() {}
  onResize() {}
  write() {}
  focus() {}
}
vi.mock('@xterm/xterm', () => ({ Terminal: FakeTerminal }))
vi.mock('@xterm/addon-fit', () => ({ FitAddon: class { fit() {} } }))
vi.mock('@xterm/xterm/css/xterm.css', () => ({}))

const mockedConsole = vi.mocked(api.virtConsole)
const mockedSocket = vi.mocked(openConsoleSocket)

const answer: VirtConsoleAnswer = { ticket: 't', vnc_password: null, password_known: true, command: null, error: null }
const guest = { id: 'g1' } as VirtGuest

function fakeSocket() {
  return { readyState: 1, send: vi.fn(), close: vi.fn(), onmessage: null, onclose: null } as unknown as WebSocket & {
    close: ReturnType<typeof vi.fn>
  }
}

const observers: { disconnect: ReturnType<typeof vi.fn> }[] = []

beforeEach(() => {
  vi.clearAllMocks()
  terminals.length = 0
  observers.length = 0
  vi.stubGlobal('requestAnimationFrame', (cb: () => void) => setTimeout(cb, 0))
  vi.stubGlobal(
    'ResizeObserver',
    class {
      disconnect = vi.fn()
      constructor() {
        observers.push(this)
      }
      observe() {}
    },
  )
})

afterEach(() => {
  vi.unstubAllGlobals()
  theme.set('system')
})

describe('VirtConsole', () => {
  it('releases the socket, terminal and observer on Close', async () => {
    const socket = fakeSocket()
    mockedConsole.mockResolvedValue(answer)
    mockedSocket.mockResolvedValue(socket)
    render(VirtConsole, { guest, kind: 'text', sudoPassword: null })
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    const close = await screen.findByRole('button', { name: 'Close' })
    await waitFor(() => expect(terminals).toHaveLength(1))

    await fireEvent.click(close)
    expect(socket.close).toHaveBeenCalled()
    expect(terminals[0].dispose).toHaveBeenCalled()
    expect(observers[0].disconnect).toHaveBeenCalled()
  })

  it('installs nothing when destroyed while still opening', async () => {
    let answerNow!: (a: VirtConsoleAnswer) => void
    mockedConsole.mockReturnValue(new Promise((r) => (answerNow = r)))
    const socket = fakeSocket()
    mockedSocket.mockResolvedValue(socket)
    const { unmount } = render(VirtConsole, { guest, kind: 'text', sudoPassword: null })
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    unmount()
    answerNow(answer)
    await new Promise((r) => setTimeout(r, 10))
    expect(mockedSocket).not.toHaveBeenCalled()
    expect(terminals).toHaveLength(0)
  })

  it('closes a socket that arrives after the component is gone', async () => {
    mockedConsole.mockResolvedValue(answer)
    let socketNow!: (s: WebSocket) => void
    mockedSocket.mockReturnValue(new Promise((r) => (socketNow = r)))
    const { unmount } = render(VirtConsole, { guest, kind: 'text', sudoPassword: null })
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    await waitFor(() => expect(mockedSocket).toHaveBeenCalled())
    unmount()
    const socket = fakeSocket()
    socketNow(socket)
    await new Promise((r) => setTimeout(r, 10))
    expect(socket.close).toHaveBeenCalled()
    expect(terminals).toHaveLength(0)
  })

  it('follows a theme change while open', async () => {
    theme.set('light')
    mockedConsole.mockResolvedValue(answer)
    mockedSocket.mockResolvedValue(fakeSocket())
    render(VirtConsole, { guest, kind: 'text', sudoPassword: null })
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    await waitFor(() => expect(terminals).toHaveLength(1))
    expect(terminals[0].options.theme).toMatchObject({ background: '#ffffff' })

    theme.set('dark')
    flushSync()
    expect(terminals[0].options.theme).toMatchObject({ background: '#0b0f14' })
  })

  it('starts without screen reader mode and follows its toggle', async () => {
    mockedConsole.mockResolvedValue(answer)
    mockedSocket.mockResolvedValue(fakeSocket())
    render(VirtConsole, { guest, kind: 'text', sudoPassword: null })
    const toggle = screen.getByRole('button', { name: 'Screen reader mode' })
    expect(toggle).toHaveAttribute('aria-pressed', 'false')
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    await waitFor(() => expect(terminals).toHaveLength(1))
    expect(terminals[0].options.screenReaderMode).toBe(false)

    await fireEvent.click(toggle)
    flushSync()
    expect(toggle).toHaveAttribute('aria-pressed', 'true')
    expect(terminals[0].options.screenReaderMode).toBe(true)
    screenReader.set(false)
  })
})
