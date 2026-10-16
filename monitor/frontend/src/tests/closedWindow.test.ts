/// A window closed while its app waits on the agent leaves nothing running:
/// no poll started by the late answer, no console socket kept open.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Bmc from '../desk/apps/bmc/BmcApp.svelte'
import Benchmark from '../desk/apps/benchmark/BenchmarkApp.svelte'
import VirtConsole from '../desk/apps/virt/VirtConsole.svelte'
import { api } from '../lib/api'
import { openConsoleSocket } from '../lib/virtConsole'
import type { BenchView, BmcList, VirtConsoleAnswer, VirtGuest } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    getBmc: vi.fn(),
    bmcStatus: vi.fn(),
    getBenchmark: vi.fn(),
    estimateBenchmark: vi.fn(),
    virtConsole: vi.fn(),
  },
}))
vi.mock('../lib/virtConsole', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/virtConsole')>()),
  openConsoleSocket: vi.fn(),
}))
const mocked = vi.mocked(api)

/// A promise the test settles.
function later<T>() {
  let settle!: (value: T) => void
  const promise = new Promise<T>((resolve) => (settle = resolve))
  return { promise, settle }
}

describe('a window closed mid-request', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.useFakeTimers({ shouldAdvanceTime: true })
    mocked.estimateBenchmark.mockResolvedValue({
      minutes: 1,
      traffic_bytes: 0,
      required_free_bytes: null,
      system_info_only: false,
    })
  })
  afterEach(() => vi.useRealTimers())

  it('BMC: the late list starts no status poll', async () => {
    const list = later<BmcList>()
    mocked.getBmc.mockReturnValue(list.promise)
    const { unmount } = render(Bmc)
    unmount()
    list.settle({ targets: [{ id: 't1', name: 'r', url: 'https://x', username: 'a', has_password: true, cert_sha256: null }], editable: true } as BmcList)
    await vi.advanceTimersByTimeAsync(120_000)
    expect(mocked.bmcStatus).not.toHaveBeenCalled()
  })

  it('Benchmark: a late answer with a live run schedules nothing', async () => {
    const first = later<BenchView>()
    mocked.getBenchmark.mockReturnValueOnce(first.promise)
    const { unmount } = render(Benchmark)
    unmount()
    first.settle({ runs: [], supported: true, live: { answered: false, exit_code: null } } as unknown as BenchView)
    await vi.advanceTimersByTimeAsync(60_000)
    expect(mocked.getBenchmark).toHaveBeenCalledTimes(1)
  })

  it('Console: a socket that opens after the view closed is closed', async () => {
    const answer = later<VirtConsoleAnswer>()
    mocked.virtConsole.mockReturnValue(answer.promise)
    const socket = { close: vi.fn(), readyState: 1 } as unknown as WebSocket
    vi.mocked(openConsoleSocket).mockResolvedValue(socket)
    const guest = { id: 'g1', name: 'vm' } as VirtGuest
    const { unmount } = render(VirtConsole, { guest, kind: 'text', sudoPassword: null })
    await fireEvent.click(screen.getByRole('button', { name: /open/i }))
    unmount()
    answer.settle({ ticket: 't', password_known: true } as VirtConsoleAnswer)
    await vi.advanceTimersByTimeAsync(1_000)
    // Either never opened, or closed at once.
    const opened = vi.mocked(openConsoleSocket).mock.calls.length
    if (opened) expect(socket.close).toHaveBeenCalled()
  })
})
