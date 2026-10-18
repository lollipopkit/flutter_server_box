import { describe, it, expect, vi, beforeEach } from 'vitest'
import { WebApps } from '../desk/webapps/register'
import { deskApi } from '../desk/deskApi'
import { app } from '../desk/registry.svelte'
import type { InstalledApp } from '../types'

vi.mock('../desk/deskApi', () => ({ deskApi: { apps: vi.fn() } }))
const apps = vi.mocked(deskApi.apps)

const installed = (name: string, sha = 'a', approved: string[] | null = ['notifications']): InstalledApp => ({
  id: `acme.${name}`,
  version: '1.0.0',
  sha256: sha,
  manifest: { publisher: 'acme', name, version: '1.0.0', api: 1, kind: 'web', title: name, glyph: 'apps', tone: 'sky', permissions: ['notifications'] },
  approved_permissions: approved,
  installed_at: '',
  approved_at: '',
})

const entry = { id: 's', url: '', token: 't' }

describe('installed apps on a desk', () => {
  beforeEach(() => apps.mockReset())

  it('keeps an unchanged app registered across reloads, and follows what changed', async () => {
    const set = new WebApps(entry)
    apps.mockResolvedValue({ apps: [installed('notes'), installed('clock')] })
    await set.reload()
    const notes = app('acme.notes')
    expect(notes).toBeDefined()

    // Nothing changed for notes: the same registration, so its windows stay.
    apps.mockResolvedValue({ apps: [installed('notes'), installed('clock', 'b')] })
    await set.reload()
    expect(app('acme.notes')).toBe(notes)
    expect(app('acme.clock')).toBeDefined()

    // Removed, or waiting for approval again: gone.
    apps.mockResolvedValue({ apps: [installed('clock', 'c', null)] })
    await set.reload()
    expect(app('acme.notes')).toBeUndefined()
    expect(app('acme.clock')).toBeUndefined()
    set.close()
  })

  it('adds nothing once the desk is gone', async () => {
    const set = new WebApps(entry)
    let answer!: (v: { apps: InstalledApp[] }) => void
    apps.mockReturnValue(new Promise((r) => (answer = r)))
    const reading = set.reload()
    set.close()
    answer({ apps: [installed('late')] })
    await reading
    expect(app('acme.late')).toBeUndefined()
  })
})
