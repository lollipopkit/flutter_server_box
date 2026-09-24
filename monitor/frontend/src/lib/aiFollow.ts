/// The follow stream, decoded and folded into the state a page draws.
///
/// Two steps that belong outside a component because both are pure: bytes into
/// frames, and a frame onto the state it changes. A page that did either inline
/// could only be checked by watching it stream.
///
/// The state here is deliberately not the whole conversation. An item is what
/// the agent stored, so a frame is appended and never edited; what is *in
/// progress* — a step's text, and whether a turn is running at all — is the part
/// a stream exists to show, and the part a page cannot re-derive from the items.

import type { AiFollowFrame, AiItemView, AiPhase, AiStopCode } from '../types'

/// What a page holds while it is following one conversation.
export interface AiFollowState {
  items: AiItemView[]
  /// The text of the step being streamed, which is not an item yet.
  live: { step: number; content: string; reasoning: string } | null
  running: boolean
  phase: AiPhase
  error: AiStopCode | null
  /// The calls nobody has answered. Non-empty is what draws Approve/Decline.
  waiting: string[]
}

export function emptyFollowState(): AiFollowState {
  return { items: [], live: null, running: false, phase: 'idle', error: null, waiting: [] }
}

/// The state a fetched detail view starts a page from.
///
/// The stream is followed from `lastOrdinal` of this, so the items already here
/// arrive once: the endpoint answers `?after=` with what was stored since, and
/// a page that appended its own copy of everything it had fetched would draw
/// every message twice.
export function followStateFrom(
  items: AiItemView[],
  live: { step: number | null; content: string; reasoning: string } | null,
  running: boolean,
  phase: AiPhase,
  error: AiStopCode | null,
  waiting: string[],
): AiFollowState {
  return {
    items: [...items],
    // A `step` of null means the step has already been stored as an item, so
    // there is no provisional text left to hold.
    live: live && live.step !== null
      ? { step: live.step, content: live.content, reasoning: live.reasoning }
      : null,
    running,
    phase,
    error,
    waiting: [...waiting],
  }
}

/// The ordinal to ask `?after=` for. Zero when nothing has been stored, which
/// the endpoint reads as "from the beginning".
export function lastOrdinal(state: AiFollowState): number {
  let last = 0
  for (const item of state.items) if (item.ordinal > last) last = item.ordinal
  return last
}

/// Folds one frame onto the state.
///
/// An item that answers an item already held replaces it rather than appending:
/// a reconnect asks from one ordinal behind nothing, but a page may be fed the
/// same ordinal twice across two connections, and an ordinal is the identity
/// here — the stream carries no revision to compare.
export function reduceFollow(state: AiFollowState, frame: AiFollowFrame): AiFollowState {
  switch (frame.type) {
    case 'item': {
      const item = frame.item
      const items = state.items.filter((held) => held.ordinal !== item.ordinal)
      items.push(item)
      items.sort((a, b) => a.ordinal - b.ordinal)
      // The provisional text is dropped exactly when the step it belongs to
      // becomes an item. Dropping it on any item would blank the next step's
      // text as the previous one is stored, which is what the stream sends.
      const live = state.live && state.live.step === item.ordinal ? null : state.live
      const waiting = item.call_id ? state.waiting.filter((id) => id !== item.call_id) : state.waiting
      return { ...state, items, live, waiting }
    }
    case 'delta':
      return {
        ...state,
        live: { step: frame.step, content: frame.content, reasoning: frame.reasoning },
      }
    case 'state':
      return {
        ...state,
        running: frame.running,
        phase: frame.phase,
        error: frame.error,
        waiting: [...frame.waiting],
        // A step that is no longer running leaves no provisional text: the
        // agent stored it, and the item for it either arrived or is coming.
        live: frame.running ? state.live : null,
      }
    case 'ping':
      return state
  }
}

/// Reads an NDJSON body, calling `onFrame` for each frame.
///
/// The remainder of a partly-received line is held until its newline arrives;
/// a line that is not JSON is skipped rather than thrown, because the next
/// frame is still worth drawing and a stream is data, not control. Resolves when
/// the body ends, which for this endpoint means the connection dropped — the
/// caller reconnects. `signal` is the caller's cancel: an abort rejects, as a
/// `fetch` body read does.
export async function readFollow(
  body: ReadableStream<Uint8Array>,
  onFrame: (frame: AiFollowFrame) => void,
  signal?: AbortSignal,
): Promise<void> {
  const reader = body.getReader()
  const decoder = new TextDecoder()
  let pending = ''
  try {
    for (;;) {
      if (signal?.aborted) throw new DOMException('Aborted', 'AbortError')
      const { done, value } = await reader.read()
      if (done) break
      pending += decoder.decode(value, { stream: true })
      let newline = pending.indexOf('\n')
      while (newline >= 0) {
        const line = pending.slice(0, newline).trim()
        pending = pending.slice(newline + 1)
        if (line) {
          const frame = parseFrame(line)
          if (frame) onFrame(frame)
        }
        newline = pending.indexOf('\n')
      }
    }
    const tail = pending.trim()
    if (tail) {
      const frame = parseFrame(tail)
      if (frame) onFrame(frame)
    }
  } finally {
    reader.releaseLock()
  }
}

/// One line as a frame, or null when it is not one this build knows.
///
/// The union is checked by the `type` tag rather than by a schema: an endpoint
/// of a newer agent may send a frame this page has no rendering for, and a
/// frame that would be drawn wrongly is worse than one dropped.
function parseFrame(line: string): AiFollowFrame | null {
  let value: unknown
  try {
    value = JSON.parse(line)
  } catch {
    return null
  }
  if (typeof value !== 'object' || value === null) return null
  const type = (value as { type?: unknown }).type
  if (type === 'item' || type === 'delta' || type === 'state' || type === 'ping') {
    return value as AiFollowFrame
  }
  return null
}
