import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Desktop from '../desk/apps/remote_desktop/RemoteDesktopApp.svelte'
import { api, ApiError } from '../lib/api'
import type { Desktop as Route } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getDesktops: vi.fn(), updateDesktops: vi.fn(), issueWsTicket: vi.fn() },
}))
const getDesktops = vi.mocked(api.getDesktops)
const updateDesktops = vi.mocked(api.updateDesktops)

const office: Route = {
  id: 'd1',
  name: 'office',
  protocol: 'vnc',
  host: '10.0.0.7',
  port: 5900,
  username: null,
  domain: null,
  view_only: true,
  shared: true,
}
const protocols = [{ id: 'vnc' as const, default_port: 5900 }]

describe('Desktop page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getDesktops.mockResolvedValue({ desktops: [office], protocols })
  })

  it('asks for the password only when a session is opened', async () => {
    render(Desktop)
    await fireEvent.click(await screen.findByRole('button', { name: /office/ }))
    await fireEvent.click(screen.getByRole('button', { name: /open session/i }))
    expect(screen.getByLabelText(/password/i)).toHaveAttribute('type', 'password')
  })

  it('removes a route by sending the set without it', async () => {
    updateDesktops.mockResolvedValue({ desktops: [], protocols })
    render(Desktop)
    await fireEvent.click(await screen.findByRole('button', { name: /office/ }))
    await fireEvent.click(screen.getByRole('button', { name: /delete desktop/i }))
    const confirm = screen.getAllByRole('button', { name: /delete desktop/i })
    await fireEvent.click(confirm[confirm.length - 1])
    await waitFor(() => expect(updateDesktops).toHaveBeenCalledWith([]))
  })

  it('phrases a refused save in the viewer’s language', async () => {
    updateDesktops.mockRejectedValue(
      new ApiError('invalidHost', 400, undefined, { error: 'invalidHost', index: 0 }),
    )
    render(Desktop)
    await fireEvent.click(await screen.findByRole('button', { name: /office/ }))
    await fireEvent.click(screen.getByRole('button', { name: /delete desktop/i }))
    const confirm = screen.getAllByRole('button', { name: /delete desktop/i })
    await fireEvent.click(confirm[confirm.length - 1])
    expect(await screen.findByText(/one host name or address/)).toBeInTheDocument()
  })
})
