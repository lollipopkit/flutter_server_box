import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import StorageApp from '../desk/apps/storage/StorageApp.svelte'
import { disksOf, freeDevices, minimum, mountable, nextMd, overlaps, volumesOf } from '../desk/apps/storage/model'
import { api } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { BlockDevice, StorageView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getStorage: vi.fn(), storageAct: vi.fn(), storageJob: vi.fn() },
}))

const mocked = vi.mocked(api)

const dev = (path: string, kind: string, extra: Partial<BlockDevice> = {}): BlockDevice => ({
  name: path.replace('/dev/', ''),
  path,
  kind,
  size: 4_000_000_000_000,
  model: null,
  serial: null,
  rotational: true,
  transport: 'sata',
  removable: false,
  read_only: false,
  fstype: null,
  label: null,
  uuid: null,
  mountpoints: [],
  available: null,
  used: null,
  children: [],
  ...extra,
})

const view: StorageView = {
  disks: [
    dev('/dev/sda', 'disk', { model: 'Samsung SSD', rotational: false, children: [dev('/dev/sda1', 'part', { fstype: 'ext4', mountpoints: ['/'], used: 10, available: 90 })] }),
    dev('/dev/sdb', 'disk', { model: 'WDC', children: [dev('/dev/sdb1', 'part', { fstype: 'linux_raid_member' })] }),
    dev('/dev/sdc', 'disk', { model: 'Seagate' }),
    dev('/dev/sdd', 'disk', { fstype: 'ext4', label: 'backup' }),
    dev('/dev/sr0', 'rom'),
  ],
  busy: { '/dev/sda': 'mounted', '/dev/sda1': 'mounted', '/dev/sdb': 'raidMember', '/dev/sdb1': 'raidMember' },
  arrays: [{ name: 'md0', state: 'active', level: 'raid1', members: [{ name: 'sdb1', faulty: false, spare: false }], raid_disks: 2, working_disks: 1, sync: null }],
  pools: [],
  tools: ['mdadm', 'mkfs.ext4', 'sfdisk', 'wipefs', 'smartctl'],
  job: null,
}

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
  servers.currentId = 'local'
  mocked.getStorage.mockResolvedValue(structuredClone(view))
})

describe('the storage model', () => {
  it('offers what is free, and mounts what can be', () => {
    expect(disksOf(view).map((d) => d.path)).toEqual(['/dev/sda', '/dev/sdb', '/dev/sdc', '/dev/sdd'])
    expect(freeDevices(view).map((d) => d.path)).toEqual(['/dev/sdc', '/dev/sdd'])
    expect(volumesOf(view.disks[3]).map((d) => d.path)).toEqual(['/dev/sdd'])
    expect(mountable(view.disks[3])).toBe(true)
    expect(mountable(view.disks[1].children[0])).toBe(false)
    expect(nextMd(view)).toBe('md1')
    expect([minimum(1), minimum(5), minimum(10), minimum('raidz2'), minimum('stripe')]).toEqual([2, 3, 4, 4, 1])
    expect([overlaps(view, '/dev/sdb', '/dev/sdb1'), overlaps(view, '/dev/sdb1', '/dev/sdb'), overlaps(view, '/dev/sdc', '/dev/sdd')]).toEqual([true, true, false])
  })

  it('keeps the system\'s mounts and firmware partitions', async () => {
    mocked.getStorage.mockResolvedValue({
      ...structuredClone(view),
      disks: [
        dev('/dev/sda', 'disk', {
          children: [
            dev('/dev/sda1', 'part', { fstype: 'ext4', mountpoints: ['/'] }),
            dev('/dev/sda14', 'part', { part_type: '21686148-6449-6e6f-744e-656564454649' }),
            dev('/dev/sda2', 'part', { fstype: 'ext4', mountpoints: ['/srv/data'] }),
          ],
        }),
      ],
      busy: { '/dev/sda': 'mounted', '/dev/sda1': 'mounted', '/dev/sda14': 'systemPartition', '/dev/sda2': 'mounted' },
      system: ['/dev/sda1'],
    })
    render(StorageApp)
    expect(await screen.findByText('System partition')).toBeInTheDocument()
    expect(screen.getByText('System')).toBeInTheDocument()
    // Only the data volume can be unmounted; nothing here can be formatted.
    expect(screen.getAllByRole('button', { name: 'Unmount' })).toHaveLength(1)
    expect(screen.queryByRole('button', { name: 'Format' })).toBeNull()
  })
})

describe('the Storage app', () => {
  it('lists the disks and a degraded array, and formats only after the name is typed back', async () => {
    const job = { id: 1, kind: 'storage' as never, state: 'running' as const, error: null, lines: [], next: 0 }
    mocked.storageAct.mockResolvedValue(job)
    mocked.storageJob.mockResolvedValue(job)
    render(StorageApp)
    expect(await screen.findByText(/^Samsung SSD · /)).toBeInTheDocument()
    // Busy disks offer no Initialize.
    expect(screen.getAllByRole('button', { name: 'Initialize' })).toHaveLength(2)
    await fireEvent.click(screen.getAllByRole('button', { name: 'Format' })[0])
    await fireEvent.click(screen.getByRole('button', { name: 'Continue' }))
    const go = screen.getAllByRole('button', { name: 'Format' }).at(-1)!
    expect(go).toBeDisabled()
    await fireEvent.input(screen.getByLabelText('Type /dev/sdc to confirm'), { target: { value: '/dev/sdc' } })
    expect(go).toBeEnabled()
    await fireEvent.click(go)
    await vi.waitFor(() => expect(mocked.storageAct).toHaveBeenCalledWith({ action: 'format', device: '/dev/sdc', fstype: 'ext4', label: null }, ''))

    await fireEvent.click(screen.getByText('RAID'))
    expect(await screen.findByText('Degraded')).toBeInTheDocument()
  })
})
