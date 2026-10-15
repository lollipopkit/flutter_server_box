/// The first-run guide: when it is shown, and what takes it away. Its step
/// state lives in `GuideFlow`; whether it is on screen at all is the
/// account's own preference (`DeskPrefs.needsGuide`).

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'

import GuideHarness from './fixtures/GuideHarness.svelte'
import { Desk } from '../desk/deskState.svelte'
import { DeskPrefs } from '../desk/prefs.svelte'
import { GuideFlow } from '../desk/guide/flow.svelte'
import type { DeskPreferences, SessionSave, StoredSession } from '../desk/deskApi'
import type { DeskStorage } from '../desk/storage'
import { servers } from '../lib/servers.svelte'

/// A storage that keeps what it is given, as the agent's does.
class FakeStorage implements DeskStorage {
  readonly remote = true
  readonly keepsThemes = true
  stored: DeskPreferences | null = null
  saves = 0

  constructor(preferences: DeskPreferences | null) {
    this.stored = preferences
  }

  async appItems() {
    return {}
  }
  async appPut() {}
  async appRemove() {}
  async load() {
    return { preferences: this.stored ? { ...this.stored } : null, wallpaperSha: null }
  }
  async savePreferences(p: DeskPreferences) {
    this.saves++
    this.stored = { ...p }
  }
  async loadSession(): Promise<StoredSession> {
    return { revision: 0, active_window_id: null, windows: [] }
  }
  async saveSession(): Promise<SessionSave> {
    return { ok: true, revision: 1 }
  }
  async wallpaperUrl() {
    return null
  }
  async putWallpaper() {}
  async deleteWallpaper() {}
  async notifications() {
    return { notifications: [], unread: 0 }
  }
  async markRead() {}
  events = null
}

/// The panel's defaults, as `prefs.svelte` starts from (`defaults()`).
const defaults: DeskPreferences = {
  accent: null,
  wallpaper: 'preset:bloom',
  wallpaper_fit: 'cover',
  dock: ['serverbox.status', 'serverbox.files'],
  icons: [],
  background: true,
  background_denied: [],
  onboarded_at: null,
}

async function loaded(preferences: DeskPreferences | null) {
  const storage = new FakeStorage(preferences)
  const prefs = new DeskPrefs(storage)
  await prefs.load()
  return { prefs, storage }
}

describe('the first-run guide', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    // The guide names the machine it is on (`serverNames`, else the entry).
    servers.list = [{ id: 'a', url: 'https://box.example', token: 't' }]
    servers.currentId = 'a'
  })

  it('is shown to an account with nothing stored, and on an agent without the field', async () => {
    const { prefs } = await loaded(null)
    expect(prefs.needsGuide).toBe(true)
    // An agent that predates the field: the row is there, the mark is not.
    const older = await loaded({ ...defaults })
    expect(older.prefs.needsGuide).toBe(true)
  })

  it('is not shown to an account that has seen it', async () => {
    const { prefs } = await loaded({ ...defaults, onboarded_at: '2026-10-16T00:00:00.000Z' })
    expect(prefs.needsGuide).toBe(false)
  })

  it('is not shown before the stored preferences have been read', async () => {
    const storage = new FakeStorage(null)
    const prefs = new DeskPrefs(storage)
    expect(prefs.needsGuide).toBe(false)
    await prefs.load()
    expect(prefs.needsGuide).toBe(true)
  })

  it('marks the account on the agent when skipped or walked to the end', async () => {
    const { prefs, storage } = await loaded(null)
    const skipped = new GuideFlow(prefs)
    skipped.finish()
    await vi.advanceTimersByTimeAsync(1000)
    expect(prefs.needsGuide).toBe(false)
    expect(storage.stored?.onboarded_at).toBeTruthy()

    const { prefs: second, storage: second2 } = await loaded(null)
    const walked = new GuideFlow(second)
    walked.next()
    walked.next()
    walked.next()
    await vi.advanceTimersByTimeAsync(1000)
    expect(second.needsGuide).toBe(false)
    expect(second2.stored?.onboarded_at).toBeTruthy()
  })

  it('offers it again from Settings', async () => {
    const { prefs } = await loaded({ ...defaults, onboarded_at: '2026-10-16T00:00:00.000Z' })
    prefs.showGuideAgain()
    expect(prefs.needsGuide).toBe(true)
  })

  it('is on screen until the account skips it, and steps through', async () => {
    const { prefs } = await loaded(null)
    const desk = new Desk({ id: 'a', url: 'https://box.example', token: 't' })
    render(GuideHarness, { desk, prefs })

    expect(screen.getByRole('dialog')).toHaveTextContent('Welcome to the desk')
    await fireEvent.click(screen.getByRole('button', { name: 'Next' }))
    expect(screen.getByRole('dialog')).toHaveTextContent('Apps live in windows')
    await fireEvent.click(screen.getByRole('button', { name: 'Next' }))
    expect(screen.getByRole('dialog')).toHaveTextContent('Web apps on this machine')

    // Off to install something, or skipping: either way it goes and stays gone.
    await fireEvent.click(screen.getByRole('button', { name: 'Skip' }))
    expect(prefs.needsGuide).toBe(false)
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('steps forward and back, and ticks the apps that were chosen', async () => {
    const { prefs } = await loaded(null)
    const flow = new GuideFlow(prefs)
    expect(flow.first).toBe(true)
    flow.previous()
    expect(flow.step).toBe('welcome')
    flow.next()
    expect(flow.step).toBe('apps')
    flow.next()
    expect(flow.step).toBe('webApps')
    flow.toggle('futo.immich')
    flow.toggle('jellyfin.jellyfin')
    expect(flow.chosen).toEqual(['futo.immich', 'jellyfin.jellyfin'])
    flow.toggle('futo.immich')
    expect(flow.chosen).toEqual(['jellyfin.jellyfin'])
  })
})
