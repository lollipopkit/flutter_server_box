import { describe, it, expect, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import AppsPanelHarness from './fixtures/AppsPanelHarness.svelte'
import { Desk } from '../desk/deskState.svelte'
import { servers } from '../lib/servers.svelte'

// jsdom has no Web Animations API, which the outro reaches for.
Element.prototype.animate ??= function (this: Element) {
  return { cancel() {}, finished: Promise.resolve(), onfinish: null, playState: 'idle' } as unknown as Animation
}

beforeEach(() => {
  servers.list = [{ id: 'local', url: '', token: 't' }]
  servers.currentId = 'local'
})

describe('All Apps', () => {
  it('closes a context menu first, and itself only on the next click beside the icons', async () => {
    const desk = new Desk({ id: 'local', url: '', token: 't' })
    desk.panel = 'apps'
    const { container } = render(AppsPanelHarness, { desk })
    const panel = container.querySelector('.apps-panel') as HTMLElement
    desk.menu = { x: 10, y: 10, items: [] } as unknown as typeof desk.menu

    await fireEvent.pointerDown(panel)
    await fireEvent.click(panel)
    expect(desk.menu).toBeNull()
    expect(desk.panel).toBe('apps')

    await fireEvent.pointerDown(panel)
    await fireEvent.click(panel)
    expect(desk.panel).toBeNull()
  })
})

describe('CSS times', () => {
  it('reads both units, as the built CSS writes them', async () => {
    const { cssMs } = await import('../desk/lk/motion')
    expect(cssMs('677ms')).toBe(677)
    expect(cssMs('.677s')).toBe(677)
    expect(cssMs(' 0.3s ')).toBe(300)
    expect(cssMs('', 5)).toBe(5)
  })
})
