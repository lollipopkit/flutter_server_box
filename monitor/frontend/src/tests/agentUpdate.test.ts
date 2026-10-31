import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import AgentUpdate from '../desk/apps/settings/AgentUpdate.svelte'
import { api, ApiError } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import { Desk } from '../desk/deskState.svelte'
import type { AgentUpdate as Update, Capabilities } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getUpdate: vi.fn(), startUpdate: vi.fn() },
}))

const getUpdate = vi.mocked(api.getUpdate)
const startUpdate = vi.mocked(api.startUpdate)

const behind = (over: Partial<Update> = {}): Update => ({
  version: '0.2.0',
  latest: '0.3.0',
  checked_at: '2026-10-14T06:00:00Z',
  outdated: true,
  install: 'script',
  command: 'curl -fsSL https://example/install.sh | sh -s -- upgrade',
  ...over,
})

function caps(ok: boolean): Capabilities {
  return { access: { ok }, features: ['update'] } as unknown as Capabilities
}

describe("the agent's update in Settings", () => {
  beforeEach(() => {
    vi.resetAllMocks()
    servers.list = [{ id: 'local', url: '', token: 't' }]
    servers.currentId = 'local'
    capabilitiesStore.byServer = { local: caps(true) }
  })

  it('starts the update on the agent and follows it across the restart', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    try {
      // What the agent answers now: the test moves it on.
      let now: () => Promise<Update> = async () => behind()
      getUpdate.mockImplementation(() => now())
      const running = { state: 'running' as const, started_at: '2026-10-14T06:00:00Z', lines: ['Downloading the package'] }
      startUpdate.mockImplementation(async () => {
        now = async () => behind({ run: running })
      })
      render(AgentUpdate)
      await fireEvent.click(await screen.findByRole('button', { name: 'Update now' }))
      expect(startUpdate).toHaveBeenCalledWith(undefined)
      expect(await screen.findByText('Updating…')).toBeInTheDocument()
      expect(await screen.findByText('Downloading the package')).toBeInTheDocument()
      now = async () => {
        throw new ApiError('Failed to read the update')
      }
      await vi.advanceTimersByTimeAsync(2000)
      expect(await screen.findByText(/The agent is restarting/)).toBeInTheDocument()
      // What it said before stays while it does not answer.
      expect(screen.getByText('Downloading the package')).toBeInTheDocument()
      now = async () => behind({ version: '0.3.0', outdated: false, run: { ...running, state: 'done', exit: 0, lines: ['Upgrade success'] } })
      await vi.advanceTimersByTimeAsync(2000)
      expect(await screen.findByText('Updated: the agent runs 0.3.0.')).toBeInTheDocument()
      expect(screen.getByText('Upgrade success')).toBeInTheDocument()
    } finally {
      vi.useRealTimers()
    }
  })

  it("asks sudo's password where the agent needs it, and says when it is refused", async () => {
    getUpdate.mockResolvedValue(behind({ needs_password: true }))
    startUpdate.mockRejectedValue(new ApiError('forbidden', 403, 'sudo_password'))
    render(AgentUpdate)
    const update = await screen.findByRole('button', { name: 'Update now' })
    expect(update).toBeDisabled()
    const field = document.querySelector('input[type="password"]') as HTMLInputElement
    await fireEvent.input(field, { target: { value: 'pw' } })
    await fireEvent.click(update)
    expect(startUpdate).toHaveBeenCalledWith('pw')
    expect(await screen.findByText('sudo did not accept this password.')).toBeInTheDocument()
  })

  it('asks the agent to read its releases again', async () => {
    getUpdate.mockResolvedValue(behind({ latest: '0.2.0', outdated: false }))
    render(AgentUpdate)
    expect(await screen.findByText('Up to date')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: 'Check now' }))
    expect(getUpdate).toHaveBeenLastCalledWith(true)
  })

  it('shows the command where this link may not act, and no command for a container', async () => {
    capabilitiesStore.byServer = { local: caps(false) }
    getUpdate.mockResolvedValue(behind())
    const { unmount } = render(AgentUpdate)
    expect(await screen.findByText(behind().command!)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Update now' })).toBeNull()
    unmount()

    getUpdate.mockResolvedValue(behind({ install: 'container', command: undefined }))
    render(AgentUpdate)
    expect(await screen.findByText(/pull the new image/)).toBeInTheDocument()
  })

  it("its notification opens Settings at the server's section", () => {
    const desk = new Desk({ id: 'local', url: '', token: 't' })
    const n = { id: 1, created_at: '', level: 'info' as const, source: 'agent', subject: '', body: '', read: false }
    expect(desk.noticeSource(n)).toMatchObject({ appId: 'serverbox.settings', appState: { section: 'server' } })
  })
})

describe('who a terminal types for', () => {
  it('is Snippets, by its app id', async () => {
    const { typesFor } = await import('../lib/snippetIntent')
    expect(typesFor('serverbox.snippets')).toBe(true)
    expect(typesFor('serverbox.settings')).toBe(false)
    expect(typesFor('snippets')).toBe(false)
    expect(typesFor('serverbox.files')).toBe(false)
    expect(typesFor(undefined)).toBe(false)
  })
})
