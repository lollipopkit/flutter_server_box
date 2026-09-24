import { describe, expect, it } from 'vitest'
import {
  emptyFollowState,
  followStateFrom,
  lastOrdinal,
  readFollow,
  reduceFollow,
  type AiFollowState,
} from '../lib/aiFollow'
import type { AiFollowFrame, AiItemView } from '../types'

function item(ordinal: number, content: string, callId: string | null = null): AiItemView {
  return {
    ordinal,
    created_at: '2026-09-24T00:00:00Z',
    kind: 'message',
    role: 'assistant',
    content,
    reasoning: '',
    call_id: callId,
    tool: null,
    arguments: null,
    risk: null,
  }
}

/// A body of chunks as a `ReadableStream`, which is what a fetch body is: the
/// split points are the ones a network chooses, not the ones a frame has.
function stream(...chunks: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder()
  return new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(encoder.encode(chunk))
      controller.close()
    },
  })
}

async function collect(...chunks: string[]): Promise<AiFollowFrame[]> {
  const frames: AiFollowFrame[] = []
  await readFollow(stream(...chunks), (frame) => frames.push(frame))
  return frames
}

describe('readFollow', () => {
  it('reads one frame per line', async () => {
    const frames = await collect(
      '{"type":"ping"}\n{"type":"state","running":true,"phase":"streaming","error":null,"waiting":[]}\n',
    )
    expect(frames.map((f) => f.type)).toEqual(['ping', 'state'])
  })

  it('holds a line split across two reads', async () => {
    // The case a per-chunk decoder gets wrong: the tag of the second frame is in
    // the first chunk and its body in the second.
    const frames = await collect('{"type":"pi', 'ng"}\n{"type":"delta","step":3,', '"content":"hi","reasoning":""}\n')
    expect(frames).toEqual([{ type: 'ping' }, { type: 'delta', step: 3, content: 'hi', reasoning: '' }])
  })

  it('takes a last line with no trailing newline', async () => {
    const frames = await collect('{"type":"ping"}\n{"type":"ping"}')
    expect(frames).toHaveLength(2)
  })

  it('splits a multi-byte character across two reads', async () => {
    // `TextDecoder` with `stream: true` is the reason this works; a per-chunk
    // `decode` would produce two replacement characters.
    const encoder = new TextEncoder()
    const bytes = encoder.encode('{"type":"delta","step":1,"content":"服务","reasoning":""}\n')
    const cut = bytes.indexOf(0xe5) + 1
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(bytes.slice(0, cut))
        controller.enqueue(bytes.slice(cut))
        controller.close()
      },
    })
    const frames: AiFollowFrame[] = []
    await readFollow(body, (frame) => frames.push(frame))
    expect(frames).toEqual([{ type: 'delta', step: 1, content: '服务', reasoning: '' }])
  })

  it('skips a line that is not a frame and keeps reading', async () => {
    const frames = await collect('not json\n{"type":"ping"}\n[1,2]\n{"type":"nope"}\n{"type":"ping"}\n')
    expect(frames).toHaveLength(2)
  })

  it('rejects when the caller cancels', async () => {
    const controller = new AbortController()
    controller.abort()
    await expect(readFollow(stream('{"type":"ping"}\n'), () => {}, controller.signal)).rejects.toThrow()
  })
})

describe('reduceFollow', () => {
  it('appends an item and keeps the order by ordinal', () => {
    let state = emptyFollowState()
    state = reduceFollow(state, { type: 'item', item: item(2, 'b') })
    state = reduceFollow(state, { type: 'item', item: item(1, 'a') })
    expect(state.items.map((i) => i.content)).toEqual(['a', 'b'])
  })

  it('replaces an item it already holds rather than drawing it twice', () => {
    let state = reduceFollow(emptyFollowState(), { type: 'item', item: item(1, 'a') })
    state = reduceFollow(state, { type: 'item', item: { ...item(1, 'a'), content: 'a2' } })
    expect(state.items).toHaveLength(1)
    expect(state.items[0].content).toBe('a2')
  })

  it('drops the provisional text of the step that item supersedes', () => {
    let state = reduceFollow(emptyFollowState(), { type: 'delta', step: 4, content: 'half', reasoning: 'r' })
    expect(state.live).not.toBeNull()
    state = reduceFollow(state, { type: 'item', item: item(4, 'half') })
    expect(state.live).toBeNull()
  })

  it('keeps the provisional text of the next step', () => {
    // The agent stores step N and starts streaming N+1; blanking the text on any
    // item would make the answer flicker away as it is stored.
    let state = reduceFollow(emptyFollowState(), { type: 'item', item: item(4, 'first') })
    state = reduceFollow(state, { type: 'delta', step: 5, content: 'second', reasoning: '' })
    expect(state.live).toEqual({ step: 5, content: 'second', reasoning: '' })
  })

  it('takes waiting from the state frame, and drops an answered call', () => {
    let state = reduceFollow(emptyFollowState(), {
      type: 'state',
      running: true,
      phase: 'idle',
      error: null,
      waiting: ['call_1', 'call_2'],
    })
    expect(state.waiting).toEqual(['call_1', 'call_2'])
    state = reduceFollow(state, { type: 'item', item: item(6, 'declined', 'call_1') })
    expect(state.waiting).toEqual(['call_2'])
  })

  it('clears the provisional text when the turn stops running', () => {
    let state = reduceFollow(emptyFollowState(), { type: 'delta', step: 2, content: 'x', reasoning: '' })
    state = reduceFollow(state, { type: 'state', running: false, phase: 'idle', error: 'unreachable', waiting: [] })
    expect(state.live).toBeNull()
    expect(state.error).toBe('unreachable')
  })

  it('leaves the state alone for a ping', () => {
    const state = reduceFollow(emptyFollowState(), { type: 'ping' })
    expect(state).toEqual(emptyFollowState())
  })
})

describe('followStateFrom', () => {
  it('drops a live view whose step is already an item', () => {
    const state = followStateFrom([], { step: null, content: 'stored', reasoning: '' }, false, 'idle', null, [])
    expect(state.live).toBeNull()
  })

  it('copies the lists it is given', () => {
    // The page holds these as reactive state and the fetched view is about to be
    // dropped; a shared array would be mutated through the view.
    const items = [item(1, 'a')]
    const waiting = ['call_1']
    const state: AiFollowState = followStateFrom(items, null, true, 'streaming', null, waiting)
    items.push(item(2, 'b'))
    waiting.push('call_2')
    expect(state.items).toHaveLength(1)
    expect(state.waiting).toEqual(['call_1'])
  })
})

describe('lastOrdinal', () => {
  it('is zero for a conversation with nothing stored', () => {
    expect(lastOrdinal(emptyFollowState())).toBe(0)
  })

  it('is the highest ordinal, wherever it sits', () => {
    let state = reduceFollow(emptyFollowState(), { type: 'item', item: item(7, 'b') })
    state = reduceFollow(state, { type: 'item', item: item(3, 'a') })
    expect(lastOrdinal(state)).toBe(7)
  })
})
