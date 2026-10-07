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

describe('merging windows with panes', () => {
  async function twoWindows() {
    const { readLayout } = await import('../desk/panes')
    off = registerApp({
      id: 'acme_term',
      title: 'Term',
      glyph: 'terminal',
      tone: 'ink',
      instances: 3,
      panes: true,
      load: () => import('./fixtures/AppSettingsPage.svelte'),
    })
    const desk = new Desk({ id: 'local', url: '', token: 't', username: 'admin' })
    const a = desk.open('acme_term', { appState: { n: 1 } })!
    const b = desk.open('acme_term', { appState: { n: 2 } })!
    const layoutOf = (id: string) => readLayout(desk.windows.get(id)!.appState, id)
    return { desk, a, b, layoutOf }
  }

  it('moves a window in as a tab, keeping its pane, without closing it', async () => {
    const { desk, a, b, layoutOf } = await twoWindows()
    desk.mergeWindow(b, { windowId: a, kind: 'tab' })

    expect(desk.windows.get(b)).toBeUndefined()
    // Gone into the other window, not closed: what its pane held lives on.
    expect(desk.windows.wasClosed(b)).toBe(false)
    const layout = layoutOf(a)
    expect(layout.tabs).toHaveLength(2)
    expect(layout.focus).toBe(b)
    expect(layout.tabs[1].root).toEqual({ kind: 'pane', id: b, state: { n: 2 } })
  })

  it('splits a window in beside a pane', async () => {
    const { desk, a, b, layoutOf } = await twoWindows()
    desk.mergeWindow(b, { windowId: a, kind: 'split', paneId: a, side: 'right' })
    const root = layoutOf(a).tabs[0].root
    expect(root).toMatchObject({ kind: 'split', dir: 'row', a: { id: a }, b: { id: b } })
  })

  it('takes a tab out into a window of its own, and not the last one', async () => {
    const { desk, a, b, layoutOf } = await twoWindows()
    desk.mergeWindow(b, { windowId: a, kind: 'tab' })
    const tabId = layoutOf(a).tabs[1].id

    expect(desk.detachTab(a, tabId, { x: 400, y: 300 })).toBe(true)
    expect(layoutOf(a).tabs).toHaveLength(1)
    const opened = desk.windows.of('acme_term').find((w) => w.id !== a)!
    expect(layoutOf(opened.id).tabs[0].root).toEqual({ kind: 'pane', id: b, state: { n: 2 } })

    const onlyTab = layoutOf(a).tabs[0].id
    expect(desk.detachTab(a, onlyTab, { x: 0, y: 0 })).toBe(false)
  })

  it('merges only windows of one app that has panes', async () => {
    const { desk, a } = await twoWindows()
    const other = desk.open('settings')!
    desk.mergeWindow(other, { windowId: a, kind: 'tab' })
    expect(desk.windows.get(other)).toBeDefined()
  })
})

describe('a window with panes', () => {
  it('gives each pane its own handle, and says closed only for what was closed', async () => {
    const { render, screen } = await import('@testing-library/svelte')
    const { tick } = await import('svelte')
    const PaneHostHarness = (await import('./fixtures/PaneHostHarness.svelte')).default
    const { probes } = await import('./fixtures/PaneProbe.svelte')
    probes.length = 0
    off = registerApp({
      id: 'acme_panes',
      title: 'Panes',
      glyph: 'terminal',
      tone: 'ink',
      panes: true,
      load: () => import('./fixtures/PaneProbe.svelte'),
    })
    const desk = new Desk({ id: 'local', url: '', token: 't', username: 'admin' })
    const id = desk.open('acme_panes', { appState: { n: 1 } })!
    render(PaneHostHarness, { desk, id })
    await tick()

    // The first pane is keyed by the window, and has its state.
    expect(probes).toHaveLength(1)
    const first = probes[0].handle
    expect(first.id).toBe(id)
    expect(first.appState).toEqual({ n: 1 })
    expect(first.panes?.count).toBe(1)

    first.panes!.split('right', { n: 2 })
    await tick()
    expect(screen.getAllByTestId('probe')).toHaveLength(2)
    const second = probes[1].handle
    expect(second.appState).toEqual({ n: 2 })
    // The new pane has the focus; the first is still mounted, not remounted.
    expect(second.active).toBe(true)
    expect(first.active).toBe(false)
    expect(probes).toHaveLength(2)

    // A pane saving its state changes only its own.
    second.setAppState({ n: 3 })
    expect(first.appState).toEqual({ n: 1 })
    expect(second.appState).toEqual({ n: 3 })

    second.panes!.close()
    await tick()
    expect(probes[1].closedOnDestroy).toBe(true)
    expect(screen.getAllByTestId('probe')).toHaveLength(1)
    expect(probes[0].closedOnDestroy).toBeUndefined()

    // Closing the last pane closes the window.
    first.panes!.close()
    expect(desk.windows.get(id)).toBeUndefined()
    expect(desk.windows.wasClosed(id)).toBe(true)
  })
})
