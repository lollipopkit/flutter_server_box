import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { monthGrid } from '../desk/calendar'
import type { DeskIcon, SessionSave, StoredSession } from '../desk/deskApi'
import { CELL, placeIcons } from '../desk/iconGrid'
import { SAVE_DELAY_MS, SessionSync } from '../desk/session.svelte'
import { BrowserStorage, type DeskStorage } from '../desk/storage'
import { WindowManager, type WindowPolicy } from '../desk/windows.svelte'

const policy: WindowPolicy = { instances: 3, size: { width: 600, height: 400 }, minSize: { width: 300, height: 200 } }

function manager() {
  const m = new WindowManager((id) => (id === 'files' || id === 'terminal' ? policy : undefined))
  m.resizeArea({ width: 1200, height: 800, top: 40, bottom: 80 })
  return m
}

/// A storage that keeps one session and can be moved on behind the desk's
/// back, as another tab would.
function fakeStorage() {
  let stored: StoredSession = { revision: 0, active_window_id: null, windows: [] }
  const saves: number[] = []
  const storage = {
    remote: true,
    loadSession: vi.fn(async () => structuredClone(stored)),
    saveSession: vi.fn(async (_d: string, expected: number, s: Omit<StoredSession, 'revision'>): Promise<SessionSave> => {
      if (expected !== stored.revision) return { ok: false, current: structuredClone(stored) }
      stored = { ...structuredClone(s), revision: expected + 1 }
      saves.push(stored.revision)
      return { ok: true, revision: stored.revision }
    }),
  } as unknown as DeskStorage
  return {
    storage,
    saves,
    get stored() {
      return stored
    },
    /// Another tab saved.
    elsewhere(windows: StoredSession['windows']) {
      stored = { revision: stored.revision + 1, active_window_id: null, windows }
    },
  }
}

describe('SessionSync', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('saves after a pause, once for a burst of changes', async () => {
    const f = fakeStorage()
    const m = manager()
    const sync = new SessionSync(m, f.storage, 'dev', 'local', () => true)
    await sync.load()
    m.open('files')
    sync.schedule()
    m.open('terminal')
    sync.schedule()
    await vi.advanceTimersByTimeAsync(SAVE_DELAY_MS + 10)
    expect(f.saves).toEqual([1])
    expect(f.stored.windows.map((w) => w.app_id).sort()).toEqual(['files', 'terminal'])
  })

  it('the tab in use wins a conflict', async () => {
    const f = fakeStorage()
    const m = manager()
    const sync = new SessionSync(m, f.storage, 'dev', 'local', () => true)
    await sync.load()
    f.elsewhere([])
    m.open('files')
    await sync.flush()
    expect(f.stored.revision).toBe(2)
    expect(f.stored.windows.map((w) => w.app_id)).toEqual(['files'])
    expect(sync.revision).toBe(2)
  })

  it('a tab not in use takes the other tab\'s windows', async () => {
    const f = fakeStorage()
    const m = manager()
    const sync = new SessionSync(m, f.storage, 'dev', 'local', () => false)
    await sync.load()
    const theirs = manager()
    theirs.open('terminal')
    f.elsewhere(theirs.serialize('local').windows)
    m.open('files')
    await sync.flush()
    expect(m.windows.map((w) => w.appId)).toEqual(['terminal'])
    expect(f.stored.revision).toBe(1)
  })

  it('reloads on another tab\'s event only when not in use', async () => {
    const f = fakeStorage()
    let inUse = true
    const m = manager()
    const sync = new SessionSync(m, f.storage, 'dev', 'local', () => inUse)
    await sync.load()
    const theirs = manager()
    theirs.open('terminal')
    f.elsewhere(theirs.serialize('local').windows)
    await sync.remoteChanged('dev', 1)
    expect(m.windows).toHaveLength(0)
    inUse = false
    await sync.remoteChanged('other-device', 1)
    expect(m.windows).toHaveLength(0)
    await sync.remoteChanged('dev', 1)
    expect(m.windows.map((w) => w.appId)).toEqual(['terminal'])
  })

  it('saves what is pending when closed, then nothing more', async () => {
    const f = fakeStorage()
    const m = manager()
    const sync = new SessionSync(m, f.storage, 'dev', 'local', () => true)
    await sync.load()
    m.open('files')
    sync.schedule()
    await sync.close()
    expect(f.saves).toEqual([1])
    m.open('terminal')
    sync.schedule()
    await vi.advanceTimersByTimeAsync(SAVE_DELAY_MS + 10)
    expect(f.saves).toEqual([1])
  })

  it('keeps working unsaved when the storage cannot be reached', async () => {
    const m = manager()
    const storage = {
      loadSession: vi.fn(async () => {
        throw new Error('down')
      }),
    } as unknown as DeskStorage
    const sync = new SessionSync(m, storage, 'dev', 'local', () => true)
    await sync.load()
    expect(sync.status).toBe('failed')
    m.open('files')
    expect(m.windows).toHaveLength(1)
  })
})

describe('BrowserStorage', () => {
  beforeEach(() => window.localStorage.clear())

  it('checks the revision as the agent does', async () => {
    const s = new BrowserStorage('srv')
    const first = await s.saveSession('dev', 0, { active_window_id: null, windows: [] })
    expect(first).toEqual({ ok: true, revision: 1 })
    const stale = await s.saveSession('dev', 0, { active_window_id: null, windows: [] })
    expect(stale.ok).toBe(false)
    expect((await s.loadSession('dev')).revision).toBe(1)
    // Per server.
    expect((await new BrowserStorage('other').loadSession('dev')).revision).toBe(0)
  })
})

describe('icon grid', () => {
  const area = { width: 1000, height: 400 }
  const icon = (id: string, col?: number, row?: number): DeskIcon => ({
    id,
    kind: 'app',
    app_id: 'files',
    label: '',
    col: col ?? null,
    row: row ?? null,
  })

  it('fills from the top-right, down then left', () => {
    const placed = placeIcons([icon('a'), icon('b'), icon('c'), icon('d')], area)
    const rows = Math.floor((area.height - CELL.margin) / CELL.height)
    expect(placed[0].x).toBe(area.width - CELL.margin - CELL.width)
    expect(placed[1].y).toBe(CELL.margin + CELL.height)
    expect(placed[rows].x).toBe(area.width - CELL.margin - 2 * CELL.width)
  })

  it('keeps asked-for cells and fills around them', () => {
    const placed = placeIcons([icon('a'), icon('b', 0, 0)], area)
    expect(placed[1]).toMatchObject({ x: area.width - CELL.margin - CELL.width, y: CELL.margin })
    expect(placed[0].y).toBe(CELL.margin + CELL.height)
  })

  it('a cell asked for twice goes to the first', () => {
    const placed = placeIcons([icon('a', 1, 1), icon('b', 1, 1)], area)
    expect([placed[0].x, placed[0].y]).not.toEqual([placed[1].x, placed[1].y])
  })
})

describe('calendar', () => {
  it('lays a month out in whole weeks, Monday first', () => {
    // October 2026 starts on a Thursday.
    const weeks = monthGrid(2026, 9)
    expect(weeks[0]).toHaveLength(7)
    expect(weeks[0][3].date.getDate()).toBe(1)
    expect(weeks[0][0].inMonth).toBe(false)
    const days = weeks.flat().filter((d) => d.inMonth)
    expect(days).toHaveLength(31)
  })
})
