import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Containers from '../pages/Containers.svelte'
import { api } from '../lib/api'
import type { ContainerView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getContainers: vi.fn(), actContainer: vi.fn() },
}))
const getContainers = vi.mocked(api.getContainers)
const actContainer = vi.mocked(api.actContainer)

const view = (): ContainerView =>
  ({
    part: 'containers',
    available: true,
    reason_kind: null,
    reason: null,
    runtime: { kind: 'docker', version: '27.0' },
    containers: [],
    images: [],
    usage: null,
    logs: null,
  }) as unknown as ContainerView

describe('Containers page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getContainers.mockResolvedValue(view())
    actContainer.mockResolvedValue({ ...view(), exit_code: 0, output: '' } as never)
  })

  it('asks before pruning volumes, and prunes only on the answer', async () => {
    render(Containers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /remove unused volumes/i }))
    expect(actContainer).not.toHaveBeenCalled()
    expect(await screen.findByText(/cannot be recovered/i)).toBeInTheDocument()

    await fireEvent.click(screen.getByRole('button', { name: /cancel/i }))
    expect(actContainer).not.toHaveBeenCalled()

    await fireEvent.click(screen.getByRole('button', { name: /remove unused volumes/i }))
    const buttons = await screen.findAllByRole('button', { name: /remove unused volumes/i })
    await fireEvent.click(buttons.at(-1)!)
    await waitFor(() => expect(actContainer).toHaveBeenCalledWith({ action: 'prune_volumes' }))
  })
})

describe('Containers page on the images tab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getContainers.mockImplementation(async (part) =>
      part === 'images'
        ? ({
            ...view(),
            part: 'images',
            images: [{ id: 'sha256:abc', repository: 'alpine', tag: 'latest', size: '8MB', containers: 0, created_at: null }],
          } as unknown as ContainerView)
        : view(),
    )
    // What the agent answers to any change: the container listing only.
    actContainer.mockResolvedValue({ ...view(), exit_code: 0, output: '' } as never)
  })

  it('keeps the images after a prune, reading the tab again', async () => {
    render(Containers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^images$/i }))
    expect(await screen.findByText(/alpine/)).toBeInTheDocument()

    await fireEvent.click(screen.getByRole('button', { name: /remove stopped containers/i }))
    const buttons = await screen.findAllByRole('button', { name: /remove stopped containers/i })
    await fireEvent.click(buttons.at(-1)!)

    await waitFor(() => expect(actContainer).toHaveBeenCalledWith({ action: 'prune_containers' }))
    await waitFor(() => expect(getContainers.mock.calls.filter(([part]) => part === 'images').length).toBe(2))
    expect(await screen.findByText(/alpine/)).toBeInTheDocument()
  })
})
