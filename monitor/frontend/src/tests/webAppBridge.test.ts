import { describe, expect, it, vi } from 'vitest'
import { BridgeError, WebAppBridge, type BackendHost } from '../desk/webapps/bridge.svelte'
import type { WindowHandle } from '../desk/sys/window.svelte'

function setup(permissions: string[] = []) {
  const port = { postMessage: vi.fn(), onmessage: null as ((e: MessageEvent) => void) | null }
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
  const bridge = new WebAppBridge({ handle, allows: (p) => permissions.includes(p), theme: () => ({ dark: false }), locale: () => 'en' })
  bridge.attach(port)
  const post = port.postMessage
  let id = 0
  const call = async (name: string, args?: unknown) => {
    const n = ++id
    await bridge.receive({ sbm: 1, id: n, call: name, args })
    return post.mock.calls.map((c) => c[0]).find((m) => m.re === n)
  }
  return { bridge, handle, post, call, port }
}

describe('the bridge to an installed app', () => {
  it('hears its port, and nothing once closed (the frame left its page)', async () => {
    const { bridge, call, handle, port } = setup()
    port.onmessage?.(new MessageEvent('message', { data: { sbm: 1, id: 99, call: 'setTitle', args: { title: 'a' } } }))
    await Promise.resolve()
    expect(handle.setTitle).toHaveBeenCalledWith('a')
    bridge.close()
    expect(port.onmessage).toBeNull()
    expect(await call('setTitle', { title: 'b' })).toBeUndefined()
    expect(handle.setTitle).toHaveBeenCalledTimes(1)
  })

  it('refuses app state the agent would not keep, and opening apps in a loop', async () => {
    const { call } = setup()
    expect(await call('setAppState', { state: 'x'.repeat(17 * 1024) })).toMatchObject({ ok: false, error: 'tooLarge' })
    for (let i = 0; i < 3; i++) expect(await call('open', { appId: 'serverbox.files' })).toMatchObject({ ok: true })
    expect(await call('open', { appId: 'serverbox.terminal' })).toMatchObject({ ok: false, error: 'busy' })
  })

  it('says hello with what the app may know, and nothing else', async () => {
    const { call } = setup(['notifications'])
    const r = await call('hello')
    expect(r.ok).toBe(true)
    expect(r.value).toEqual({
      protocol: 1, appId: 'acme_notes', windowId: 'w1', appState: null, lifecycle: 'active',
      theme: { dark: false }, locale: 'en', ui: null, permissions: ['notifications'],
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
    expect(await call('open', { appId: 'serverbox.terminal', intent: { action: 'terminal.type', data: { name: 'x', steps: [] } } })).toMatchObject({
      ok: false,
      error: 'notPermitted',
    })
    expect(handle.open).not.toHaveBeenCalled()
    expect(await call('open', { appId: 'serverbox.files', intent: { action: 'open', data: { path: '/etc', kind: 'dir', extra: 1 } } })).toMatchObject({ ok: true })
    expect(handle.open).toHaveBeenCalledWith('serverbox.files', { newWindow: false, intent: { action: 'open', data: { path: '/etc', kind: 'dir' } } })
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

describe('the bridge to an app backend', () => {
  function backendSetup() {
    const port = { postMessage: vi.fn(), onmessage: null }
    const asked: unknown[] = []
    const backend: BackendHost = {
      call: vi.fn(async (fn: string, _args: unknown, sudo?: unknown) => {
        if (fn === 'bad') throw new BridgeError('failedPrecondition', 'notScanned')
        return { fn, sudo: sudo ?? null }
      }),
      job: vi.fn(async (fn: string) => ({ id: 1, function: fn, state: 'running' as const, lines: [], next: 0 })),
      view: vi.fn(async () => null),
      cancel: vi.fn(async () => {}),
      sudo: vi.fn((ask, run) => {
        asked.push(ask)
        return run({ password: 'pw', remember: true })
      }),
    }
    const bridge = new WebAppBridge({ handle: { id: 'w', appId: 'a' } as unknown as WindowHandle, allows: () => false, theme: () => ({ dark: false }), locale: () => 'en', backend })
    bridge.attach(port)
    return { bridge, backend, asked, post: port.postMessage }
  }

  it('answers what the backend said, or its code and words', async () => {
    const { bridge, backend, post } = backendSetup()
    await bridge.receive({ sbm: 1, id: 1, call: 'backend.call', args: { function: 'ok', args: { x: 1 } } })
    await bridge.receive({ sbm: 1, id: 2, call: 'backend.call', args: { function: 'bad' } })
    expect(backend.call).toHaveBeenCalledWith('ok', { x: 1 }, undefined)
    expect(post.mock.calls[0][0]).toMatchObject({ re: 1, ok: true, value: { fn: 'ok', sudo: null } })
    expect(post.mock.calls[1][0]).toMatchObject({ re: 2, ok: false, error: 'failedPrecondition', message: 'notScanned' })
  })

  it('runs as root only through the desk’s own dialog', async () => {
    const { bridge, backend, asked, post } = backendSetup()
    const sudo = { title: 'Clean', body: 'Removes caches', confirmWord: 'clean' }
    await bridge.receive({ sbm: 1, id: 1, call: 'backend.job', args: { function: 'clean', args: {}, sudo } })
    expect(asked).toEqual([sudo])
    expect(backend.job).toHaveBeenCalledWith('clean', {}, { password: 'pw', remember: true })
    expect(post.mock.calls[0][0]).toMatchObject({ re: 1, ok: true, value: { function: 'clean', state: 'running' } })
    // What the dialog may be made to say is checked.
    await bridge.receive({ sbm: 1, id: 2, call: 'backend.call', args: { function: 'x', sudo: { title: 'T', body: 'B', confirmWord: '<b>' } } })
    expect(post.mock.calls[1][0]).toMatchObject({ re: 2, ok: false, error: 'invalidArgs' })
    expect(backend.call).not.toHaveBeenCalled()
  })

  it('opens a model server stack in the desk’s sheet for an app that runs programs, one at a time', async () => {
    let close = () => {}
    const openStack = vi.fn(() => new Promise<void>((done) => (close = done)))
    const port = { postMessage: vi.fn(), onmessage: null as ((e: MessageEvent) => void) | null }
    const make = (permissions: string[]) => {
      const b = new WebAppBridge({ handle: { id: 'w', appId: 'a' } as unknown as WindowHandle, allows: (p) => permissions.includes(p), theme: () => ({ dark: false }), locale: () => 'en', openStack })
      b.attach(port)
      return b
    }
    await make([]).receive({ sbm: 1, id: 1, call: 'openStack', args: { id: 'vllm.vllm' } })
    expect(port.postMessage.mock.calls[0][0]).toMatchObject({ re: 1, ok: false, error: 'notPermitted' })
    const bridge = make(['process'])
    // Only the engines' stacks.
    await bridge.receive({ sbm: 1, id: 2, call: 'openStack', args: { id: 'futo.immich' } })
    expect(port.postMessage.mock.calls[1][0]).toMatchObject({ re: 2, ok: false, error: 'invalidArgs' })
    const first = bridge.receive({ sbm: 1, id: 3, call: 'openStack', args: { id: 'ggml.llama_cpp', model: 'a/b-GGUF:Q4_K_M', backend: 'cuda' } })
    await bridge.receive({ sbm: 1, id: 4, call: 'openStack', args: { id: 'vllm.vllm' } })
    expect(port.postMessage.mock.calls[2][0]).toMatchObject({ re: 4, ok: false, error: 'busy' })
    expect(openStack).toHaveBeenCalledWith('ggml.llama_cpp', 'a/b-GGUF:Q4_K_M', 'cuda')
    close()
    await first
    expect(port.postMessage.mock.calls[3][0]).toMatchObject({ re: 3, ok: true })
  })
})
