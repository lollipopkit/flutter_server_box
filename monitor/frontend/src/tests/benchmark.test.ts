import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Benchmark from '../desk/apps/benchmark/BenchmarkApp.svelte'
import { api, ApiError } from '../lib/api'
import type { BenchRun, BenchView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    getBenchmark: vi.fn(),
    getBenchmarkRun: vi.fn(),
    estimateBenchmark: vi.fn(),
    startBenchmark: vi.fn(),
    cancelBenchmark: vi.fn(),
    removeBenchmark: vi.fn(),
  },
}))
const mocked = vi.mocked(api)

const view = (): BenchView => ({ runs: [], supported: true }) as unknown as BenchView

describe('Benchmark page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mocked.getBenchmark.mockResolvedValue(view())
    mocked.estimateBenchmark.mockResolvedValue({
      minutes: 10,
      traffic_bytes: 0,
      required_free_bytes: null,
      system_info_only: false,
    })
  })

  it('starts a run with the form options and says so', async () => {
    mocked.startBenchmark.mockResolvedValue({ run: { id: 'bench_1' } as BenchRun })
    render(Benchmark)
    await fireEvent.click(await screen.findByRole('button', { name: /^run$/i }))
    await waitFor(() => expect(mocked.startBenchmark).toHaveBeenCalledTimes(1))
    expect(mocked.startBenchmark.mock.calls[0][0]).toBeTypeOf('object')
    expect(await screen.findByText(/bench_1/)).toBeInTheDocument()
  })

  it('names a refusal in its own words', async () => {
    mocked.startBenchmark.mockRejectedValue(new ApiError('already_running', 409))
    render(Benchmark)
    await fireEvent.click(await screen.findByRole('button', { name: /^run$/i }))
    expect(await screen.findByText(/already running/i)).toBeInTheDocument()
  })
})
