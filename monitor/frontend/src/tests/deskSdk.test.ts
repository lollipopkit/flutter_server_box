import { describe, expect, it, vi } from 'vitest'
import { connect } from '../../../sdk/desk-sys/src/index'
import { WebAppBridge } from '../desk/webapps/bridge.svelte'
import type { WindowHandle } from '../desk/sys/window.svelte'

/// The SDK in a frame and the desk's bridge, joined by two fake windows.
function joined(permissions: string[]) {
  const frameListeners: ((e: MessageEvent) => void)[] = []
  const parentWin = {} as { postMessage(m: unknown): void }
  const frameWin = {} as { postMessage(m: unknown): void }
  frameWin.postMessage = (m) => frameListeners.forEach((f) => f(new MessageEvent('message', { data: m, source: parentWin as unknown as Window })))
  const handle = {
    id: 'w1',
    appId: 'acme_notes',
    appState: { page: 2 },
    lifecycle: 'active',
    setTitle: vi.fn(),
    notify: vi.fn(),
    storage: { get: vi.fn(async () => 'v'), set: vi.fn(), remove: vi.fn(), keys: vi.fn(async () => ['k']) },
  } as unknown as WindowHandle
  const bridge = new WebAppBridge(
    { handle, allows: (p) => permissions.includes(p), theme: () => ({ dark: true }), locale: () => 'de', backend: async () => ({ ok: 7 }) },
    () => frameWin as unknown as Window,
  )
  parentWin.postMessage = (m) => void bridge.receive(new MessageEvent('message', { data: m, source: frameWin as unknown as Window }))
  const channel = { parent: parentWin, self: { addEventListener: (_: 'message', f: (e: MessageEvent) => void) => frameListeners.push(f) } }
  return { bridge, handle, channel }
}

describe('the desk SDK against the bridge', () => {
  it('connects, calls and hears events', async () => {
    const { bridge, handle, channel } = joined(['notifications'])
    const desk = await connect(channel)
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
    expect(actions).toEqual(['refresh'])
  })

  it('throws the desk’s refusal', async () => {
    const { channel } = joined([])
    const desk = await connect(channel)
    await expect(desk.notify({ title: 'x' })).rejects.toThrow('notPermitted')
    await expect(desk.keepAlive('upload')).rejects.toThrow('notPermitted')
  })
})
