import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { EachServer } from '../lib/eachServer'
import type { ServerEntry } from '../lib/servers.svelte'

const entries = [{ id: 'a' }, { id: 'b' }] as ServerEntry[]

describe('EachServer', () => {
  let visibility: DocumentVisibilityState = 'visible'
  beforeEach(() => {
    vi.useFakeTimers()
    visibility = 'visible'
    vi.spyOn(document, 'visibilityState', 'get').mockImplementation(() => visibility)
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.restoreAllMocks()
  })

  it('asks every server each round, not while the tab is hidden, and at once when shown', async () => {
    const asked: string[] = []
    const after = vi.fn()
    const poll = new EachServer(1000, () => entries, async (s) => void asked.push(s.id), after)
    poll.start()
    await vi.advanceTimersByTimeAsync(0)
    expect(asked).toEqual(['a', 'b'])
    expect(after).toHaveBeenCalledWith(entries)

    await vi.advanceTimersByTimeAsync(1000)
    expect(asked).toHaveLength(4)

    visibility = 'hidden'
    await vi.advanceTimersByTimeAsync(1000)
    expect(asked).toHaveLength(6)
    // Hidden after that round: none scheduled.
    await vi.advanceTimersByTimeAsync(10_000)
    expect(asked).toHaveLength(6)

    visibility = 'visible'
    document.dispatchEvent(new Event('visibilitychange'))
    await vi.advanceTimersByTimeAsync(0)
    expect(asked).toHaveLength(8)

    poll.stop()
    await vi.advanceTimersByTimeAsync(10_000)
    expect(asked).toHaveLength(8)
  })

  it('drops an answer from a round stopped meanwhile', async () => {
    let finish!: () => void
    const stored: string[] = []
    const poll = new EachServer(
      1000,
      () => [entries[0]],
      async (s, _signal, current) => {
        await new Promise<void>((r) => (finish = r))
        if (current()) stored.push(s.id)
      },
    )
    poll.start()
    await vi.advanceTimersByTimeAsync(0)
    poll.stop()
    finish()
    await vi.advanceTimersByTimeAsync(0)
    expect(stored).toEqual([])
  })
})
