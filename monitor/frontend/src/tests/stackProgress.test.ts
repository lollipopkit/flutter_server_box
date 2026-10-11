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
})
