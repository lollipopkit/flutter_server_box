import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Snippets from '../desk/apps/snippets/SnippetsApp.svelte'
import { api, ApiError } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import { snippetRun } from '../lib/snippetRun.svelte'
import type { Snippet } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getSnippets: vi.fn(), updateSnippets: vi.fn(), planSnippet: vi.fn() },
}))

// Run opens the terminal app; the window is what a rendered app alone has no
// context for, so the handle is a spy here.
const { open } = vi.hoisted(() => ({ open: vi.fn() }))
vi.mock('../desk/sys/window.svelte', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../desk/sys/window.svelte')>()),
  useWindow: () => ({ open }),
}))
const getSnippets = vi.mocked(api.getSnippets)
const updateSnippets = vi.mocked(api.updateSnippets)
const planSnippet = vi.mocked(api.planSnippet)

const disk: Snippet = { id: 'a', name: 'Disk', script: 'df -h', note: '', tags: ['ops'] }
const login: Snippet = { id: 'b', name: 'Login', script: 'ssh ${user}@${host}', note: '', tags: [] }

describe('Snippets page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    snippetRun.waiting = null
    open.mockReturnValue('term-1')
    getSnippets.mockResolvedValue({ snippets: [disk, login] })
  })

  it('runs a snippet by handing the agent’s steps to the terminal', async () => {
    const steps = [{ type: 'text' as const, text: 'df -h' }]
    planSnippet.mockResolvedValue({ steps })
    render(Snippets)

    await fireEvent.click(await screen.findByRole('button', { name: /Disk/ }))
    await fireEvent.click(screen.getByRole('button', { name: /^run$/i }))

    await waitFor(() => expect(open).toHaveBeenCalledWith('terminal', { newWindow: true }))
    expect(planSnippet).toHaveBeenCalledWith('df -h')
    // For the window that Run opened, and no other terminal.
    expect(snippetRun.waiting).toEqual({ name: 'Disk', steps, window: 'term-1' })
    expect(snippetRun.for('another')).toBeNull()
  })

  it('queues nothing when no terminal window can be opened', async () => {
    planSnippet.mockResolvedValue({ steps: [{ type: 'text' as const, text: 'df -h' }] })
    open.mockReturnValue(null)
    render(Snippets)

    await fireEvent.click(await screen.findByRole('button', { name: /Disk/ }))
    await fireEvent.click(screen.getByRole('button', { name: /^run$/i }))

    expect(await screen.findByText(/close one to run a snippet/)).toBeInTheDocument()
    expect(snippetRun.waiting).toBeNull()
  })

  it('drops a plan that answers after the server was switched', async () => {
    let answer!: (plan: { steps: [] }) => void
    planSnippet.mockReturnValue(new Promise((resolve) => (answer = resolve)))
    const current = vi.spyOn(servers, 'currentId', 'get').mockReturnValue('a')
    render(Snippets)

    await fireEvent.click(await screen.findByRole('button', { name: /Disk/ }))
    await fireEvent.click(screen.getByRole('button', { name: /^run$/i }))
    current.mockReturnValue('b')
    answer({ steps: [] })

    await waitFor(() => expect(screen.getByRole('button', { name: /^run$/i })).toBeEnabled())
    expect(snippetRun.waiting).toBeNull()
    expect(open).not.toHaveBeenCalled()
    current.mockRestore()
  })

  it('says which value the panel cannot fill in, and queues nothing', async () => {
    planSnippet.mockRejectedValue(
      new ApiError('unanswerable', 400, undefined, { error: 'unanswerable', key: 'user' }),
    )
    render(Snippets)

    await fireEvent.click(await screen.findByRole('button', { name: /Login/ }))
    await fireEvent.click(screen.getByRole('button', { name: /^run$/i }))

    expect(await screen.findByText(/uses \$\{user\}, which the panel/)).toBeInTheDocument()
    expect(snippetRun.waiting).toBeNull()
  })

  it('removes a snippet by sending the library without it', async () => {
    updateSnippets.mockResolvedValue({ snippets: [login] })
    render(Snippets)

    await fireEvent.click(await screen.findByRole('button', { name: /Disk/ }))
    await fireEvent.click(screen.getByRole('button', { name: /delete snippet/i }))
    const confirm = screen.getAllByRole('button', { name: /delete snippet/i })
    await fireEvent.click(confirm[confirm.length - 1])

    await waitFor(() => expect(updateSnippets).toHaveBeenCalledWith([login]))
  })

  it('phrases a refused save in the viewer’s language', async () => {
    updateSnippets.mockRejectedValue(
      new ApiError('duplicateName', 400, undefined, { error: 'duplicateName', index: 1 }),
    )
    render(Snippets)

    await fireEvent.click(await screen.findByRole('button', { name: /Disk/ }))
    await fireEvent.click(screen.getByRole('button', { name: /delete snippet/i }))
    const confirm = screen.getAllByRole('button', { name: /delete snippet/i })
    await fireEvent.click(confirm[confirm.length - 1])

    expect(await screen.findByText('Two snippets have the same name.')).toBeInTheDocument()
  })
})
