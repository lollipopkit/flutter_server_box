import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { Flow, FlowDetail } from '../lib/agentApi'

let emit: (e: Record<string, unknown>) => void = () => {}
const detail: FlowDetail = {
  flow: flow('a', 'running'),
  entries: [],
  pending: null,
  output: null,
}

vi.mock('../lib/agentApi', () => ({
  agentApi: {
    list: vi.fn(async () => ({ flows: [flow('a', 'running'), flow('b', 'running')], configured: true, maxRunning: 3, hostname: 't10' })),
    detail: vi.fn(async () => structuredClone(detail)),
    events: vi.fn((_e: unknown, signal: AbortSignal, onEvent: (e: Record<string, unknown>) => void, onOpen?: () => void) => {
      emit = onEvent
      onOpen?.()
      return new Promise<void>((resolve) => signal.addEventListener('abort', () => resolve()))
    }),
  },
}))

const { AgentStore } = await import('../desk/agent/agentStore.svelte')

function flow(id: string, status: Flow['status']): Flow {
  return {
    id,
    title: id,
    status,
    line: '',
    areas: [], mode: 'manual',
    createdAt: '2026-10-09T00:00:00Z',
    updatedAt: '2026-10-09T00:00:00Z',
    startedAt: null,
    finishedAt: null,
    waiting: null,
  }
}

const entry = { url: 'https://127.0.0.1:3770', token: 't', id: 's', username: 'u' } as never

describe('Agent mode state', () => {
  let store: InstanceType<typeof AgentStore>
  beforeEach(async () => {
    store = new AgentStore(entry)
    store.start()
    await store.refresh()
    await store.open('a')
  })

  it('is live once the stream is open, before anything happens', () => {
    expect(store.live).toBe(true)
  })

  it('follows the open task: its entries, the words being written and the running output', () => {
    emit({ type: 'event', id: 'a', event: { type: 'message_update', event: { type: 'text_delta', delta: 'Look' } } })
    emit({ type: 'event', id: 'a', event: { type: 'message_update', event: { type: 'text_delta', delta: 'ing' } } })
    expect(store.streaming).toBe('Looking')
    emit({ type: 'event', id: 'a', event: { type: 'entry_added', entry: { id: 'x', type: 'message', seq: 2, message: { role: 'assistant', content: [] } } } })
    expect(store.detail?.entries.map((e) => e.id)).toEqual(['x'])
    expect(store.streaming).toBe('')
    // The same entry again changes nothing.
    emit({ type: 'event', id: 'a', event: { type: 'entry_added', entry: { id: 'x', type: 'message', seq: 2 } } })
    expect(store.detail?.entries).toHaveLength(1)

    emit({ type: 'output', id: 'a', toolCallId: 'c1', lines: [[1, 'one'], [2, 'two']] })
    expect(store.detail?.output).toEqual({ toolCallId: 'c1', lines: [[1, 'one'], [2, 'two']], omitted: 0 })
    expect(store.flows.find((f) => f.id === 'a')?.tail).toEqual([[1, 'one'], [2, 'two']])
    // Its result ends the live output.
    emit({ type: 'event', id: 'a', event: { type: 'entry_added', entry: { id: 'y', type: 'message', seq: 3, message: { role: 'toolResult', toolCallId: 'c1', content: [] } } } })
    expect(store.detail?.output).toBeNull()
  })

  it('tells the account about a task elsewhere that needs it, not about the one it is looking at', () => {
    emit({ type: 'flow', flow: { ...flow('b', 'waiting'), waiting: 'confirm' } })
    expect(store.notice).toMatchObject({ id: 'b', status: 'waiting' })
    store.dismissNotice()
    emit({ type: 'flow', flow: flow('a', 'done') })
    expect(store.notice).toBeNull()
    expect(store.detail?.flow.status).toBe('done')
  })

  it('keeps what was typed per task until the task goes', () => {
    const d = store.draft('a')
    d.text = 'half a reply'
    expect(store.draft('a')).toBe(d)
    expect(store.draft('b')).not.toBe(d)
    emit({ type: 'removed', id: 'a' })
    expect(store.draft('a')).not.toBe(d)
    expect(store.draft('a').text).toBe('')
  })

  it('ignores what another task says while one is open, and forgets a removed one', () => {
    emit({ type: 'pending', id: 'b', pending: { id: 'p', kind: 'confirm', toolCallId: 'c', title: 't' } })
    expect(store.detail?.pending).toBeNull()
    emit({ type: 'pending', id: 'a', pending: { id: 'p', kind: 'confirm', toolCallId: 'c', title: 't' } })
    expect(store.detail?.pending?.id).toBe('p')
    emit({ type: 'removed', id: 'a' })
    expect(store.openId).toBeNull()
    expect(store.flows.map((f) => f.id)).toEqual(['b'])
  })
})
