import { describe, expect, it, vi } from 'vitest'
import { connect } from '../../../sdk/lkui/src/index'
import { applyTheme } from '../../../sdk/lkui/src/ui'
import { WebAppBridge } from '../desk/webapps/bridge.svelte'
import type { WindowHandle } from '../desk/sys/window.svelte'

/// The SDK in a frame and the desk's bridge, joined by a real port pair,
/// handed over the way the frame window would be.
function joined(permissions: string[], stylesheet: string | null = null) {
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
    theme: () => ({ dark: true, tokens: { '--color-accent': '#6750a4' } }),
    locale: () => 'de',
    stylesheet: () => stylesheet,
    backend: async () => ({ ok: 7 }),
  })
  const channel = { parent, self: { addEventListener: (_: 'message', f: (e: MessageEvent) => void) => listeners.push(f) } }
  const connecting = connect({ channel })
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
    expect(desk.info).toMatchObject({ appId: 'acme_notes', appState: { page: 2 }, theme: { dark: true, tokens: { '--color-accent': '#6750a4' } }, locale: 'de', permissions: ['notifications'] })
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

describe('applyTheme', () => {
  it('draws an app the way the desk is, and lets go of a theme removed', () => {
    const root = document.createElement('div')
    applyTheme({ dark: true, tokens: { '--color-accent': '#6750a4', '--shape-card': '20px', color: 'red' } }, root)
    expect(document.documentElement.dataset.theme).toBe('dark')
    expect(root.classList.contains('lk')).toBe(true)
    expect(root.style.getPropertyValue('--color-accent')).toBe('#6750a4')
    // Only custom properties: a token cannot restyle the element itself.
    expect(root.style.color).toBe('')
    applyTheme({ dark: false, tokens: {} }, root)
    expect(document.documentElement.dataset.theme).toBe('light')
    expect(root.style.getPropertyValue('--color-accent')).toBe('')
    expect(root.style.getPropertyValue('--shape-card')).toBe('')
  })
})

describe('the desk’s design system in a frame', () => {
  it('loads the stylesheet the desk names and follows its theme', async () => {
    const { bridge, connecting } = joined([], '/desk-app/desk.css')
    // The SDK waits for the sheet; jsdom loads none, so it is told.
    let link: HTMLLinkElement | null = null
    await vi.waitFor(() => {
      link = document.head.querySelector('link[href="/desk-app/desk.css"]')
      expect(link).not.toBeNull()
    })
    expect(document.head.firstElementChild).toBe(link)
    link!.dispatchEvent(new Event('load'))
    await connecting
    expect(document.body.classList.contains('lk')).toBe(true)
    expect(document.documentElement.dataset.theme).toBe('dark')
    expect(document.body.style.getPropertyValue('--color-accent')).toBe('#6750a4')
    bridge.send('theme', { dark: false, tokens: {} })
    await vi.waitFor(() => expect(document.documentElement.dataset.theme).toBe('light'))
    expect(document.body.style.getPropertyValue('--color-accent')).toBe('')
    link!.remove()
  })
})
