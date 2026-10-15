import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import SettingsWindowHarness from './fixtures/SettingsWindowHarness.svelte'
import { Desk } from '../desk/deskState.svelte'
import { isSection, resolveSection, SETTINGS_SECTIONS } from '../desk/apps/settings/sections'
import { api } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import type { Capabilities, SettingsView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    getSettings: vi.fn(),
    getCustomCmds: vi.fn(),
    getPush: vi.fn(),
    // The host card is optional: unread here.
    getMetrics: () => Promise.reject(new Error('not in this test')),
  },
}))

const mocked = vi.mocked(api)

// jsdom has no Web Animations API, which `in:fade` reaches for; the settings
// panel must still render (that is the observable part).
Element.prototype.animate ??= function (this: Element) {
  return { cancel() {}, playState: 'idle' } as unknown as Animation
}

const settingsView = (): SettingsView => ({
  interval_seconds: 5,
  extended_interval_secs: null,
  idle_pause_enabled: true,
  idle_pause_threshold_secs: null,
  rules: [],
  data_retention: null,
  cors_allowed_origins: [],
  live_fields: ['interval_seconds'],
  data_retention_defaults: {
    metrics_days: 7,
    alerts_days: 30,
    cleanup_interval_hours: 24,
    max_db_size_mb: 0,
  },
})

const caps = (ok: boolean): Capabilities =>
  ({
    features: ['agent_mode'],
    access: ok ? { ok } : { ok, why: 'insecure_transport' },
  }) as unknown as Capabilities

/// A desk with one Settings window open, so `useWindow()` answers its handle.
function deskWith(appState: unknown): { desk: Desk; id: string } {
  const desk = new Desk({ id: 'local', url: '', token: 't' })
  const id = desk.open('serverbox.settings', { appState })
  if (!id) throw new Error('the settings window did not open')
  return { desk, id }
}

const appStateOf = (desk: Desk, id: string): unknown => desk.windows.get(id)?.appState

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't' }]
  servers.currentId = 'local'
  capabilitiesStore.byServer = { local: caps(true) }
  mocked.getSettings.mockResolvedValue(settingsView())
  mocked.getCustomCmds.mockResolvedValue({ commands: [], editable: true })
  mocked.getPush.mockResolvedValue({
    pushes: [],
    push_rate: null,
    push_types: ['webhook'],
    applies_on_restart: true,
  })
})

describe('settings sections', () => {
  it('knows its own sections and nothing else', () => {
    expect([...SETTINGS_SECTIONS]).toEqual(['general', 'appearance', 'apps', 'account', 'server', 'agent'])
    expect(isSection('server')).toBe(true)
    expect(isSection('Server')).toBe(false)
    expect(isSection(null)).toBe(false)
  })

  it('reads the section a window asked for, and falls back to general', () => {
    expect(resolveSection({ section: 'appearance' })).toBe('appearance')
    expect(resolveSection({ section: 'nonsense' })).toBe('general')
    expect(resolveSection({ path: '/etc' })).toBe('general')
    expect(resolveSection(null)).toBe('general')
  })
})

describe('settings app', () => {
  it('shows the section the window was opened at', async () => {
    const { desk, id } = deskWith({ section: 'server' })
    render(SettingsWindowHarness, { desk, id })

    expect(await screen.findByRole('heading', { level: 1, name: /server settings/i })).toBeInTheDocument()
  })

  it('writes the chosen section to the window and shows its panel', async () => {
    const { desk, id } = deskWith({ section: 'general' })
    render(SettingsWindowHarness, { desk, id })

    await fireEvent.click(screen.getByRole('button', { name: /^server settings$/i }))

    expect(appStateOf(desk, id)).toEqual({ section: 'server' })
    expect(await screen.findByRole('heading', { level: 1, name: /server settings/i })).toBeInTheDocument()
  })

  it('follows a second open that asks for another section', async () => {
    const { desk, id } = deskWith({ section: 'general' })
    render(SettingsWindowHarness, { desk, id })

    desk.windows.setAppState(id, { section: 'account' })

    expect(await screen.findByRole('heading', { level: 1, name: /^account$/i })).toBeInTheDocument()
  })

  it('changes the password where the account may act over this link', async () => {
    const { desk, id } = deskWith({ section: 'account' })
    render(SettingsWindowHarness, { desk, id })

    expect(await screen.findByRole('button', { name: /^change…$/i })).toBeInTheDocument()
    expect(screen.queryByText('Role')).toBeNull()
  })

  it('says why neither the password nor the agent settings change over a plaintext link', async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    const { desk, id } = deskWith({ section: 'server' })
    render(SettingsWindowHarness, { desk, id })

    expect(await screen.findByText('This needs HTTPS, or a proxy on the same host.')).toBeInTheDocument()
    expect(mocked.getSettings).not.toHaveBeenCalled()

    desk.windows.setAppState(id, { section: 'account' })
    expect(await screen.findByRole('heading', { level: 1, name: /^account$/i })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^change…$/i })).toBeNull()
  })

  it('offers Agent mode only where the account may act over this link', () => {
    capabilitiesStore.byServer = { local: caps(false) }
    const { desk, id } = deskWith({ section: 'agent' })
    render(SettingsWindowHarness, { desk, id })

    expect(screen.queryByRole('button', { name: /^agent$/i })).toBeNull()
    // The section it asked for is not offered, so it falls back rather than
    // showing a panel with nothing in it.
    expect(screen.getByRole('heading', { level: 1, name: /^account$/i })).toBeInTheDocument()
  })
})

describe('settings pages of other apps', () => {
  it('lists every app under Apps, each opening a page of its own run as that app', async () => {
    const { registerApp } = await import('../desk/sys')
    const { BrowserStorage } = await import('../desk/storage')
    const { DeskPrefs } = await import('../desk/prefs.svelte')
    const { AppData } = await import('../desk/appData')
    const off = registerApp({
      publisher: 'acme', name: 'greeter',
      title: 'Greeter',
      glyph: 'waving_hand',
      tone: 'amber',
      load: () => import('./fixtures/AppSettingsPage.svelte'),
      settings: () => import('./fixtures/AppSettingsPage.svelte'),
    })
    const { desk, id } = deskWith({ section: 'apps' })
    const storage = new BrowserStorage(`test-${crypto.randomUUID()}`)
    desk.prefs = new DeskPrefs(storage)
    desk.appData = new AppData(storage)
    render(SettingsWindowHarness, { desk, id })

    // A row in the list opens the app's page, kept in the window's state.
    await fireEvent.click(await screen.findByRole('button', { name: /^Greeter/ }))
    expect(desk.windows.get(id)?.appState).toEqual({ section: 'apps', app: 'acme.greeter' })
    expect(await screen.findByRole('heading', { name: 'Greeter' })).toBeInTheDocument()
    expect(screen.getByRole('switch', { name: 'Show in the dock' })).toBeInTheDocument()
    // Its own preferences, in that page.
    await fireEvent.click(await screen.findByRole('button', { name: 'Save greeting' }))
    expect(await screen.findByText('saved: hi')).toBeInTheDocument()
    // Kept as the app's, not Settings'.
    expect(await desk.appData.for('acme.greeter').get('greeting')).toBe('hi')
    expect(await desk.appData.for('settings').keys()).toEqual([])

    // Without an app, the list again.
    desk.windows.setAppState(id, { section: 'apps' })
    expect(await screen.findByText('All apps')).toBeInTheDocument()
    off()
  })
})
