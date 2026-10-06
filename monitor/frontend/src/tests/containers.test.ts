import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Containers from '../pages/Containers.svelte'
import { ApiError, api } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import type { Capabilities, ContainerImage, ContainerRow, ContainerView } from '../types'

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
    unused_tagged: null,
    usage: null,
    logs: null,
  }) as unknown as ContainerView

const IMAGE: ContainerImage = {
  repository: 'alpine',
  tag: 'latest',
  id: 'sha256:abc',
  digest: null,
  size: '8MB',
  containers: 0,
  created_at: null,
  created: null,
  dangling: false,
}

/// A running container, which is the only state a shell is offered in.
const RUNNING: ContainerRow = {
  id: 'abc',
  name: 'web',
  image: 'nginx:alpine',
  project: null,
  working_dir: null,
  ports: null,
  raw_status: 'Up 2 hours',
  status: 'running',
  stats: null,
  actions: ['stop', 'restart', 'remove', 'logs', 'terminal'],
}

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
            images: [IMAGE],
          } as unknown as ContainerView)
        : view(),
    )
    // What the agent answers to any change: the container listing only.
    actContainer.mockResolvedValue({ ...view(), exit_code: 0, output: '' } as never)
  })

  it('reads the images again when a change answers the other listing', async () => {
    render(Containers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^images$/i }))
    expect(await screen.findByText(/alpine/)).toBeInTheDocument()

    // `system prune` answers the container listing, so this tab is stale and
    // has to be read again rather than replaced with a listing it does not show.
    await fireEvent.click(screen.getByRole('button', { name: /prune system/i }))
    const buttons = await screen.findAllByRole('button', { name: /prune system/i })
    await fireEvent.click(buttons.at(-1)!)

    await waitFor(() =>
      expect(actContainer).toHaveBeenCalledWith({
        action: 'prune_system',
        all_unused_images: false,
        include_volumes: false,
      }),
    )
    await waitFor(() => expect(getContainers.mock.calls.filter(([part]) => part === 'images').length).toBe(2))
    expect(await screen.findByText(/alpine/)).toBeInTheDocument()
  })

  it('asks before removing an image, and sends its id', async () => {
    render(Containers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^images$/i }))
    await screen.findByText(/alpine/)

    await fireEvent.click(screen.getByRole('button', { name: /^remove$/i }))
    expect(actContainer).not.toHaveBeenCalled()
    expect(await screen.findByText(/remove image alpine:latest/i)).toBeInTheDocument()

    const buttons = await screen.findAllByRole('button', { name: /^remove$/i })
    await fireEvent.click(buttons.at(-1)!)
    await waitFor(() =>
      expect(actContainer).toHaveBeenCalledWith({ action: 'remove_image', id: 'sha256:abc' }),
    )
  })

  it('sends the prune scope from the checkbox', async () => {
    render(Containers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^images$/i }))
    await screen.findByText(/alpine/)

    await fireEvent.click(screen.getByRole('button', { name: /prune images/i }))
    await fireEvent.click(screen.getByRole('checkbox'))
    const buttons = await screen.findAllByRole('button', { name: /prune images/i })
    await fireEvent.click(buttons.at(-1)!)

    await waitFor(() =>
      expect(actContainer).toHaveBeenCalledWith({ action: 'prune_images', all_unused: true }),
    )
  })

  it('shows a refusal code translated', async () => {
    actContainer.mockRejectedValueOnce(
      new ApiError('invalid_input', 400, undefined, {
        error: 'invalid_input',
        issue: 'invalid_reference',
      }),
    )
    render(Containers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^images$/i }))
    await screen.findByText(/alpine/)

    await fireEvent.click(screen.getByRole('button', { name: /^remove$/i }))
    const buttons = await screen.findAllByRole('button', { name: /^remove$/i })
    await fireEvent.click(buttons.at(-1)!)

    expect(await screen.findByText(/image reference contains a character/i)).toBeInTheDocument()
  })

  it('drops an answer that arrives after the server changed', async () => {
    servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
    servers.currentId = 'local'
    let answer: (v: Awaited<ReturnType<typeof api.actContainer>>) => void = () => {}
    actContainer.mockReturnValueOnce(new Promise((resolve) => (answer = resolve)))

    render(Containers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^images$/i }))
    await screen.findByText(/alpine/)
    await fireEvent.click(screen.getByRole('button', { name: /prune images/i }))
    const buttons = await screen.findAllByRole('button', { name: /prune images/i })
    await fireEvent.click(buttons.at(-1)!)
    await waitFor(() => expect(actContainer).toHaveBeenCalled())

    // A pull may take minutes; the sidebar can move on in between.
    servers.add('https://another.example')
    answer({
      ...view(),
      part: 'images',
      images: [{ ...IMAGE, repository: 'redis-marker' }],
      exit_code: 0,
      output: '',
    } as never)
    await new Promise((r) => setTimeout(r, 50))

    expect(screen.queryByText(/redis-marker/)).toBeNull()
  })
})

describe('Containers page shell action', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
    servers.currentId = 'local'
    getContainers.mockResolvedValue({ ...view(), containers: [RUNNING] } as unknown as ContainerView)
    actContainer.mockResolvedValue({ ...view(), containers: [RUNNING], exit_code: 0, output: '' } as never)
  })

  it('is hidden when the agent does not list container_exec', async () => {
    capabilitiesStore.byServer['local'] = {
      features: ['containers'],
      grants: { shell: { ok: true } },
    } as unknown as Capabilities
    render(Containers, { onback: () => {} })
    await screen.findByText('web')
    expect(screen.queryByRole('button', { name: /open shell/i })).toBeNull()
  })

  it('is offered for a running container when the agent and the account allow it', async () => {
    capabilitiesStore.byServer['local'] = {
      features: ['containers', 'container_exec'],
      grants: { shell: { ok: true } },
    } as unknown as Capabilities
    render(Containers, { onback: () => {} })
    await screen.findByText('web')
    expect(await screen.findByRole('button', { name: /open shell/i })).toBeInTheDocument()
  })
})
