import { describe, expect, it, vi } from 'vitest'
import { WebAppBridge } from '../desk/webapps/bridge.svelte'
import type { WindowHandle } from '../desk/sys/window.svelte'

function setup(permissions: string[] = []) {
  const frame = { postMessage: vi.fn() } as unknown as Window
  const handle = {
    id: 'w1',
    appId: 'acme_notes',
    appState: null,
    lifecycle: 'active',
    chrome: null,
    setTitle: vi.fn(),
    setAppName: vi.fn(),
    setIcon: vi.fn(),
    setBadge: vi.fn(),
    setAppState: vi.fn(),
    notify: vi.fn(),
    open: vi.fn(() => 'w2'),
    handlers: vi.fn(() => []),
    close: vi.fn(),
    storage: { get: vi.fn(async () => 3), set: vi.fn(async () => {}), remove: vi.fn(async () => {}), keys: vi.fn(async () => []) },
  } as unknown as WindowHandle
  const bridge = new WebAppBridge(
    { handle, allows: (p) => permissions.includes(p), theme: () => ({ dark: false }), locale: () => 'en' },
    () => frame,
  )
  const post = frame.postMessage as ReturnType<typeof vi.fn>
  let id = 0
  const call = async (name: string, args?: unknown, source: unknown = frame) => {
    const n = ++id
    await bridge.receive(new MessageEvent('message', { data: { sbm: 1, id: n, call: name, args }, source: source as Window }))
    return post.mock.calls.map((c) => c[0]).find((m) => m.re === n)
  }
  return { bridge, handle, post, call }
}

describe('the bridge to an installed app', () => {
  it('hears only its own frame', async () => {
    const { call, handle } = setup()
    expect(await call('setTitle', { title: 'x' }, window)).toBeUndefined()
    expect(handle.setTitle).not.toHaveBeenCalled()
  })

  it('says hello with what the app may know, and nothing else', async () => {
    const { call } = setup(['notifications'])
    const r = await call('hello')
    expect(r.ok).toBe(true)
    expect(r.value).toEqual({
      protocol: 1, appId: 'acme_notes', windowId: 'w1', appState: null, lifecycle: 'active',
      theme: { dark: false }, locale: 'en', permissions: ['notifications'],
    })
  })

  it('holds events until the frame says hello', async () => {
    const { bridge, call, post } = setup()
    bridge.send('lifecycle', 'background')
    expect(post).not.toHaveBeenCalled()
    await call('hello')
    await Promise.resolve()
    expect(post.mock.calls.some((c) => c[0].event === 'lifecycle' && c[0].data === 'background')).toBe(true)
  })

  it('refuses what its permissions do not cover', async () => {
    const { call, handle } = setup([])
    expect(await call('notify', { title: 'hi' })).toMatchObject({ ok: false, error: 'notPermitted' })
    expect(await call('keepAlive', { token: 't' })).toMatchObject({ ok: false, error: 'notPermitted' })
    expect(handle.notify).not.toHaveBeenCalled()
  })

  it('hands on only the desk’s own open of a path', async () => {
    const { call, handle } = setup()
    expect(await call('open', { appId: 'terminal', intent: { action: 'terminal.type', data: { name: 'x', steps: [] } } })).toMatchObject({
      ok: false,
      error: 'notPermitted',
    })
    expect(handle.open).not.toHaveBeenCalled()
    expect(await call('open', { appId: 'files', intent: { action: 'open', data: { path: '/etc', kind: 'dir', extra: 1 } } })).toMatchObject({ ok: true })
    expect(handle.open).toHaveBeenCalledWith('files', { newWindow: false, intent: { action: 'open', data: { path: '/etc', kind: 'dir' } } })
  })

  it('keeps the app’s own storage and draws its menus', async () => {
    const { bridge, call, handle } = setup()
    expect(await call('storage.get', { key: 'n' })).toMatchObject({ ok: true, value: 3 })
    await call('menus', { menus: [{ label: 'File', items: [{ id: 'new', label: 'New', icon: 'add', shortcut: '⌘N' }, { id: 1 }, { separator: true }] }] })
    const [menu] = bridge.menuEntries()
    expect(menu.label).toBe('File')
    expect(menu.items).toHaveLength(2)
    expect(handle.storage.get).toHaveBeenCalledWith('n')
  })

  it('drops icon names that are not glyphs and refuses unknown calls', async () => {
    const { bridge, call } = setup()
    await call('toolbar', { actions: [{ id: 'a', label: 'A', icon: '<img src=x>' }] })
    expect(bridge.toolbar.actions?.[0].icon).toBeUndefined()
    expect(await call('eval', {})).toMatchObject({ ok: false, error: 'unknownCall' })
  })
})
