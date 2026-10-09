import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import SystemUsers from '../desk/apps/system_users/SystemUsersApp.svelte'
import { api } from '../lib/api'
import type { UserRow, UserView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getSystemUsers: vi.fn(), actSystemUser: vi.fn() },
}))
const getSystemUsers = vi.mocked(api.getSystemUsers)
const actSystemUser = vi.mocked(api.actSystemUser)

const row = (name: string, uid: number, extra: Partial<UserRow> = {}): UserRow => ({
  name,
  uid,
  gid: uid,
  comment: '',
  home: `/home/${name}`,
  shell: '/bin/bash',
  primary_group: name,
  supplementary_groups: [],
  is_root: false,
  system: false,
  login_disabled: false,
  agent_account: false,
  deletable: true,
  ...extra,
})

const view = (): UserView => ({
  part: 'list',
  available: true,
  reason_kind: null,
  reason: null,
  agent_account: 'agent',
  uid_min: 1000,
  users: [
    row('root', 0, { is_root: true, deletable: false, system: true }),
    row('agent', 1000, { agent_account: true, deletable: false }),
    row('deploy', 1001),
  ],
  name: null,
  detail: null,
})

const ok = { succeeded: true, sudo_rejected: false, exit_code: 0, stdout: '', stderr: '' }

describe('System users page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getSystemUsers.mockResolvedValue(view())
  })

  it('offers no removal of root or of the agent own account', async () => {
    render(SystemUsers)
    await fireEvent.click(await screen.findByRole('button', { name: /^root/ }))
    expect(screen.getByRole('button', { name: /delete user/i })).toBeDisabled()
  })

  it('asks before deleting, and retries as root with the sudo password', async () => {
    actSystemUser
      .mockResolvedValueOnce({ ...ok, succeeded: false, sudo_rejected: true })
      .mockResolvedValueOnce(ok)
    render(SystemUsers)
    await fireEvent.click(await screen.findByRole('button', { name: /^deploy/ }))
    await fireEvent.click(screen.getByRole('button', { name: /delete user/i }))
    expect(actSystemUser).not.toHaveBeenCalled()
    expect(screen.getByText(/delete deploy\?/i)).toBeInTheDocument()

    await fireEvent.click(screen.getByLabelText(/remove the home directory/i))
    await fireEvent.click(screen.getAllByRole('button', { name: /delete user/i }).at(-1)!)
    await waitFor(() =>
      expect(actSystemUser).toHaveBeenCalledWith({ action: 'delete', name: 'deploy', remove_home: true }),
    )

    // Refused for want of root: the dialog asks for the password and sends it
    // as its own field on the second attempt.
    await fireEvent.input(await screen.findByLabelText(/sudo password/i), { target: { value: 'hunter2' } })
    await fireEvent.click(screen.getAllByRole('button', { name: /delete user/i }).at(-1)!)
    await waitFor(() =>
      expect(actSystemUser).toHaveBeenLastCalledWith({
        action: 'delete',
        name: 'deploy',
        remove_home: true,
        password: 'hunter2',
      }),
    )
    expect(await screen.findByText('Removed deploy.')).toBeInTheDocument()
  })

  it('says why a machine cannot be listed', async () => {
    getSystemUsers.mockResolvedValue({
      ...view(),
      available: false,
      reason_kind: 'unsupported_platform',
      agent_account: null,
      uid_min: null,
      users: [],
    })
    render(SystemUsers)
    expect(await screen.findByText(/linux/i)).toBeInTheDocument()
  })
})
