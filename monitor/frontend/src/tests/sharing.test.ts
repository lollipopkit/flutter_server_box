import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import SharingApp from '../desk/apps/sharing/SharingApp.svelte'
import { shareNameOk, withExport, withShare, withoutExport, withoutShare } from '../desk/apps/sharing/model'
import { api, ApiError } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { SharesView, SmbShare } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    getShares: vi.fn(),
    getSystemUsers: vi.fn(),
    setSmbShares: vi.fn(),
    setNfsExports: vi.fn(),
    setSmbPassword: vi.fn(),
    installShares: vi.fn(),
    sharesJob: vi.fn(),
  },
}))

const mocked = vi.mocked(api)

const share = (name: string, managed = true, extra: Partial<SmbShare> = {}): SmbShare => ({
  name,
  path: `/srv/${name}`,
  comment: null,
  read_only: false,
  guest: false,
  users: [],
  managed,
  ...extra,
})

const view: SharesView = {
  tools: ['smbd', 'testparm', 'smbpasswd', 'exportfs'],
  smb_active: true,
  nfs_active: false,
  smb: [share('media', false, { guest: true, read_only: true }), share('backup', true, { users: ['alice'] })],
  nfs: [{ path: '/srv/media', managed: true, clients: [{ host: '192.168.1.0/24', read_only: true, squash: 'root', options: [] }] }],
  job: null,
}

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
  servers.currentId = 'local'
  mocked.getShares.mockResolvedValue(structuredClone(view))
  mocked.getSystemUsers.mockResolvedValue({
    part: 'list', available: true, reason_kind: null, reason: null, agent_account: 'sbm', uid_min: 1000, name: null, detail: null,
    users: [
      { name: 'root', uid: 0, gid: 0, comment: '', home: '/root', shell: '/bin/sh', primary_group: 'root', supplementary_groups: [], is_root: true, system: true, login_disabled: false, agent_account: false, deletable: false },
      { name: 'alice', uid: 1000, gid: 1000, comment: '', home: '/home/alice', shell: '/bin/bash', primary_group: 'alice', supplementary_groups: [], is_root: false, system: false, login_disabled: false, agent_account: false, deletable: true },
    ],
  })
})

describe('the sharing model', () => {
  it('writes only ServerBox\'s own shares back', () => {
    expect(withShare(view.smb, share('photos'), null).map((s) => s.name)).toEqual(['backup', 'photos'])
    expect(withShare(view.smb, share('backup2'), 'backup').map((s) => s.name)).toEqual(['backup2'])
    expect(withoutShare(view.smb, 'backup')).toEqual([])
    const e = withExport(view.nfs, { path: '/mnt/x', managed: true, clients: [{ host: ' * ', read_only: false, squash: 'all', options: [] }, { host: '', read_only: false, squash: 'root', options: [] }] }, null)
    expect(e.map((x) => [x.path, x.clients.map((c) => c.host)])).toEqual([['/srv/media', ['192.168.1.0/24']], ['/mnt/x', ['*']]])
    expect(withoutExport(view.nfs, '/srv/media')).toEqual([])
    expect([shareNameOk('photos'), shareNameOk('global'), shareNameOk('a b'), shareNameOk('')]).toEqual([true, false, false, false])
  })
})

describe('the Sharing app', () => {
  it('lists shares, leaves others\' alone, and adds one with sudo\'s password', async () => {
    mocked.setSmbShares.mockResolvedValue({ ...structuredClone(view), smb: [...view.smb, share('photos')] })
    render(SharingApp)
    expect(await screen.findByText('media')).toBeInTheDocument()
    expect(screen.getByText('Set up outside ServerBox')).toBeInTheDocument()
    // Only ServerBox's share can be edited.
    expect(screen.getAllByRole('button', { name: 'Edit' })).toHaveLength(1)

    await fireEvent.click(screen.getByRole('button', { name: 'Add share' }))
    await fireEvent.input(screen.getByLabelText('Name'), { target: { value: 'photos' } })
    await fireEvent.input(screen.getByLabelText(/^Folder/), { target: { value: '/srv/photos' } })
    await fireEvent.click(screen.getByRole('checkbox', { name: 'alice' }))
    await fireEvent.click(screen.getByRole('button', { name: 'Continue' }))
    await fireEvent.input(screen.getByLabelText(/sudo password/), { target: { value: 'pw' } })
    await fireEvent.click(screen.getAllByRole('button', { name: 'Save' }).at(-1)!)
    await vi.waitFor(() =>
      expect(mocked.setSmbShares).toHaveBeenCalledWith(
        [share('backup', true, { users: ['alice'] }), share('photos', true, { users: ['alice'] })],
        'pw',
      ),
    )
    expect(await screen.findByText('photos')).toBeInTheDocument()
  })

  it('says why a change was refused and keeps the dialog', async () => {
    mocked.setNfsExports.mockRejectedValue(new ApiError('notAFolder', 409, 'notAFolder', { error: 'notAFolder', path: '/srv/media' }))
    render(SharingApp)
    await fireEvent.click(await screen.findByText('NFS'))
    await fireEvent.click(await screen.findByRole('button', { name: 'Remove' }))
    await fireEvent.click(screen.getAllByRole('button', { name: 'Remove' }).at(-1)!)
    expect(await screen.findByText('/srv/media is not a folder on the server.')).toBeInTheDocument()
    expect(mocked.setNfsExports).toHaveBeenCalledWith([], '')
  })

  it('offers to install Samba where it is missing', async () => {
    mocked.getShares.mockResolvedValue({ ...structuredClone(view), tools: [], smb: [], nfs: [] })
    mocked.installShares.mockResolvedValue({ id: 1, kind: 'shares', state: 'running', error: null, lines: [], next: 0 })
    mocked.sharesJob.mockResolvedValue({ id: 1, kind: 'shares', state: 'running', error: null, lines: [], next: 0 })
    render(SharingApp)
    await fireEvent.click(await screen.findByRole('button', { name: 'Install Samba' }))
    await fireEvent.click(screen.getAllByRole('button', { name: 'Install Samba' }).at(-1)!)
    await vi.waitFor(() => expect(mocked.installShares).toHaveBeenCalledWith(false, ''))
    expect(await screen.findByText('Installing…')).toBeInTheDocument()
  })
})
