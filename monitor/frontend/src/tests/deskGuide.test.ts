/// The first-run guide: when it is shown, and what takes it away. Its step
/// state lives in `GuideFlow`; whether it is on screen at all is the
/// account's (`DeskPrefs.needsGuide`, `/desk/onboarding`).

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'

import GuideHarness from './fixtures/GuideHarness.svelte'
import { Desk } from '../desk/deskState.svelte'
import { DeskPrefs, defaults as defaultPreferences } from '../desk/prefs.svelte'
import { GuideFlow } from '../desk/guide/flow.svelte'
import type { DeskPreferences, SessionSave, StoredSession } from '../desk/deskApi'
import { BrowserStorage, type DeskStorage } from '../desk/storage'
import { servers } from '../lib/servers.svelte'

/// A storage that keeps what it is given, as the agent's does.
class FakeStorage implements DeskStorage {
  readonly remote = true
  readonly keepsThemes = true
  stored: DeskPreferences | null = null
  onboarded: boolean
  saves = 0

  constructor(preferences: DeskPreferences | null, onboarded = false) {
    this.stored = preferences
    this.onboarded = onboarded
  }

  async appItems() {
    return {}
  }
  async appPut() {}
  async appRemove() {}
  async load() {
    return { preferences: this.stored ? { ...this.stored } : null, wallpaperSha: null, onboarded: this.onboarded }
  }
  async savePreferences(p: DeskPreferences) {
    this.saves++
    this.stored = { ...p }
  }
  async setOnboarded(done: boolean) {
    this.onboarded = done
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

async function loaded(onboarded = false) {
  const storage = new FakeStorage(null, onboarded)
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

  it('is shown to an account that has not been through it, and only after loading', async () => {
    const storage = new FakeStorage(null)
    const prefs = new DeskPrefs(storage)
    expect(prefs.needsGuide).toBe(false)
    await prefs.load()
    expect(prefs.needsGuide).toBe(true)
    expect((await loaded(true)).prefs.needsGuide).toBe(false)
  })

  it('is marked done when skipped or walked to the end, apart from the preferences', async () => {
    const { prefs, storage } = await loaded()
    new GuideFlow(prefs).finish()
    expect(prefs.needsGuide).toBe(false)
    await vi.advanceTimersByTimeAsync(1000)
    expect(storage.onboarded).toBe(true)
    expect(storage.saves).toBe(0)

    const second = await loaded()
    const walked = new GuideFlow(second.prefs)
    walked.next()
    walked.next()
    walked.next()
    expect(second.prefs.needsGuide).toBe(false)
    expect(second.storage.onboarded).toBe(true)
  })

  it('offers it again from Settings', async () => {
    const { prefs, storage } = await loaded(true)
    prefs.showGuideAgain()
    expect(prefs.needsGuide).toBe(true)
    expect(storage.onboarded).toBe(false)
  })

  it('is on screen until the account skips it, and steps through', async () => {
    const { prefs } = await loaded()
    const desk = new Desk({ id: 'a', url: 'https://box.example', token: 't' })
    render(GuideHarness, { desk, prefs })

    expect(screen.getByRole('dialog')).toHaveTextContent('Welcome to the desk')
    await fireEvent.click(screen.getByRole('button', { name: 'Next' }))
    expect(screen.getByRole('dialog')).toHaveTextContent('Where the apps are')
    await fireEvent.click(screen.getByRole('button', { name: 'Next' }))
    expect(screen.getByRole('dialog')).toHaveTextContent('Recommended web apps')

    // The last step has no Skip: Done ends it the same way.
    expect(screen.queryByRole('button', { name: 'Skip' })).toBeNull()
    await fireEvent.click(screen.getByRole('button', { name: 'Done' }))
    expect(prefs.needsGuide).toBe(false)
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('steps forward and back', async () => {
    const { prefs } = await loaded()
    const flow = new GuideFlow(prefs)
    expect(flow.first).toBe(true)
    flow.previous()
    expect(flow.step).toBe('welcome')
    flow.next()
    expect(flow.step).toBe('apps')
    flow.next()
    expect(flow.step).toBe('webApps')
    flow.previous()
    expect(flow.step).toBe('apps')
  })

  it('is kept in the browser for an agent that keeps no desk; a desk used before is not greeted', async () => {
    localStorage.clear()
    const fresh = new BrowserStorage('fresh')
    expect((await fresh.load()).onboarded).toBe(false)
    await fresh.setOnboarded(true)
    expect((await new BrowserStorage('fresh').load()).onboarded).toBe(true)

    const used = new BrowserStorage('used')
    await used.savePreferences(defaultPreferences())
    expect((await used.load()).onboarded).toBe(true)
    await used.setOnboarded(false)
    expect((await used.load()).onboarded).toBe(false)
  })
})
