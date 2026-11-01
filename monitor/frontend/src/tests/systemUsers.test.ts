import { get } from 'svelte/store'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import { LL } from '../i18n/i18n-svelte'
import SystemUsers from '../pages/SystemUsers.svelte'
import { api } from '../lib/api'
import type { GroupRow, UserRow, UserView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getSystemUsers: vi.fn(), actSystemUser: vi.fn() },
}))
const ll = get(LL)
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
  gid_min: 1000,
  users: [
    row('root', 0, { is_root: true, deletable: false, system: true }),
    row('agent', 1000, { agent_account: true, deletable: false }),
    row('deploy', 1001),
  ],
  groups: [
    {
      name: 'ops',
      gid: 1001,
      members: ['deploy'],
      is_root: false,
      system: false,
      primary_members: [],
      local: true,
      deletable: true,
    } satisfies GroupRow,
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
    render(SystemUsers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^root/ }))
    expect(screen.getByRole('button', { name: ll.userDelete() })).toBeDisabled()
  })

  it('asks before deleting, and retries as root with the sudo password', async () => {
    actSystemUser
      .mockResolvedValueOnce({ ...ok, succeeded: false, sudo_rejected: true })
      .mockResolvedValueOnce(ok)
    render(SystemUsers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^deploy/ }))
    await fireEvent.click(screen.getByRole('button', { name: ll.userDelete() }))
    expect(actSystemUser).not.toHaveBeenCalled()
    expect(screen.getByText(ll.userDeleteConfirm({ name: 'deploy' }))).toBeInTheDocument()

    await fireEvent.click(screen.getByLabelText(ll.userRemoveHome()))
    await fireEvent.click(screen.getAllByRole('button', { name: ll.userDelete() }).at(-1)!)
    await waitFor(() =>
      expect(actSystemUser).toHaveBeenCalledWith({ action: 'delete', name: 'deploy', remove_home: true }),
    )

    // Refused for want of root: the dialog asks for the password and sends it
    // as its own field on the second attempt.
    await fireEvent.input(await screen.findByLabelText(ll.powerPassword()), { target: { value: 'hunter2' } })
    await fireEvent.click(screen.getAllByRole('button', { name: ll.userDelete() }).at(-1)!)
    await waitFor(() =>
      expect(actSystemUser).toHaveBeenLastCalledWith({
        action: 'delete',
        name: 'deploy',
        remove_home: true,
        password: 'hunter2',
      }),
    )
    expect(await screen.findByText(ll.userDoneDeleted({ name: 'deploy' }))).toBeInTheDocument()
  })

  it('edits a group the same way as an account', async () => {
    actSystemUser.mockResolvedValue(ok)
    render(SystemUsers, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: ll.groupTab() }))
    await fireEvent.click(await screen.findByRole('button', { name: /^ops/ }))
    await fireEvent.click(screen.getByRole('button', { name: ll.groupEdit() }))
    await fireEvent.click(screen.getByRole('button', { name: ll.save() }))
    await waitFor(() =>
      expect(actSystemUser).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'edit', kind: 'group', name: 'ops' }),
      ),
    )
  })

  it('says why a machine cannot be listed', async () => {
    getSystemUsers.mockResolvedValue({
      ...view(),
      available: false,
      reason_kind: 'unsupported_platform',
      agent_account: null,
      uid_min: null,
      gid_min: null,
      users: [],
      groups: [],
    })
    render(SystemUsers, { onback: () => {} })
    expect(await screen.findByText(ll.userUnsupportedPlatform())).toBeInTheDocument()
  })
})
