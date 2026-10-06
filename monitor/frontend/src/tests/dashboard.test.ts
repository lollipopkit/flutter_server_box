import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Dashboard from '../desk/apps/status/StatusApp.svelte'
import { api } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import type { Capabilities, CustomCmdOutput, SystemMetrics } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    getMetrics: vi.fn(),
    getHistory: vi.fn(),
    getCardOrder: vi.fn(),
    updateCardOrder: vi.fn(),
  },
}))

/// The iperf dialog mounts the shared terminal component; xterm is stubbed so
/// the page renders without a DOM renderer.
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

const mocked = vi.mocked(api)

const metrics = (custom_cmds?: CustomCmdOutput[]): SystemMetrics =>
  ({
    timestamp: '2026-01-01T00:00:00Z',
    server_name: 'srv',
    cpu_usage: 10,
    memory: { total: 100, used: 50, free: 50, usage_percent: 50 },
    swap: { total: 0, used: 0, usage_percent: 0 },
    disk: { total: 100, used: 50, free: 50, usage_percent: 50 },
    network: { rx_bytes: 0, tx_bytes: 0 },
    custom_cmds,
  }) as unknown as SystemMetrics

const caps = (features: string[]): Capabilities =>
  ({
    features,
    grants: {
      shell: { ok: true },
      ssh_terminal: { ok: false },
      files: { ok: false },
      connect: { ok: false },
      listen: { ok: false },
      virt: { ok: false },
    },
    me: { admin: true },
  }) as unknown as Capabilities

/// The dashboard renders once its first metrics poll has answered.
async function rendered() {
  return screen.findByRole('button', { name: /refresh/i })
}

beforeEach(() => {
  // `bind:clientWidth` in LineChart measures through a ResizeObserver, which
  // jsdom does not have.
  vi.stubGlobal(
    'ResizeObserver',
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  )
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('Dashboard custom commands', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
    servers.currentId = 'local'
    mockMetrics(metrics())
  })

  function mockMetrics(value: SystemMetrics) {
    mocked.getMetrics.mockResolvedValue(value)
    mocked.getHistory.mockResolvedValue([])
    mocked.getCardOrder.mockResolvedValue({ card_order: [] })
  }

  it('draws no card when there are no commands', async () => {
    render(Dashboard)
    await rendered()
    expect(screen.queryByText(/custom commands/i)).toBeNull()
  })

  it('shows a one-line output as a plain row, with the count', async () => {
    mockMetrics(metrics([{ name: 'health', output: 'ok' }]))
    render(Dashboard)
    await rendered()
    expect(await screen.findByText('health')).toBeInTheDocument()
    expect(screen.getByText('ok')).toBeInTheDocument()
    expect(screen.getByText(/1 commands/)).toBeInTheDocument()
    // Nothing to open: the row is not interactive.
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('treats a one-line output that ends in a newline as a plain row', async () => {
    // The agent serves the output as the command printed it, so a single line
    // normally ends in `\n` — that must not read as a second line.
    mockMetrics(metrics([{ name: 'health', output: 'single line\n' }]))
    render(Dashboard)
    await rendered()
    const row = await screen.findByRole('button', { name: /health/ })
    expect(row).toHaveTextContent('single line')
    expect(row).toBeDisabled()
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('still opens a multi-line output that ends in a newline', async () => {
    mockMetrics(metrics([{ name: 'health', output: 'first line\nsecond line\n' }]))
    render(Dashboard)
    await rendered()
    const row = await screen.findByRole('button', { name: /health/ })
    expect(row).toHaveTextContent('first line')
    expect(row).not.toHaveTextContent('second line')
    expect(row).not.toBeDisabled()

    await fireEvent.click(row)
    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('second line')
  })

  it('shows a multi-line output as its first line, opening the rest in a dialog', async () => {
    mockMetrics(metrics([{ name: 'health', output: 'line one\nline two\nline three' }]))
    render(Dashboard)
    await rendered()
    const row = await screen.findByRole('button', { name: /health/ })
    expect(row).toHaveTextContent('line one')
    expect(row).not.toHaveTextContent('line three')

    await fireEvent.click(row)
    expect(await screen.findByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText(/line three/)).toBeInTheDocument()
  })

  it('renders HTML in an output as text', async () => {
    mockMetrics(metrics([{ name: 'health', output: '<b>bold</b>\nsecond' }]))
    render(Dashboard)
    await rendered()
    const row = await screen.findByRole('button', { name: /health/ })
    expect(row).toHaveTextContent('<b>bold</b>')

    await fireEvent.click(row)
    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('<b>bold</b>')
    // Untrusted text, drawn as text: no element was built from it.
    expect(document.querySelector('b')).toBeNull()
  })
})

describe('Dashboard iperf action', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
    servers.currentId = 'local'
    mocked.getMetrics.mockResolvedValue(metrics())
    mocked.getHistory.mockResolvedValue([])
    mocked.getCardOrder.mockResolvedValue({ card_order: [] })
  })

  it('is hidden when the agent does not list iperf', async () => {
    capabilitiesStore.byServer['local'] = caps([])
    render(Dashboard)
    await rendered()
    expect(screen.queryByRole('button', { name: /^iperf$/i })).toBeNull()
  })

  it('is offered when the agent lists iperf and the account holds shell', async () => {
    capabilitiesStore.byServer['local'] = caps(['iperf'])
    render(Dashboard)
    await rendered()
    expect(await screen.findByRole('button', { name: /^iperf$/i })).toBeInTheDocument()
  })
})
