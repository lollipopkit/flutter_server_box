import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Snippets from '../pages/Snippets.svelte'
import { api, ApiError } from '../lib/api'
import { layout } from '../lib/layout.svelte'
import { snippetRun } from '../lib/snippetRun.svelte'
import type { Snippet } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getSnippets: vi.fn(), updateSnippets: vi.fn(), planSnippet: vi.fn() },
}))
const getSnippets = vi.mocked(api.getSnippets)
const updateSnippets = vi.mocked(api.updateSnippets)
const planSnippet = vi.mocked(api.planSnippet)

const disk: Snippet = { id: 'a', name: 'Disk', script: 'df -h', note: '', tags: ['ops'] }
const login: Snippet = { id: 'b', name: 'Login', script: 'ssh ${user}@${host}', note: '', tags: [] }

describe('Snippets page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    snippetRun.clear()
    getSnippets.mockResolvedValue({ snippets: [disk, login] })
  })

  it('runs a snippet by handing the agent’s steps to the terminal', async () => {
    const steps = [{ type: 'text' as const, text: 'df -h' }]
    planSnippet.mockResolvedValue({ steps })
    const navigate = vi.spyOn(layout, 'navigate')
    render(Snippets, { onback: () => {} })

    await fireEvent.click(await screen.findByRole('button', { name: /Disk/ }))
    await fireEvent.click(screen.getByRole('button', { name: /^run$/i }))

    await waitFor(() => expect(navigate).toHaveBeenCalledWith('terminal'))
    expect(planSnippet).toHaveBeenCalledWith('df -h')
    expect(snippetRun.waiting).toEqual({ name: 'Disk', steps })
  })

  it('says which value the panel cannot fill in, and queues nothing', async () => {
    planSnippet.mockRejectedValue(
      new ApiError('unanswerable', 400, undefined, { error: 'unanswerable', key: 'user' }),
    )
    render(Snippets, { onback: () => {} })

    await fireEvent.click(await screen.findByRole('button', { name: /Login/ }))
    await fireEvent.click(screen.getByRole('button', { name: /^run$/i }))

    expect(await screen.findByText(/uses \$\{user\}, which the panel/)).toBeInTheDocument()
    expect(snippetRun.waiting).toBeNull()
  })

  it('removes a snippet by sending the library without it', async () => {
    updateSnippets.mockResolvedValue({ snippets: [login] })
    render(Snippets, { onback: () => {} })

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
    render(Snippets, { onback: () => {} })

    await fireEvent.click(await screen.findByRole('button', { name: /Disk/ }))
    await fireEvent.click(screen.getByRole('button', { name: /delete snippet/i }))
    const confirm = screen.getAllByRole('button', { name: /delete snippet/i })
    await fireEvent.click(confirm[confirm.length - 1])

    expect(await screen.findByText('Two snippets have the same name.')).toBeInTheDocument()
  })
})
