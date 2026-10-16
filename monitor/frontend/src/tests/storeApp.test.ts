import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import StoreApp from '../desk/apps/store/StoreApp.svelte'
import { api } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import type { Capabilities, StackApp, StackManifest } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { listStacks: vi.fn(), refreshStacks: vi.fn(), prepareStack: vi.fn() },
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
})

describe('the App Store', () => {
  it('lists the catalog with each app state, filtered by search', async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    render(StoreApp)
    expect(await screen.findByText('Immich does things.')).toBeInTheDocument()
    expect(screen.getByText('Installed')).toBeInTheDocument()
    // Installed, but its containers are not running.
    expect(screen.getByText('Down')).toBeInTheDocument()
    expect(screen.getByText('Media does things.')).toBeInTheDocument()
    await fireEvent.input(screen.getByPlaceholderText('Search apps'), { target: { value: 'media' } })
    expect(screen.queryByText('Immich does things.')).toBeNull()
    expect(screen.getByText('Media does things.')).toBeInTheDocument()
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
