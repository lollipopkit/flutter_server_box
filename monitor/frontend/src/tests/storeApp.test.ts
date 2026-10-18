import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import StoreApp from '../desk/apps/store/StoreApp.svelte'
import { api } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import type { Capabilities, InstalledApp, OfferedApp, StackApp, StackManifest } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    listStacks: vi.fn(),
    refreshStacks: vi.fn(),
    prepareStack: vi.fn(),
    appCatalog: vi.fn(),
    listApps: vi.fn(),
    removeApp: vi.fn(),
    installOffered: vi.fn(),
    approveApp: vi.fn(),
  },
}))

const mocked = vi.mocked(api)

// jsdom has no Web Animations API, which the page transitions reach for.
Element.prototype.animate ??= function (this: Element) {
  return { cancel() {}, finished: Promise.resolve(), onfinish: null, playState: 'idle' } as unknown as Animation
}

const manifest = (name: string, title: string, categories: string[]): StackManifest => ({
  id: `acme.${name}`,
  publisher: 'acme',
  name,
  project: title,
  developer: `${title} team`,
  version: '1.0.0',
  homepage: 'https://example.com',
  source: 'https://example.com/src',
  glyph: 'apps',
  tone: 'sky',
  categories,
  notices: [],
  title: { en: title },
  description: { en: `${title} does things.` },
  license: { spdx: 'MIT', url: 'https://example.com/LICENSE', accept: false },
  requirements: { arch: [], os: [] },
  web: { port: 'port', path: '/' },
  settings: [],
})

const apps: StackApp[] = [
  { manifest: manifest('immich', 'Immich', ['photos']), stack: { state: 'installed', version: '1.0.0' }, job: null, proxy: true },
  { manifest: manifest('broken', 'Broken', ['tools']), stack: { state: 'installed', version: '1.0.0' }, job: null, proxy: true, health: { state: 'down', failing: ['web'], checked_at: '' } },
  { manifest: manifest('jellyfin', 'Media', ['media']), stack: null, job: null, proxy: false, source: 'local' },
]

const caps = (ok: boolean) =>
  ({ features: ['stacks'], stacks: [], access: ok ? { ok } : { ok, why: 'insecure_transport' } }) as unknown as Capabilities

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't' }]
  servers.currentId = 'local'
  mocked.listStacks.mockResolvedValue({ apps: structuredClone(apps) })
  mocked.appCatalog.mockResolvedValue({ apps: [offered] })
  mocked.listApps.mockResolvedValue({ apps: [installedKernel] })
})

const kernelManifest = {
  publisher: 'serverbox',
  name: 'kernel',
  version: '1.1.0',
  api: 2,
  kind: 'wasm' as const,
  title: { en: 'Kernels' },
  description: { en: 'The kernels GRUB boots.' },
  glyph: 'memory',
  tone: 'ink',
  permissions: ['root'],
}
const offered: OfferedApp = { id: 'serverbox.kernel', version: '1.1.0', sha256: 'a'.repeat(64), size: 2048, manifest: kernelManifest, signedBy: 'serverbox-2026', source: 'bundled', repo: null }
const installedKernel: InstalledApp = {
  id: 'serverbox.kernel',
  version: '1.1.0',
  sha256: 'a'.repeat(64),
  manifest: kernelManifest,
  approved_permissions: ['root'],
  installed_at: '2026-10-18T00:00:00Z',
  approved_at: '2026-10-18T00:00:00Z',
  signed_by: 'serverbox-2026',
}

describe('the App Store', () => {
  it('lists the catalog with each app state, filtered by search', async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    render(StoreApp)
    expect(await screen.findByText('Immich does things.')).toBeInTheDocument()
    // The badge, beside the sidebar's place of the same name
    expect(screen.getAllByText('Installed')).toHaveLength(2)
    // Installed, but its containers are not running.
    expect(screen.getByText('Down')).toBeInTheDocument()
    expect(screen.getByText('Media does things.')).toBeInTheDocument()
    await fireEvent.input(screen.getByPlaceholderText('Search apps'), { target: { value: 'media' } })
    expect(screen.queryByText('Immich does things.')).toBeNull()
    expect(screen.getByText('Media does things.')).toBeInTheDocument()
  })

  it('shows the place chosen in the sidebar, and searches every place', async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    render(StoreApp)
    expect(await screen.findByText('Media does things.')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /^Installed/ }))
    expect(screen.getByText('Immich does things.')).toBeInTheDocument()
    expect(screen.queryByText('Media does things.')).toBeNull()
    await fireEvent.input(screen.getByPlaceholderText('Search apps'), { target: { value: 'media' } })
    expect(screen.getByText('Media does things.')).toBeInTheDocument()
  })

  it("opens a desk app's page and uninstalls it with the password", async () => {
    capabilitiesStore.byServer = { local: caps(true) }
    mocked.removeApp.mockResolvedValue(undefined as never)
    render(StoreApp)
    await fireEvent.click(await screen.findByRole('button', { name: /^Desk apps/ }))
    await fireEvent.click(await screen.findByText('The kernels GRUB boots.'))
    expect(await screen.findByText(/run scripts as root/)).toBeInTheDocument()
    expect(screen.getByText('Shipped with the agent')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: 'Uninstall' }))
    await fireEvent.input(screen.getByLabelText('Current password'), { target: { value: 'pw' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Confirm' }))
    await vi.waitFor(() => expect(mocked.removeApp).toHaveBeenCalledWith('serverbox.kernel', 'pw'))
  })

  it("opens an app's page: set up where the account may act, otherwise told why not", async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    const first = render(StoreApp)
    await fireEvent.click(await screen.findByText('Media does things.'))
    expect(await screen.findByText('This needs HTTPS, or a proxy on the same host.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Get' })).toBeNull()
    first.unmount()

    capabilitiesStore.byServer = { local: caps(true) }
    render(StoreApp)
    await fireEvent.click(await screen.findByText('Media does things.'))
    expect(await screen.findByRole('button', { name: 'Get' })).toBeInTheDocument()
    expect(screen.getAllByText('Media team').length).toBeGreaterThan(0)
  })

  it("marks an app of the server's own folder, and reads the catalog again", async () => {
    capabilitiesStore.byServer = { local: caps(true) }
    mocked.refreshStacks.mockResolvedValue({ apps: structuredClone(apps) })
    render(StoreApp)
    expect(await screen.findByText('Local')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: 'Check for new apps and versions' }))
    expect(mocked.refreshStacks).toHaveBeenCalled()
  })
})
