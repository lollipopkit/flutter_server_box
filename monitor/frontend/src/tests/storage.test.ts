import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import StorageApp from '../desk/apps/storage/StorageApp.svelte'
import { arrayDevice, disksOf, expandable, freeDevices, growableArray, minimum, mountable, nextMd, overlaps, verdict, volumesOf } from '../desk/apps/storage/model'
import { api, ApiError } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { BlockDevice, DiskHealth, HealthReading, StorageView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getStorage: vi.fn(), storageAct: vi.fn(), storageJob: vi.fn(), storageHealth: vi.fn(), setStorageMaintenance: vi.fn(), runStorageMaintenance: vi.fn() },
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
  mocked.storageHealth.mockRejectedValue(new ApiError('sudo_rejected', 403, 'sudo_rejected', { error: 'sudo_rejected' }))
})

const health = (device: string, extra: Partial<DiskHealth> = {}): DiskHealth => ({
  device,
  supported: true,
  asleep: false,
  passed: true,
  temperature: 35,
  power_on_hours: 1000,
  bad_sectors: 0,
  testing: null,
  last_test: null,
  ...extra,
})

const reading: HealthReading = {
  at: Math.floor(Date.now() / 1000),
  disks: [health('/dev/sda', { testing: 90 }), health('/dev/sdb', { bad_sectors: 8 }), health('/dev/sdc', { supported: false, passed: null }), health('/dev/sdd', { supported: false, asleep: true })],
}

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

  it('finds an array\'s filesystem and what can grow', () => {
    const md = dev('/dev/md0', 'raid1', { fstype: 'ext4', mountpoints: ['/srv/data'], size: 8 * 2 ** 30, fs_size: 4 * 2 ** 30 })
    const v = { ...structuredClone(view), disks: [dev('/dev/sdb', 'disk', { children: [dev('/dev/sdb1', 'part', { children: [md] })] })] }
    expect(arrayDevice(v, 'md0')?.path).toBe('/dev/md0')
    expect(arrayDevice(v, 'md9')).toBeUndefined()
    expect(expandable(md)).toBe(true)
    // What ext4 keeps for itself is not room to grow into.
    expect(expandable({ ...md, fs_size: 7.8 * 2 ** 30 })).toBe(false)
    expect(expandable({ ...md, mountpoints: [] })).toBe(false)
    expect(expandable({ ...md, fstype: 'vfat' })).toBe(false)
    expect(['raid0', 'raid1', 'raid5', 'raid6', 'raid10', null].map(growableArray)).toEqual([false, true, true, true, false, false])
  })

  it('says what a disk\'s SMART says', () => {
    expect(reading.disks.map(verdict)).toEqual(['healthy', 'wearing', 'unsupported', 'asleep'])
    expect(verdict(health('/dev/sde', { passed: false }))).toBe('failing')
    expect(verdict(health('/dev/sde', { last_test: { long: true, outcome: 'failed', hours: 1 } }))).toBe('failing')
    expect(verdict(health('/dev/sde', { last_test: { long: false, outcome: 'aborted', hours: 1 } }))).toBe('healthy')
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

  it('reads SMART on its own where sudo lets it, and offers a test only where there is SMART', async () => {
    mocked.storageHealth.mockResolvedValue(structuredClone(reading))
    render(StorageApp)
    expect(await screen.findByText('Wearing')).toBeInTheDocument()
    expect(mocked.storageHealth).toHaveBeenCalledWith()
    expect(screen.getByText('Healthy')).toBeInTheDocument()
    expect(screen.getByText('No SMART')).toBeInTheDocument()
    expect(screen.getByText('Asleep')).toBeInTheDocument()
    expect(screen.getByText(/Self-test: 90% left/)).toBeInTheDocument()
    // sda is testing already; sdb has SMART; the others have none.
    const tests = screen.getAllByRole('button', { name: 'SMART test' })
    expect(tests).toHaveLength(2)
    expect(tests[0]).toBeDisabled()
    expect(tests[1]).toBeEnabled()
  })

  it('asks for sudo\'s password to read SMART when sudo wants one', async () => {
    render(StorageApp)
    await vi.waitFor(() => expect(mocked.storageHealth).toHaveBeenCalledTimes(1))
    expect(screen.queryByRole('button', { name: 'SMART test' })).toBeNull()
    mocked.storageHealth.mockResolvedValue(structuredClone(reading))
    await fireEvent.click(screen.getByRole('button', { name: 'Read disk health' }))
    await fireEvent.input(await screen.findByLabelText(/sudo password/), { target: { value: 'pw' } })
    const read = screen.getAllByRole('button', { name: 'Read disk health' }).at(-1)!
    await fireEvent.click(read)
    await vi.waitFor(() => expect(mocked.storageHealth).toHaveBeenLastCalledWith('pw'))
    expect(await screen.findByText('Wearing')).toBeInTheDocument()
  })

  it('schedules maintenance and runs it now', async () => {
    const task = { task: 'scrub' as const, every: 'weekly' as const, at: '03:00', day: 6, last_run: null, last_error: null }
    mocked.setStorageMaintenance.mockResolvedValue({ maintenance: [task] })
    mocked.runStorageMaintenance.mockResolvedValue({ maintenance: [{ ...task, last_run: new Date().toISOString(), last_error: 'sudoNeedsPassword' }] })
    mocked.getStorage.mockResolvedValue({ ...structuredClone(view), account: 'sbm', maintenance: [] })
    render(StorageApp)
    await fireEvent.click(await screen.findByText('Maintenance'))
    expect(screen.getByText(/sbm ALL=\(root\) NOPASSWD/)).toBeInTheDocument()
    await fireEvent.change(screen.getByLabelText('Scrub pools and check arrays'), { target: { value: 'weekly' } })
    await vi.waitFor(() => expect(mocked.setStorageMaintenance).toHaveBeenCalledWith('scrub', 'weekly', '03:00', 6))
    await fireEvent.click(await screen.findByRole('button', { name: 'Run now' }))
    expect(await screen.findByText(/sudo asked for a password/)).toBeInTheDocument()
  })

  it('grows an array by one working member', async () => {
    mocked.storageAct.mockResolvedValue({ id: 2, kind: 'storage', state: 'running', error: null, lines: [], next: 0 })
    mocked.storageJob.mockResolvedValue({ id: 2, kind: 'storage', state: 'running', error: null, lines: [], next: 0 })
    render(StorageApp)
    await fireEvent.click(await screen.findByText('RAID'))
    await fireEvent.click(await screen.findByRole('button', { name: 'Grow' }))
    await fireEvent.click(screen.getByRole('button', { name: 'Continue' }))
    await fireEvent.input(screen.getByLabelText('Type /dev/sdc to confirm'), { target: { value: '/dev/sdc' } })
    await fireEvent.click(screen.getAllByRole('button', { name: 'Grow' }).at(-1)!)
    await vi.waitFor(() => expect(mocked.storageAct).toHaveBeenCalledWith({ action: 'growRaid', array: 'md0', device: '/dev/sdc' }, ''))
  })
})
