import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import StackProgress from '../components/stack/StackProgress.svelte'
import { servers } from '../lib/servers.svelte'
import type { StackJob } from '../types'

beforeEach(() => {
  servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
  servers.currentId = 'local'
})

describe('StackProgress', () => {
  it('reports a job once when it ends, and stops reading it', async () => {
    const running: StackJob = { id: 1, kind: 'storage', state: 'running', error: null, lines: [], next: 0 }
    const read = vi.fn(async (since: number) => ({ ...running, state: 'succeeded' as const, lines: since === 0 ? [{ seq: 0, text: 'done' }] : [], next: 1 }))
    const ondone = vi.fn()
    render(StackProgress, { job: running, title: 'Working', read, stop: null, ondone })
    await new Promise((r) => setTimeout(r, 1500))
    expect(ondone).toHaveBeenCalledTimes(1)
    expect(read).toHaveBeenCalledTimes(1)
  })

  it('reads a job given without its lines from the first line', async () => {
    // A list's summary of a job already 5 lines in.
    const summary: StackJob = { id: 2, kind: 'storage', state: 'running', error: null, lines: [], next: 5 }
    const all = [0, 1, 2, 3, 4].map((seq) => ({ seq, text: `line ${seq}` }))
    const read = vi.fn(async (since: number) => ({ ...summary, state: 'succeeded' as const, lines: all.filter((l) => l.seq >= since), next: 5 }))
    const { getByLabelText } = render(StackProgress, { job: summary, title: 'Working', read, stop: null, ondone: () => {} })
    await new Promise((r) => setTimeout(r, 600))
    expect(read).toHaveBeenCalledWith(0)
    expect(getByLabelText('Log').textContent).toBe(all.map((l) => l.text).join('\n'))
  })
})
