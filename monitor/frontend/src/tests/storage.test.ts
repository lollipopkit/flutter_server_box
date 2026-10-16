import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import StorageApp from '../desk/apps/storage/StorageApp.svelte'
import { arrayDevice, disksOf, expandable, freeDevices, growableArray, growablePartition, isLuks, minimum, mountable, nextMd, opened, overlaps, poolDeviceActions, verdict, volumesOf } from '../desk/apps/storage/model'
import { api, ApiError } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { BlockDevice, DiskHealth, HealthReading, StorageView, ZPool } from '../types'

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
  servers.list = [{ id: 'local', url: '', token: 't' }]
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

  it('knows what a partition, a LUKS container and a pool\'s devices allow', () => {
    const p1 = dev('/dev/sdb1', 'part', { size: 2 * 2 ** 30 })
    const disk = dev('/dev/sdb', 'disk', { size: 8 * 2 ** 30, children: [dev('/dev/sdb0', 'part', { size: 2 ** 20 }), p1] })
    expect(growablePartition(disk, p1)).toBe(true)
    expect(growablePartition(disk, disk.children[0])).toBe(false)
    expect(growablePartition({ ...disk, size: 2 * 2 ** 30 + 2 ** 21 }, p1)).toBe(false)

    const mapper = dev('/dev/mapper/luks-1', 'crypt', { fstype: 'ext4' })
    const luks = dev('/dev/sdc1', 'part', { fstype: 'crypto_LUKS', children: [mapper] })
    expect([isLuks(luks), opened(luks)?.path, opened({ ...luks, children: [] })]).toEqual([true, '/dev/mapper/luks-1', undefined])
    expect(volumesOf(dev('/dev/sdd', 'disk', { fstype: 'crypto_LUKS', children: [mapper] })).map((v) => v.path)).toEqual(['/dev/sdd'])

    const pool: ZPool = {
      name: 'tank', size: 1, allocated: 0, free: 1, health: 'DEGRADED', scan: null,
      vdevs: [
        { name: 'mirror-0', state: 'DEGRADED', depth: 0, errors: 0 },
        { name: '/dev/sdb', state: 'ONLINE', depth: 1, errors: 0 },
        { name: '/dev/sdc', state: 'OFFLINE', depth: 1, errors: 0 },
        { name: 'raidz1-1', state: 'ONLINE', depth: 0, errors: 0 },
        { name: '/dev/sdf', state: 'ONLINE', depth: 1, errors: 0 },
        { name: '/dev/sdg', state: 'ONLINE', depth: 0, errors: 0 },
        { name: '/dev/sdd', state: 'AVAIL', depth: 0, errors: 0, section: 'spares' },
      ],
    }
    const acts = pool.vdevs.map((_, i) => poolDeviceActions(pool, i))
    expect(acts[0]).toEqual({ replace: false, attach: false, remove: false, online: false })
    expect(acts[1]).toEqual({ replace: true, attach: true, remove: false, online: false })
    expect(acts[2]).toEqual({ replace: true, attach: true, remove: false, online: true })
    expect(acts[4]).toEqual({ replace: true, attach: false, remove: false, online: false })
    expect(acts[5]).toEqual({ replace: true, attach: true, remove: false, online: false })
    expect(acts[6]).toEqual({ replace: false, attach: false, remove: true, online: false })
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

  it('formats inside LUKS and unlocks with a passphrase that never goes in the action', async () => {
    // Done at once, so the next change is not waiting for this one.
    const job = { id: 3, kind: 'storage' as const, state: 'succeeded' as const, error: null, lines: [], next: 0 }
    mocked.storageAct.mockResolvedValue(job)
    mocked.storageJob.mockResolvedValue(job)
    const locked = dev('/dev/sde1', 'part', { fstype: 'crypto_LUKS' })
    mocked.getStorage.mockResolvedValue({
      ...structuredClone(view),
      tools: [...view.tools, 'cryptsetup'],
      disks: [...structuredClone(view.disks), dev('/dev/sde', 'disk', { children: [locked] })],
      busy: { ...view.busy, '/dev/sde': 'holdsVolume', '/dev/sde1': 'holdsVolume' },
    })
    render(StorageApp)
    await fireEvent.click(await screen.findByRole('button', { name: 'Unlock' }))
    await fireEvent.input(screen.getByLabelText('Passphrase'), { target: { value: 'correct horse' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Continue' }))
    await fireEvent.click(screen.getAllByRole('button', { name: 'Unlock' }).at(-1)!)
    await vi.waitFor(() => expect(mocked.storageAct).toHaveBeenCalledWith({ action: 'unlock', device: '/dev/sde1' }, '', 'correct horse'))

    // An encrypted format asks for the passphrase twice.
    await fireEvent.click(screen.getAllByRole('button', { name: 'Format' })[0])
    await fireEvent.click(screen.getByRole('checkbox', { name: 'Encrypt (LUKS)' }))
    await fireEvent.click(screen.getByRole('button', { name: 'Continue' }))
    await fireEvent.input(screen.getByLabelText(/^Passphrase/), { target: { value: 'twelve chars' } })
    await fireEvent.input(screen.getByLabelText('The same again'), { target: { value: 'twelve chars' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Continue' }))
    await fireEvent.input(screen.getByLabelText('Type /dev/sdc to confirm'), { target: { value: '/dev/sdc' } })
    await fireEvent.click(screen.getAllByRole('button', { name: 'Format' }).at(-1)!)
    await vi.waitFor(() =>
      expect(mocked.storageAct).toHaveBeenLastCalledWith({ action: 'format', device: '/dev/sdc', fstype: 'ext4', label: null, encrypt: true }, '', 'twelve chars'),
    )
  })

  it('replaces a pool\'s device with a free one', async () => {
    const job = { id: 4, kind: 'storage' as const, state: 'running' as const, error: null, lines: [], next: 0 }
    mocked.storageAct.mockResolvedValue(job)
    mocked.storageJob.mockResolvedValue(job)
    mocked.getStorage.mockResolvedValue({
      ...structuredClone(view),
      tools: [...view.tools, 'zpool'],
      pools: [{ name: 'tank', size: 1, allocated: 0, free: 1, health: 'DEGRADED', scan: null, vdevs: [{ name: 'mirror-0', state: 'DEGRADED', depth: 0, errors: 0 }, { name: '/dev/sdx', state: 'FAULTED', depth: 1, errors: 3 }] }],
    })
    render(StorageApp)
    await fireEvent.click(await screen.findByText('ZFS pools'))
    await fireEvent.click(await screen.findByRole('button', { name: 'Replace' }))
    await fireEvent.click(screen.getByRole('button', { name: 'Continue' }))
    await fireEvent.input(screen.getByLabelText('Type /dev/sdc to confirm'), { target: { value: '/dev/sdc' } })
    await fireEvent.click(screen.getAllByRole('button', { name: 'Replace' }).at(-1)!)
    await vi.waitFor(() => expect(mocked.storageAct).toHaveBeenCalledWith({ action: 'replaceInPool', name: 'tank', old: '/dev/sdx', new: '/dev/sdc' }, ''))
  })

  it('shows a disk\'s SMART details and starts a long test', async () => {
    mocked.storageHealth.mockResolvedValue({
      at: Math.floor(Date.now() / 1000),
      disks: [health('/dev/sdb', { attributes: [{ id: 5, name: 'Reallocated_Sector_Ct', value: 100, worst: 100, thresh: 140, raw: '8', failing: true }], tests: [{ long: true, outcome: 'failed', hours: 30980 }] })],
    })
    mocked.storageAct.mockResolvedValue({ id: 5, kind: 'storage', state: 'running', error: null, lines: [], next: 0 })
    mocked.storageJob.mockResolvedValue({ id: 5, kind: 'storage', state: 'running', error: null, lines: [], next: 0 })
    render(StorageApp)
    await fireEvent.click(await screen.findByRole('button', { name: 'Details' }))
    expect(screen.getByText('5 Reallocated_Sector_Ct')).toBeInTheDocument()
    expect(screen.getByText('Long · Failed · at 30980 h')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: 'Long test' }))
    await fireEvent.click(screen.getAllByRole('button', { name: 'Long test' }).at(-1)!)
    await vi.waitFor(() => expect(mocked.storageAct).toHaveBeenCalledWith({ action: 'smartTest', device: '/dev/sdb', long: true }, ''))
  })
})
