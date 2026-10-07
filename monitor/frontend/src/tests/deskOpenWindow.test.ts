/// `useWindow().openWindow`: another window of the same app, up to its limit.

import { describe, it, expect, afterEach } from 'vitest'
import { render } from '@testing-library/svelte'
import WindowHandleHarness from './fixtures/WindowHandleHarness.svelte'
import { Desk } from '../desk/deskState.svelte'
import { registerApp } from '../desk/sys'
import type { WindowHandle } from '../desk/sys/window.svelte'

let off: (() => void) | null = null
afterEach(() => {
  off?.()
  off = null
})

function handleOf(desk: Desk, id: string): WindowHandle {
  let handle: WindowHandle | null = null
  render(WindowHandleHarness, { desk, id, onhandle: (h: WindowHandle) => (handle = h) })
  if (!handle) throw new Error('no handle')
  return handle
}

describe('openWindow', () => {
  it('opens another window of the app with the state given, up to its limit', () => {
    off = registerApp({
      id: 'acme_twin',
      title: 'Twin',
      glyph: 'folder',
      tone: 'soft',
      instances: 2,
      load: () => import('./fixtures/AppSettingsPage.svelte'),
    })
    const desk = new Desk({ id: 'local', url: '', token: 't', username: 'admin' })
    const first = desk.open('acme_twin')!
    const win = handleOf(desk, first)

    expect(win.canOpenWindow).toBe(true)
    const second = win.openWindow({ path: '/srv' })
    expect(second).not.toBeNull()
    expect(second).not.toBe(first)
    expect(desk.windows.get(second!)).toMatchObject({ appId: 'acme_twin', appState: { path: '/srv' } })

    // At the limit: no third window, and the item says so.
    expect(win.canOpenWindow).toBe(false)
    expect(win.openWindow()).toBeNull()
    expect(desk.windows.of('acme_twin')).toHaveLength(2)

    // `closed` tells an unmounting app its window is gone for good.
    expect(win.closed).toBe(false)
    desk.windows.close(first)
    expect(win.closed).toBe(true)
  })

  it('is closed to an app of one window', () => {
    off = registerApp({
      id: 'acme_single',
      title: 'Single',
      glyph: 'folder',
      tone: 'soft',
      load: () => import('./fixtures/AppSettingsPage.svelte'),
    })
    const desk = new Desk({ id: 'local', url: '', token: 't', username: 'admin' })
    const id = desk.open('acme_single')!
    const win = handleOf(desk, id)

    expect(win.canOpenWindow).toBe(false)
    expect(win.openWindow()).toBe(id)
    expect(desk.windows.of('acme_single')).toHaveLength(1)
  })
})
