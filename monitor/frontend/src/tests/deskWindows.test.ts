import { describe, expect, it } from 'vitest'
import { type Area, cascade, clamp, KEEP_VISIBLE, resize, snapRect, snapZoneAt, unsnapUnder } from '../desk/geometry'
import { WindowManager, type WindowPolicy } from '../desk/windows.svelte'

const area: Area = { width: 1200, height: 800, top: 40, bottom: 80, left: 0, right: 0 }
const min = { width: 300, height: 200 }

const policies: Record<string, WindowPolicy> = {
  files: { instances: 1, size: { width: 800, height: 500 }, minSize: min },
  terminal: { instances: 3, size: { width: 700, height: 450 }, minSize: min },
}

function manager() {
  const m = new WindowManager((id) => policies[id])
  m.resizeArea(area)
  return m
}

describe('geometry', () => {
  it('keeps a side dock clear', () => {
    const side: Area = { ...area, left: 78, right: 0 }
    expect(snapRect('max', side)).toEqual({ x: 85, y: 40, width: 1200 - 78 - 14, height: 680 })
    expect(snapRect('left', side).x).toBe(85)
    expect(snapZoneAt(80, 400, side)).toBe('left')
    expect(snapZoneAt(40, 400, side)).toBe('left')
    expect(clamp({ x: -5000, y: 100, width: 400, height: 300 }, side, min).x).toBe(78 + KEEP_VISIBLE - 400)
    const right: Area = { ...area, right: 78 }
    expect(snapZoneAt(1200 - 80, 400, right)).toBe('right')
    expect(snapRect('right', right).x + snapRect('right', right).width).toBe(1200 - 78 - 7)
  })

  it('keeps a window reachable and within its limits', () => {
    expect(clamp({ x: -5000, y: -50, width: 100, height: 5000 }, area, min)).toEqual({
      x: KEEP_VISIBLE - 300,
      y: 40,
      width: 300,
      height: 680,
    })
    const far = clamp({ x: 5000, y: 5000, width: 400, height: 300 }, area, min)
    expect(far.x).toBe(1200 - KEEP_VISIBLE)
    expect(far.y).toBeLessThan(800 - 80)
  })

  it('cascades new windows', () => {
    const a = cascade(0, { width: 800, height: 500 }, area)
    const b = cascade(1, { width: 800, height: 500 }, area)
    expect(b.x - a.x).toBe(28)
    expect(b.y - a.y).toBe(28)
    expect(a.y).toBeGreaterThanOrEqual(area.top)
  })

  it('snaps to halves and the whole area', () => {
    expect(snapRect('max', area)).toEqual({ x: 7, y: 40, width: 1186, height: 680 })
    expect(snapRect('left', area)).toEqual({ x: 7, y: 40, width: 590, height: 680 })
    expect(snapRect('right', area)).toEqual({ x: 604, y: 40, width: 589, height: 680 })
    expect(snapZoneAt(500, 42, area)).toBe('max')
    expect(snapZoneAt(2, 400, area)).toBe('left')
    expect(snapZoneAt(1198, 400, area)).toBe('right')
    expect(snapZoneAt(600, 400, area)).toBeNull()
  })

  it('resizes from any edge, the opposite one staying put', () => {
    const start = { x: 100, y: 100, width: 500, height: 400 }
    expect(resize(start, 'se', 50, 20, min)).toEqual({ x: 100, y: 100, width: 550, height: 420 })
    expect(resize(start, 'nw', 50, 20, min)).toEqual({ x: 150, y: 120, width: 450, height: 380 })
    // Never below the minimum, and the right edge does not move.
    const w = resize(start, 'w', 400, 0, min)
    expect(w.width).toBe(300)
    expect(w.x + w.width).toBe(600)
  })

  it('restores a snapped window under the pointer', () => {
    const r = unsnapUnder(900, 60, { x: 600, y: 40, width: 600, height: 680 }, { width: 400, height: 300 })
    expect(r.width).toBe(400)
    expect(r.x).toBe(900 - 200)
  })
})

describe('WindowManager', () => {
  it('focuses the one window a single-instance app allows', () => {
    const m = manager()
    const a = m.open('files', { appState: { path: '/a' } })!
    const b = m.open('files', { appState: { path: '/b' } })
    expect(b).toBe(a)
    expect(m.windows).toHaveLength(1)
    expect(m.get(a)!.appState).toEqual({ path: '/b' })
  })

  it('opens several windows up to the limit', () => {
    const m = manager()
    m.open('terminal')
    m.open('terminal')
    m.open('terminal')
    expect(m.open('terminal')).toBeNull()
    expect(m.of('terminal')).toHaveLength(3)
    expect(m.open('nope')).toBeNull()
  })

  it('orders, minimises and focuses', () => {
    const m = manager()
    const a = m.open('files')!
    const b = m.open('terminal')!
    expect(m.active?.id).toBe(b)
    m.minimize(b)
    expect(m.active?.id).toBe(a)
    m.focus(b)
    expect(m.get(b)!.minimized).toBe(false)
    expect(m.active?.id).toBe(b)
  })

  it('maximises and goes back', () => {
    const m = manager()
    const a = m.open('files')!
    const before = { ...m.get(a)!.rect }
    m.toggleMaximize(a)
    expect(m.get(a)!.rect).toEqual(snapRect('max', area))
    m.toggleMaximize(a)
    expect(m.get(a)!.rect).toEqual(before)
  })

  it('round-trips through what the agent stores', () => {
    const m = manager()
    const a = m.open('files', { appState: { path: '/etc' } })!
    const b = m.open('terminal')!
    const before = { ...m.get(a)!.rect }
    m.toggleMaximize(a)
    m.minimize(b)
    const stored = m.serialize('local')
    expect(stored.windows.find((w) => w.window_id === a)).toMatchObject({
      maximized: true,
      x: before.x,
      width: before.width,
      app_state: { path: '/etc' },
      server_id: 'local',
    })

    const n = manager()
    n.hydrate([...stored.windows, { ...stored.windows[0], window_id: 'gone', app_id: 'retired' }])
    expect(n.windows.map((w) => w.id).sort()).toEqual([a, b].sort())
    expect(n.get(a)!.snap).toBe('max')
    expect(n.get(b)!.minimized).toBe(true)
    n.toggleMaximize(a)
    expect(n.get(a)!.rect).toEqual(before)
  })

  it('keeps a mounted window object when hydrating over it', () => {
    const m = manager()
    const a = m.open('files')!
    const object = m.get(a)
    m.hydrate(m.serialize(null).windows)
    expect(m.get(a)).toBe(object)
  })

  it('counts changes worth saving', () => {
    const m = manager()
    const start = m.changes
    const a = m.open('files')!
    m.place(a, { x: 10, y: 50, width: 400, height: 300 })
    m.setTitle(a, 'x')
    expect(m.changes).toBe(start + 2)
  })

  it('is compact on a narrow screen', () => {
    const m = manager()
    m.resizeArea({ ...area, width: 600 })
    expect(m.compact).toBe(true)
  })
})
