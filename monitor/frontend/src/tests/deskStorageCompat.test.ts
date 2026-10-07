import { beforeEach, describe, expect, it, vi } from 'vitest'

const { putPreferences } = vi.hoisted(() => ({ putPreferences: vi.fn() }))
vi.mock('../desk/deskApi', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../desk/deskApi')>()),
  deskApi: { putPreferences },
}))

import { AgentStorage } from '../desk/storage'
import type { DeskPreferences } from '../desk/deskApi'

const entry = { id: 'a', url: 'https://agent', token: 't', username: 'admin' }
const prefs: DeskPreferences = { accent: null, wallpaper: 'preset:bloom', wallpaper_fit: 'cover', dock: [], icons: [], background: false, background_denied: ['status'] }

describe('desk preferences on an older agent', () => {
  beforeEach(() => putPreferences.mockReset())

  it('sends background where the agent keeps it', async () => {
    await new AgentStorage(entry, true, true).savePreferences(prefs)
    expect(putPreferences.mock.calls[0][1]).toHaveProperty('background', false)
  })

  it('leaves it out where the agent would refuse it', async () => {
    await new AgentStorage(entry, false, true).savePreferences(prefs)
    expect(putPreferences.mock.calls[0][1]).not.toHaveProperty('background')
    expect(putPreferences.mock.calls[0][1]).not.toHaveProperty('background_denied')
  })
})
