import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Services from '../desk/apps/services/ServicesApp.svelte'
import { api } from '../lib/api'
import type { ServiceActResult, ServiceView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getServices: vi.fn(), actService: vi.fn() },
}))
const getServices = vi.mocked(api.getServices)
const actService = vi.mocked(api.actService)

const unit = {
  key: 'system:nginx.service',
  name: 'nginx',
  full_name: 'nginx.service',
  type: 'service',
  scope: 'system',
  state: 'stopped',
  description: 'A high performance web server',
  actions: ['start'],
  startup: 'enabled',
}

const view = (): ServiceView =>
  ({
    part: 'list',
    available: true,
    reason_kind: null,
    reason: null,
    manager: { type: 'systemd', detected_name: 'systemd', description: 'systemd' },
    supports_user_scope: true,
    units: [unit],
    notice: null,
    detail: null,
    sampled_at_millis: null,
    log: null,
    text: null,
  }) as unknown as ServiceView

const result = (over: Partial<ServiceActResult>): ServiceActResult =>
  ({ succeeded: false, sudo_rejected: false, exit_code: 1, stdout: '', stderr: '', ...over }) as ServiceActResult

describe('Services page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getServices.mockResolvedValue(view())
  })

  it('asks for a password when root needed one, and sends it on the retry', async () => {
    render(Services)
    await fireEvent.click(await screen.findByText('nginx.service'))

    actService.mockResolvedValueOnce(result({ sudo_rejected: true, stderr: 'sudo: a password is required' }))
    await fireEvent.click(await screen.findByRole('button', { name: /start/i }))
    const password = await screen.findByLabelText('Sudo password')
    const retry = screen.getByRole('button', { name: /retry as root/i })
    expect(retry).toBeDisabled()

    actService.mockResolvedValueOnce(result({ succeeded: true, exit_code: 0 }))
    await fireEvent.input(password, { target: { value: 'hunter2' } })
    await fireEvent.click(retry)
    await waitFor(() =>
      expect(actService).toHaveBeenLastCalledWith({ key: 'system:nginx.service', action: 'start', password: 'hunter2' }),
    )
  })

  it('narrows the list to the group the sidebar picked', async () => {
    getServices.mockResolvedValue({
      ...view(),
      units: [
        unit,
        { ...unit, key: 'system:ssh.service', name: 'ssh', full_name: 'ssh.service', state: 'failed', actions: [] },
      ],
    } as unknown as ServiceView)
    render(Services)
    expect(await screen.findByText('nginx.service')).toBeInTheDocument()

    await fireEvent.click(screen.getAllByRole('button', { name: /^failed/i })[0])
    expect(screen.queryByText('nginx.service')).not.toBeInTheDocument()
    expect(screen.getByText('ssh.service')).toBeInTheDocument()
  })
})
