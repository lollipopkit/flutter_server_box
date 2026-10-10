import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import StackHost from '../components/stack/StackHost.svelte'
import StackWindowHarness from './fixtures/StackWindowHarness.svelte'
import { Desk } from '../desk/deskState.svelte'
import { enterUrl, pick } from '../components/stack/text'
import { stackDeployed, stackOf } from '../components/stack/apps'
import { api } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import type { Capabilities, StackApp, StackManifest } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    listStacks: vi.fn(),
    prepareStack: vi.fn(),
    installStack: vi.fn(),
    checkStack: vi.fn(),
    enterStack: vi.fn(),
    stackJob: vi.fn(),
  },
}))

const mocked = vi.mocked(api)

const manifest: StackManifest = {
  id: 'futo.immich',
  publisher: 'futo',
  name: 'immich',
  project: 'Immich',
  developer: 'Immich (FUTO)',
  version: '3.3.1',
  homepage: 'https://immich.app',
  source: 'https://github.com/immich-app/immich/tree/v3.3.1',
  glyph: 'photo_library',
  tone: 'sky',
  categories: ['photos'],
  notices: ['pullsImages', 'publishesPort'],
  title: { en: 'Photos', zh: '相册' },
  description: { en: 'Back up and browse photos.' },
  license: { spdx: 'AGPL-3.0', url: 'https://example.com/LICENSE', accept: true },
  requirements: { memory_min_mib: 4096, memory_recommended_mib: 6144, cores_min: 2, arch: [], os: [] },
  web: { port: 'port', path: '/' },
  settings: [
    { type: 'path', key: 'library', label: { en: 'Library' }, env: 'UPLOAD_LOCATION', default: '{stack}/library', data: true },
    { type: 'port', key: 'port', label: { en: 'Port' }, env: 'IMMICH_PORT', default: 2283 },
  ],
}

const app = (stack: StackApp['stack'], proxy = false): StackApp => ({ manifest, stack, job: null, proxy })

const caps = (admin: boolean) =>
  ({ features: ['stacks'], me: { username: 'u', role: admin ? 'admin' : 'viewer', admin } }) as unknown as Capabilities

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't', username: 'u' }]
  servers.currentId = 'local'
  mocked.prepareStack.mockResolvedValue({
    defaults: { library: '/srv/stacks/immich/library', port: 2283 },
    runtime: { available: true, runtime: 'docker', compose: '5.6.0' },
    memory_mib: 16384,
    cores: 8,
    gpus: [],
    gpus_seen: [],
    wsl: false,
  })
})

describe('the Photos window', () => {
  it('tells an account that is not an admin to wait for one', async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    mocked.listStacks.mockResolvedValue({ apps: [app(null)] })
    render(StackHost, { stackId: 'futo.immich' })
    expect(await screen.findByText('Not set up')).toBeInTheDocument()
    expect(mocked.prepareStack).not.toHaveBeenCalled()
  })

  it('confirms the project, its licence and what it installs before the password', async () => {
    capabilitiesStore.byServer = { local: caps(true) }
    mocked.listStacks.mockResolvedValue({ apps: [app(null)] })
    mocked.checkStack.mockResolvedValue({
      settings: { library: '/srv/stacks/immich/library', port: 2283 },
      images: ['ghcr.io/immich-app/immich-server:v3.3.1'],
      data_paths: ['/srv/stacks/immich/library'],
      port: 2283,
      port_free: true,
    })
    render(StackHost, { stackId: 'futo.immich' })
    expect(await screen.findByDisplayValue('/srv/stacks/immich/library')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /set up/i }))

    expect(await screen.findByText('ghcr.io/immich-app/immich-server:v3.3.1')).toBeInTheDocument()
    expect(screen.getByText('Immich (FUTO)')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'AGPL-3.0' })).toHaveAttribute('href', 'https://example.com/LICENSE')
    const go = screen.getByRole('button', { name: 'Continue' })
    expect(go).toBeDisabled()
    await fireEvent.click(screen.getByLabelText(/I understand this installs Immich/))
    expect(go).toBeDisabled()
    await fireEvent.click(screen.getByLabelText('I accept the AGPL-3.0 licence'))
    expect(go).toBeEnabled()
    await fireEvent.click(go)
    await vi.waitFor(() => expect(document.querySelector('input[type=password]')).not.toBeNull())
    expect(mocked.installStack).not.toHaveBeenCalled()
  })

  it('stops at a setting the agent refuses, before any confirmation', async () => {
    capabilitiesStore.byServer = { local: caps(true) }
    mocked.listStacks.mockResolvedValue({ apps: [app(null)] })
    const { ApiError } = await import('../lib/api')
    mocked.checkStack.mockRejectedValue(Object.assign(new ApiError('invalid', 400), { body: { error: 'invalidSetting', field: 'port' } }))
    render(StackHost, { stackId: 'futo.immich' })
    await screen.findByDisplayValue('/srv/stacks/immich/library')
    await fireEvent.click(screen.getByRole('button', { name: /set up/i }))
    expect(await screen.findByText('Check Port.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Continue' })).toBeNull()
  })

  it('frames the running app through its proxy', async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    mocked.listStacks.mockResolvedValue({ apps: [app({ state: 'installed', version: '3.3.1' }, true)] })
    mocked.enterStack.mockResolvedValue({ ticket: 'abc.def', port: 3780, tls: false, path: '/', enter: '/__sbm/enter' })
    const { container } = render(StackHost, { stackId: 'futo.immich' })
    await vi.waitFor(() => expect(container.querySelector('iframe')).not.toBeNull())
    const src = new URL(container.querySelector('iframe')!.getAttribute('src')!)
    expect(src.port).toBe('3780')
    expect(src.pathname).toBe('/__sbm/enter')
    expect(src.searchParams.get('ticket')).toBe('abc.def')
  })
})

describe('the Photos frame in a window', () => {
  it('takes the first click itself only while the window is behind', async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    mocked.listStacks.mockResolvedValue({ apps: [app({ state: 'installed', version: '3.3.1' }, true)] })
    mocked.enterStack.mockResolvedValue({ ticket: 'abc.def', port: 3780, tls: false, path: '/', enter: '/__sbm/enter' })
    const desk = new Desk({ id: 'local', url: '', token: 't', username: 'u' })
    const id = desk.open('serverbox.photos', {}) ?? 'w'
    const shield = (c: HTMLElement) => c.querySelector('iframe')?.nextElementSibling ?? null

    const behind = render(StackWindowHarness, { desk, id, state: 'visible' })
    await vi.waitFor(() => expect(behind.container.querySelector('iframe')).not.toBeNull())
    expect(shield(behind.container)).not.toBeNull()
    behind.unmount()

    const front = render(StackWindowHarness, { desk, id, state: 'active' })
    await vi.waitFor(() => expect(front.container.querySelector('iframe')).not.toBeNull())
    expect(shield(front.container)).toBeNull()
  })
})

describe('Photos in Apps', () => {
  it('is offered once installed; to an admin also while being set up or failed', () => {
    const with_ = (state: 'installing' | 'installed' | 'failed' | null, admin: boolean) =>
      ({ features: ['stacks'], stacks: state ? [{ id: 'futo.immich', state }] : [], me: { admin } }) as unknown as Capabilities
    expect(stackDeployed(with_(null, true), 'futo.immich')).toBe(false)
    expect(stackDeployed(with_('installed', false), 'futo.immich')).toBe(true)
    expect(stackDeployed(with_('failed', false), 'futo.immich')).toBe(false)
    expect(stackDeployed(with_('failed', true), 'futo.immich')).toBe(true)
    expect(stackDeployed({ stacks: [{ id: 'futo.immich', state: 'installed' }] } as unknown as Capabilities, 'futo.immich')).toBe(false)
    expect(stackOf('serverbox.photos')).toBe('futo.immich')
    expect(stackOf('serverbox.files')).toBeUndefined()
  })
})

describe('stack text helpers', () => {
  it('picks the locale, then its language, then English', () => {
    const t = { en: 'Photos', zh: '相册', 'zh-TW': '相簿' }
    expect(pick(t, 'zh-TW')).toBe('相簿')
    expect(pick(t, 'zh-CN')).toBe('相册')
    expect(pick(t, 'de')).toBe('Photos')
    expect(pick(null, 'en')).toBe('')
  })

  it("enters on the server's host at the proxy's port", () => {
    const entry = { ticket: 't.s', port: 3781, tls: true, path: '/albums', enter: '/__sbm/enter' }
    const url = new URL(enterUrl('https://nas.example:3770', entry))
    expect(url.origin).toBe('https://nas.example:3781')
    expect(url.searchParams.get('next')).toBe('/albums')
  })
})
