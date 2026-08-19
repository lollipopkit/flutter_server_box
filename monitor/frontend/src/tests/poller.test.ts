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

  it('clears a successful server result before polling a new identity', async () => {
    let resolveSecond!: (value: string) => void
    const fetcher = vi
      .fn<(signal: AbortSignal) => Promise<string>>()
      .mockResolvedValueOnce('server-a')
      .mockImplementationOnce(
        () => new Promise((resolve) => (resolveSecond = resolve)),
      )
    const poller = new Poller(fetcher)

    poller.start()
    await vi.waitFor(() => expect(poller.data).toBe('server-a'))
    poller.reset()
    poller.start()

    expect(poller.data).toBeNull()
    expect(poller.error).toBeNull()
    resolveSecond('server-b')
    await vi.waitFor(() => expect(poller.data).toBe('server-b'))
    poller.stop()
  })

  it('clears successful history before polling a different range', async () => {
    let resolveSecond!: (value: number[]) => void
    const fetcher = vi
      .fn<(signal: AbortSignal) => Promise<number[]>>()
      .mockResolvedValueOnce([60])
      .mockImplementationOnce(
        () => new Promise((resolve) => (resolveSecond = resolve)),
      )
    const poller = new Poller(fetcher)

    poller.start()
    await vi.waitFor(() => expect(poller.data).toEqual([60]))
    poller.reset()
    poller.start()

    expect(poller.data).toBeNull()
    resolveSecond([1440])
    await vi.waitFor(() => expect(poller.data).toEqual([1440]))
    poller.stop()
  })
})
