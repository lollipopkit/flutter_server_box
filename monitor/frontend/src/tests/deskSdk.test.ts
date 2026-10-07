import { describe, expect, it, vi } from 'vitest'
import { connect } from '../../../sdk/desk-sys/src/index'
import { WebAppBridge } from '../desk/webapps/bridge.svelte'
import type { WindowHandle } from '../desk/sys/window.svelte'

/// The SDK in a frame and the desk's bridge, joined by a real port pair,
/// handed over the way the frame window would be.
function joined(permissions: string[]) {
  const listeners: ((e: MessageEvent) => void)[] = []
  const parent = {}
  const handle = {
    id: 'w1',
    appId: 'acme_notes',
    appState: { page: 2 },
    lifecycle: 'active',
    setTitle: vi.fn(),
    notify: vi.fn(),
    open: vi.fn(() => 'w2'),
    storage: { get: vi.fn(async () => 'v'), set: vi.fn(), remove: vi.fn(), keys: vi.fn(async () => ['k']) },
  } as unknown as WindowHandle
  const bridge = new WebAppBridge({
    handle,
    allows: (p) => permissions.includes(p),
    theme: () => ({ dark: true }),
    locale: () => 'de',
    backend: async () => ({ ok: 7 }),
  })
  const channel = { parent, self: { addEventListener: (_: 'message', f: (e: MessageEvent) => void) => listeners.push(f) } }
  const connecting = connect(channel)
  const pair = new MessageChannel()
  bridge.attach(pair.port1)
  // From another window first: ignored.
  listeners.forEach((f) => f(new MessageEvent('message', { data: { sbm: 1, event: 'connect' }, source: null, ports: [new MessageChannel().port2] })))
  listeners.forEach((f) => f(new MessageEvent('message', { data: { sbm: 1, event: 'connect' }, source: parent as Window, ports: [pair.port2] })))
  return { bridge, handle, connecting }
}

describe('the desk SDK against the bridge', () => {
  it('connects, calls and hears events', async () => {
    const { bridge, handle, connecting } = joined(['notifications'])
    const desk = await connecting
    expect(desk.info).toMatchObject({ appId: 'acme_notes', appState: { page: 2 }, theme: { dark: true }, locale: 'de', permissions: ['notifications'] })
    await desk.setTitle('Draft')
    expect(handle.setTitle).toHaveBeenCalledWith('Draft')
    expect(await desk.storage.get('k')).toBe('v')
    expect(await desk.backend('sum', [3, 4])).toBe(7)
    await desk.notify({ title: 'Saved' })
    expect(handle.notify).toHaveBeenCalled()

    const actions: string[] = []
    desk.on('action', ({ id }) => actions.push(id))
    bridge.action('refresh')
    await vi.waitFor(() => expect(actions).toEqual(['refresh']))
  })

  it('throws the desk’s refusal', async () => {
    const { connecting } = joined([])
    const desk = await connecting
    await expect(desk.notify({ title: 'x' })).rejects.toThrow('notPermitted')
    await expect(desk.keepAlive('upload')).rejects.toThrow('notPermitted')
  })
})
