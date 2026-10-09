import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import PushChannels from '../desk/apps/settings/PushChannels.svelte'
import { api } from '../lib/api'
import { servers } from '../lib/servers.svelte'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getPush: vi.fn(), updatePush: vi.fn(), testPush: vi.fn() },
}))

const mocked = vi.mocked(api)

const listed = {
  pushes: [
    {
      name: 'phone',
      push_type: 'bark',
      config: { key: null, server: 'https://api.day.app' },
      editable: true,
    },
  ],
  push_rate: null,
  push_types: ['webhook', 'bark', 'smtp'],
  applies_on_restart: true,
}

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
  servers.currentId = 'local'
  mocked.getPush.mockResolvedValue(structuredClone(listed))
  mocked.updatePush.mockResolvedValue(structuredClone(listed))
})

describe('push channels', () => {
  it("offers the type's settings a channel does not have yet", async () => {
    render(PushChannels)
    expect(await screen.findByLabelText('subtitle')).toHaveValue('')
    expect(screen.getByLabelText('cipher_key')).toBeInTheDocument()
  })

  it('saves an offered setting only once it is filled in', async () => {
    render(PushChannels)
    await screen.findByLabelText('subtitle')
    await fireEvent.click(screen.getByRole('button', { name: /save/i }))
    await waitFor(() => expect(mocked.updatePush).toHaveBeenCalledTimes(1))
    // Nothing offered and left alone reaches the agent, the off switches included.
    expect(mocked.updatePush.mock.calls[0][0].pushes[0].config).toEqual({
      key: null,
      server: 'https://api.day.app',
    })

    await fireEvent.input(screen.getByLabelText('subtitle'), { target: { value: 'on {{name}}' } })
    await fireEvent.click(screen.getByRole('button', { name: /save/i }))
    await waitFor(() => expect(mocked.updatePush).toHaveBeenCalledTimes(2))
    expect(mocked.updatePush.mock.calls[1][0].pushes[0].config).toMatchObject({ subtitle: 'on {{name}}' })
  })
})
