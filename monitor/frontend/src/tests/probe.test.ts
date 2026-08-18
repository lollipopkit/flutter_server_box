/// The panel assumes, before asking anything, that the origin it was served
/// from is an agent. That holds when an agent serves it and does not when it is
/// hosted statically — where every unknown path answers 200 with index.html,
/// which is exactly what a naive check reads as healthy.

import { describe, it, expect, vi, afterEach } from 'vitest'
import { probe } from '../lib/probe'

function respondWith(body: string, init?: ResponseInit) {
  vi.stubGlobal(
    'fetch',
    vi.fn(async () => new Response(body, { status: 200, ...init })),
  )
}

describe('probe', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('an agent answers with its own json', async () => {
    respondWith(JSON.stringify({ status: 'healthy', version: '1.0' }))

    expect(await probe('')).toBe('healthy')
  })

  it('a static host answers every path with the page itself', async () => {
    // What Cloudflare Pages serves for /api/v1/health: 200, and HTML.
    respondWith('<!doctype html><html><body>ServerBox</body></html>', {
      headers: { 'content-type': 'text/html' },
    })

    expect(await probe('')).toBe('not-an-agent')
  })

  it('json from something that is not an agent is not an agent either', async () => {
    respondWith(JSON.stringify({ error: 'not found' }))

    expect(await probe('')).toBe('not-an-agent')
  })

  it('an agent answering badly is still an agent', async () => {
    // 'unreachable' rather than 'not-an-agent': callers drop an entry on the
    // latter, and a restarting agent must not lose its saved session.
    respondWith('upstream error', { status: 502 })

    expect(await probe('')).toBe('unreachable')
  })

  it('nothing there at all', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new TypeError('failed to fetch')
      }),
    )

    expect(await probe('')).toBe('unreachable')
  })
})
