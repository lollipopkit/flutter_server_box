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
    listUsers: vi.fn(),
    listRoles: vi.fn(),
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

const caps = (admin: boolean): Capabilities =>
  ({
    claims: [],
    features: [],
    grants: {
      shell: { ok: true },
      files: { ok: false },
      connect: { ok: false },
      listen: { ok: false },
      virt: { ok: false },
    },
    me: { username: 'admin', role: admin ? 'admin' : 'viewer', admin },
  }) as unknown as Capabilities

/// A desk with one Settings window open, so `useWindow()` answers its handle.
function deskWith(appState: unknown): { desk: Desk; id: string } {
  const desk = new Desk({ id: 'local', url: '', token: 't', username: 'admin' })
  const id = desk.open('settings', { appState })
  if (!id) throw new Error('the settings window did not open')
  return { desk, id }
}

const appStateOf = (desk: Desk, id: string): unknown => desk.windows.get(id)?.appState

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
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
  mocked.listUsers.mockResolvedValue([])
  mocked.listRoles.mockResolvedValue([])
})

describe('settings sections', () => {
  it('knows its own sections and nothing else', () => {
    expect([...SETTINGS_SECTIONS]).toEqual(['general', 'appearance', 'apps', 'account', 'server', 'access'])
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

  it('offers the Access section where this account administers the agent', () => {
    const { desk, id } = deskWith(null)
    render(SettingsWindowHarness, { desk, id })

    expect(screen.getByRole('button', { name: /^access$/i })).toBeInTheDocument()
  })

  it('offers no Access section to an account that does not administer', () => {
    capabilitiesStore.byServer = { local: caps(false) }
    const { desk, id } = deskWith({ section: 'access' })
    render(SettingsWindowHarness, { desk, id })

    expect(screen.queryByRole('button', { name: /^access$/i })).toBeNull()
    // The section it asked for is not offered, so it falls back rather than
    // showing a panel with nothing in it.
    expect(screen.getByRole('heading', { level: 1, name: /^account$/i })).toBeInTheDocument()
  })

  it('offers no Access section where the agent does not say who is asking', () => {
    const { me: _me, ...withoutMe } = caps(true) as unknown as Record<string, unknown>
    void _me
    capabilitiesStore.byServer = { local: withoutMe as unknown as Capabilities }
    const { desk, id } = deskWith(null)
    render(SettingsWindowHarness, { desk, id })

    expect(screen.queryByRole('button', { name: /^access$/i })).toBeNull()
  })
})

describe('settings pages of other apps', () => {
  it('shows them under Apps, each run as its app', async () => {
    const { registerApp } = await import('../desk/sys')
    const { BrowserStorage } = await import('../desk/storage')
    const { DeskPrefs } = await import('../desk/prefs.svelte')
    const { AppData } = await import('../desk/appData')
    const off = registerApp({
      id: 'acme_greeter',
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

    // Inline, in the app's own group.
    expect(await screen.findByRole('heading', { name: 'Greeter' })).toBeInTheDocument()
    await fireEvent.click(await screen.findByRole('button', { name: 'Save greeting' }))
    expect(await screen.findByText('saved: hi')).toBeInTheDocument()
    // Kept as the app's, not Settings'.
    expect(await desk.appData.for('acme_greeter').get('greeting')).toBe('hi')
    expect(await desk.appData.for('settings').keys()).toEqual([])
    off()
  })
})
