import { afterEach, describe, expect, it, vi } from 'vitest'
import { Poller } from '../lib/poller.svelte'

describe('Poller', () => {
  afterEach(() => {
    vi.useRealTimers()
  })

  it('waits for one request to finish before scheduling the next', async () => {
    vi.useFakeTimers()
    let finish!: (value: number) => void
    const fetcher = vi.fn(
      () => new Promise<number>((resolve) => {
        finish = resolve
      }),
    )
    const poller = new Poller(fetcher, 1000)

    poller.start()
    expect(fetcher).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(5000)
    expect(fetcher).toHaveBeenCalledTimes(1)

    finish(1)
    await Promise.resolve()
    await vi.advanceTimersByTimeAsync(999)
    expect(fetcher).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(1)
    expect(fetcher).toHaveBeenCalledTimes(2)
    poller.stop()
  })

  it('aborts an in-flight request and ignores its late result', async () => {
    let finish!: (value: number) => void
    let requestSignal!: AbortSignal
    const poller = new Poller<number>(
      (signal) => {
        requestSignal = signal
        return new Promise((resolve) => {
          finish = resolve
        })
      },
      1000,
    )

    poller.start()
    poller.stop()
    expect(requestSignal.aborted).toBe(true)
    finish(42)
    await Promise.resolve()
    expect(poller.data).toBeNull()
  })
})
