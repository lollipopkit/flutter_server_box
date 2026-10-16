import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import PowerModal from '../components/PowerModal.svelte'
import { api, ApiError } from '../lib/api'
import { machineAccess } from '../lib/access'
import type { Capabilities, PowerResult } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { power: vi.fn() },
}))
const mockedPower = vi.mocked(api.power)

const result = (over: Partial<PowerResult>): PowerResult => ({
  exit_code: 0,
  stdout: '',
  stderr: '',
  sudo_rejected: false,
  truncated: false,
  timed_out: false,
  ...over,
})

async function pickAndRun(action: RegExp, password = '') {
  render(PowerModal, { open: true, onclose: () => {} })
  const buttons = screen.getAllByRole('button', { name: action })
  await fireEvent.click(buttons[0])
  if (password) await fireEvent.input(screen.getByLabelText(/Sudo password/), { target: { value: password } })
  // The second button with the action's name is the one that runs it.
  await fireEvent.click(screen.getAllByRole('button', { name: action }).at(-1)!)
}

describe('PowerModal', () => {
  beforeEach(() => vi.clearAllMocks())

  it('sends the password as its own field', async () => {
    mockedPower.mockResolvedValue(result({}))
    await pickAndRun(/reboot/i, 'hunter2')
    await waitFor(() => expect(mockedPower).toHaveBeenCalledWith('reboot', 'hunter2'))
    expect(await screen.findByText(/Sent: Reboot/)).toBeInTheDocument()
  })

  it('says a refused password is refused, and stays open for another', async () => {
    mockedPower.mockResolvedValue(result({ exit_code: 1, sudo_rejected: true, stderr: 'Sorry, try again.' }))
    await pickAndRun(/shut down/i)
    expect(await screen.findByRole('alert')).toHaveTextContent('refused that password')
    expect(screen.getByLabelText(/Sudo password/)).toBeInTheDocument()
  })

  it('reads a shutdown the agent did not live to answer as sent', async () => {
    mockedPower.mockRejectedValue(new ApiError('Failed to reach the machine'))
    await pickAndRun(/shut down/i)
    expect(await screen.findByText(/Sent: Shut down/)).toBeInTheDocument()
  })

  it('does not read a refusal from the agent that way', async () => {
    mockedPower.mockRejectedValue(new ApiError('insecure_transport', 403, 'forbidden'))
    await pickAndRun(/reboot/i)
    expect(await screen.findByRole('alert')).toHaveTextContent('insecure_transport')
  })
})

describe('machineAccess', () => {
  const caps = (features: string[] | undefined, ok: boolean) =>
    ({ features, access: { ok } }) as unknown as Capabilities

  it('needs the agent to serve the page and the account to act over this link', () => {
    expect(machineAccess(caps(['power'], true), 'power')).toBe(true)
    expect(machineAccess(caps(['power'], false), 'power')).toBe(false)
    // An agent before the page answers neither `features` nor a page name.
    expect(machineAccess(caps(undefined, true), 'power')).toBe(false)
    expect(machineAccess(caps([], true), 'power')).toBe(false)
    expect(machineAccess(undefined, 'power')).toBe(false)
  })
})
