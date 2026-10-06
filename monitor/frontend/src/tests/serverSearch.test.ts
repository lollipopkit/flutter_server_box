/// The sidebar's server search: the matching rule on its own, and the field
/// that uses it.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import { serverMatches } from '../lib/serverSearch'

const mocks = vi.hoisted(() => ({
  select: vi.fn(),
  navigate: vi.fn(),
  back: vi.fn(),
}))

vi.mock('../lib/servers.svelte', () => ({
  servers: {
    list: [] as unknown[],
    currentId: 'a',
    servedByAgent: false,
    select: mocks.select,
    logout: vi.fn(),
    add: vi.fn(),
    confirmSameOrigin: vi.fn(async () => {}),
  },
  displayName: (e: { url: string; id: string }) => e.url || e.id,
}))

vi.mock('../lib/layout.svelte', () => ({
  layout: {
    collapsed: false,
    mobileOpen: false,
    view: 'dashboard',
    addServerOpen: false,
    navigate: mocks.navigate,
    back: mocks.back,
    toggleCollapsed: vi.fn(),
  },
}))

vi.mock('../lib/capabilities.svelte', () => ({
  capabilitiesStore: { byServer: {}, ensure: vi.fn() },
}))

vi.mock('../lib/health.svelte', () => ({
  health: { status: {}, start: vi.fn(), stop: vi.fn() },
}))

vi.mock('../lib/serverNames.svelte', () => ({
  serverNames: { byServer: {}, refresh: vi.fn(async () => {}), start: vi.fn(), stop: vi.fn() },
}))

import Sidebar from '../components/Sidebar.svelte'
import { serverNames } from '../lib/serverNames.svelte'
import { servers } from '../lib/servers.svelte'

const SEARCH = 'Search'

beforeEach(() => {
  // Two servers, each with the agent's live name, so a query can match the
  // name or the URL separately.
  servers.list = [
    { id: 'a', url: 'https://alpha.example', token: 't', username: 'admin' },
    { id: 'b', url: 'https://beta.example', token: 't', username: 'admin' },
  ]
  ;(servers as unknown as { currentId: string }).currentId = 'a'
  ;(serverNames as unknown as { byServer: Record<string, string> }).byServer = {
    a: 'Alpha',
    b: 'Beta',
  }
  mocks.select.mockClear()
})

afterEach(cleanup)

describe('serverMatches', () => {
  it('keeps everything for an empty query', () => {
    expect(serverMatches('', 'Alpha', 'https://alpha.example')).toBe(true)
    expect(serverMatches('   ', 'Alpha', 'https://alpha.example')).toBe(true)
  })

  it('matches the label, case-insensitively', () => {
    expect(serverMatches('alpha', 'Alpha', 'https://x.example')).toBe(true)
    expect(serverMatches('ALPHA', 'Alpha', 'https://x.example')).toBe(true)
    expect(serverMatches('alp', 'Alpha', 'https://x.example')).toBe(true)
  })

  it('matches the URL', () => {
    expect(serverMatches('beta.example', 'Beta', 'https://beta.example')).toBe(true)
    expect(serverMatches('https://beta', 'Beta', 'https://beta.example')).toBe(true)
  })

  it('drops a row neither matches', () => {
    expect(serverMatches('gamma', 'Alpha', 'https://alpha.example')).toBe(false)
  })
})

describe('the sidebar search field', () => {
  const search = () => screen.getByPlaceholderText(SEARCH) as HTMLInputElement

  it('is absent with a single server', () => {
    servers.list = [servers.list[0]]
    render(Sidebar)
    expect(screen.queryByPlaceholderText(SEARCH)).toBeNull()
  })

  it('hides the rows that do not match and keeps the selected one', async () => {
    render(Sidebar)
    await fireEvent.input(search(), { target: { value: 'beta.example' } })

    expect(screen.queryByText('Alpha')).toBeNull()
    expect(screen.getByText('Beta')).toBeInTheDocument()
    // Filtering hides rows; it never changes what is selected.
    expect(mocks.select).not.toHaveBeenCalled()
  })

  it('says so when nothing matches', async () => {
    render(Sidebar)
    await fireEvent.input(search(), { target: { value: 'nothing-like-this' } })

    expect(screen.getByText('No matching servers')).toBeInTheDocument()
  })

  it('selects the only match on Enter', async () => {
    render(Sidebar)
    await fireEvent.input(search(), { target: { value: 'Beta' } })
    await fireEvent.keyDown(search(), { key: 'Enter' })

    expect(mocks.select).toHaveBeenCalledWith('b')
  })

  it('does not select on Enter while several rows match', async () => {
    render(Sidebar)
    await fireEvent.input(search(), { target: { value: 'e' } })
    await fireEvent.keyDown(search(), { key: 'Enter' })

    expect(mocks.select).not.toHaveBeenCalled()
  })

  it('clears the field on Escape', async () => {
    render(Sidebar)
    await fireEvent.input(search(), { target: { value: 'Beta' } })
    expect(search()).toHaveValue('Beta')

    await fireEvent.keyDown(search(), { key: 'Escape' })
    expect(search()).toHaveValue('')
  })
})
