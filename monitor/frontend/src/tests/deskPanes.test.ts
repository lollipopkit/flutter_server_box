/// Tabs and split panes as data (`desk/panes.ts`).

import { describe, it, expect } from 'vitest'
import {
  addTab,
  allPanes,
  dividers,
  focusedPane,
  merge,
  pane,
  paneRects,
  readLayout,
  removePane,
  removeTab,
  setPaneState,
  setRatio,
  showTab,
  sideAt,
  split,
  writeLayout,
  type Layout,
} from '../desk/panes'

const ids = (layout: Layout) => allPanes(layout).map((p) => p.id)

describe('panes', () => {
  it('reads a plain state as one pane keyed by the window', () => {
    const layout = readLayout({ path: '/srv' }, 'w1')
    expect(layout.tabs).toHaveLength(1)
    expect(focusedPane(layout)).toEqual({ kind: 'pane', id: 'w1', state: { path: '/srv' } })
    // And a written layout reads back as itself.
    expect(readLayout(writeLayout(layout), 'other')).toEqual(layout)
    expect(readLayout(null, 'w2').focus).toBe('w2')
  })

  it('splits a pane, focusing the new one, and closes back to one', () => {
    const one = readLayout(null, 'w')
    const two = split(one, 'w', 'right', pane('b', 'p2'))
    expect(ids(two)).toEqual(['w', 'p2'])
    expect(two.focus).toBe('p2')
    const rects = paneRects(two.tabs[0].root)
    expect(rects.get('w')).toEqual({ x: 0, y: 0, w: 0.5, h: 1 })
    expect(rects.get('p2')).toEqual({ x: 0.5, y: 0, w: 0.5, h: 1 })

    // On the left it goes first.
    const left = split(one, 'w', 'top', pane(null, 'p3'))
    expect(ids(left)).toEqual(['p3', 'w'])
    expect(paneRects(left.tabs[0].root).get('p3')).toEqual({ x: 0, y: 0, w: 1, h: 0.5 })

    const back = removePane(two, 'p2')!
    expect(back.tabs[0].root).toEqual(one.tabs[0].root)
    expect(back.focus).toBe('w')
    expect(removePane(one, 'w')).toBeNull()
  })

  it('keeps every untouched node when a pane changes state', () => {
    const two = split(readLayout(null, 'w'), 'w', 'right', pane('b', 'p2'))
    const next = setPaneState(two, 'p2', 'c')
    const root = two.tabs[0].root
    const nextRoot = next.tabs[0].root
    if (root.kind !== 'split' || nextRoot.kind !== 'split') throw new Error('not a split')
    expect(nextRoot.a).toBe(root.a)
    expect(nextRoot.b).toEqual({ kind: 'pane', id: 'p2', state: 'c' })
  })

  it('opens tabs after the one on show and settles the focus when one goes', () => {
    let layout = readLayout(null, 'w')
    layout = addTab(layout, pane(null, 'p2'), 't2')
    layout = showTab(layout, `tw`)
    layout = addTab(layout, pane(null, 'p3'), 't3')
    expect(layout.tabs.map((t) => t.id)).toEqual(['tw', 't3', 't2'])
    expect(layout.focus).toBe('p3')

    const fewer = removeTab(layout, 't3')!
    // The tab left of what went is shown.
    expect(fewer.tab).toBe('tw')
    expect(fewer.focus).toBe('w')
    // The first gone, the next is.
    expect(removeTab(showTab(layout, 'tw'), 'tw')!.tab).toBe('t3')
    expect(removeTab(readLayout(null, 'w'), 'tw')).toBeNull()
  })

  it('clamps a divider and finds it by path', () => {
    const two = split(readLayout(null, 'w'), 'w', 'right', pane(null, 'p2'))
    const three = split(two, 'p2', 'bottom', pane(null, 'p3'))
    const lines = dividers(three.tabs[0].root)
    expect(lines.map((d) => [d.path, d.dir, d.at])).toEqual([
      ['', 'row', 0.5],
      ['b', 'column', 0.5],
    ])
    const moved = setRatio(three, 'tw', 'b', 0.99)
    const root = moved.tabs[0].root
    if (root.kind !== 'split' || root.b.kind !== 'split') throw new Error('not a split')
    expect(root.b.ratio).toBe(0.9)
  })

  it('merges a window as a tab or beside a pane, keeping its pane ids', () => {
    const target = readLayout('t', 'w1')
    const source = addTab(readLayout('s', 'w2'), pane('s2', 'q2'), 'u2')

    // As tabs: both of its tabs, the one on show first, focused.
    const tabs = merge(target, source, { kind: 'tab' })
    expect(tabs.tabs.map((t) => t.id)).toEqual(['tw1', 'u2', 'tw2'])
    expect(tabs.focus).toBe('q2')

    // Beside a pane: its tab on show splits in, the rest follow as tabs.
    const beside = merge(target, source, { kind: 'split', paneId: 'w1', side: 'left' })
    expect(beside.tabs).toHaveLength(2)
    expect(allPanes({ ...beside, tabs: [beside.tabs[0]] }).map((p) => p.id)).toEqual(['q2', 'w1'])
    expect(beside.focus).toBe('q2')
    expect(ids(beside).sort()).toEqual(['q2', 'w1', 'w2'])
  })

  it('names the side nearest the pointer', () => {
    const r = { x: 0, y: 0, w: 100, h: 100 }
    expect(sideAt(r, 10, 50)).toBe('left')
    expect(sideAt(r, 95, 40)).toBe('right')
    expect(sideAt(r, 50, 5)).toBe('top')
    expect(sideAt(r, 60, 90)).toBe('bottom')
  })
})
