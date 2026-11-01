import { get } from 'svelte/store'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import StorageApp from '../desk/apps/storage/StorageApp.svelte'
import { arrayDevice, disksOf, isLuks, opened, verdict, volumesOf } from '../desk/apps/storage/model'
import { LL } from '../i18n/i18n-svelte'
import { api, ApiError } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { BlockDevice, DiskHealth, HealthReading, StorageView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getStorage: vi.fn(), storageAct: vi.fn(), storageJob: vi.fn(), storageHealth: vi.fn(), setStorageMaintenance: vi.fn(), runStorageMaintenance: vi.fn() },
}))

const ll = get(LL)
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
  mounted: false,
  mountable: false,
  expandable: false,
  available: null,
  used: null,
  children: [],
  ...extra,
})

const view: StorageView = {
  disks: [
    dev('/dev/sda', 'disk', { model: 'Samsung SSD', rotational: false, children: [dev('/dev/sda1', 'part', { fstype: 'ext4', mountpoints: ['/'], mounted: true, used: 10, available: 90 })] }),
    dev('/dev/sdb', 'disk', { model: 'WDC', children: [dev('/dev/sdb1', 'part', { fstype: 'linux_raid_member' })] }),
    dev('/dev/sdc', 'disk', { model: 'Seagate' }),
    dev('/dev/sdd', 'disk', { fstype: 'ext4', label: 'backup', mountable: true }),
    dev('/dev/sr0', 'rom'),
  ],
  busy: { '/dev/sda': 'mounted', '/dev/sda1': 'mounted', '/dev/sdb': 'raidMember', '/dev/sdb1': 'raidMember' },
  free: ['/dev/sdc', '/dev/sdd'],
  overlaps: {},
  growable_partitions: [],
  next_md: 'md1',
  raid_levels: [{ value: 0, minimum: 2 }, { value: 1, minimum: 2 }, { value: 5, minimum: 3 }, { value: 6, minimum: 4 }, { value: 10, minimum: 4 }],
  pool_layouts: [{ value: 'stripe', minimum: 1 }, { value: 'mirror', minimum: 2 }, { value: 'raidz1', minimum: 3 }, { value: 'raidz2', minimum: 4 }, { value: 'raidz3', minimum: 5 }],
  arrays: [{ name: 'md0', state: 'active', level: 'raid1', members: [{ name: 'sdb1', faulty: false, spare: false }], raid_disks: 2, working_disks: 1, sync: null, growable: true }],
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
  it('lists the disks and their filesystems', () => {
    expect(disksOf(view).map((d) => d.path)).toEqual(['/dev/sda', '/dev/sdb', '/dev/sdc', '/dev/sdd'])
    expect(volumesOf(view.disks[3]).map((d) => d.path)).toEqual(['/dev/sdd'])
  })

  it('finds an array\'s filesystem and a LUKS container\'s opened device', () => {
    const md = dev('/dev/md0', 'raid1', { fstype: 'ext4' })
    const v = { ...structuredClone(view), disks: [dev('/dev/sdb', 'disk', { children: [dev('/dev/sdb1', 'part', { children: [md] })] })] }
    expect(arrayDevice(v, 'md0')?.path).toBe('/dev/md0')
    expect(arrayDevice(v, 'md9')).toBeUndefined()

    const mapper = dev('/dev/mapper/luks-1', 'crypt', { fstype: 'ext4' })
    const luks = dev('/dev/sdc1', 'part', { fstype: 'crypto_LUKS', children: [mapper] })
    expect([isLuks(luks), opened(luks)?.path, opened({ ...luks, children: [] })]).toEqual([true, '/dev/mapper/luks-1', undefined])
    expect(volumesOf(dev('/dev/sdd', 'disk', { fstype: 'crypto_LUKS', children: [mapper] })).map((v) => v.path)).toEqual(['/dev/sdd'])
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
            dev('/dev/sda1', 'part', { fstype: 'ext4', mountpoints: ['/'], mounted: true }),
            dev('/dev/sda14', 'part', { part_type: '21686148-6449-6e6f-744e-656564454649' }),
            dev('/dev/sda2', 'part', { fstype: 'ext4', mountpoints: ['/srv/data'], mounted: true }),
          ],
        }),
      ],
      busy: { '/dev/sda': 'mounted', '/dev/sda1': 'mounted', '/dev/sda14': 'systemPartition', '/dev/sda2': 'mounted' },
      system: ['/dev/sda1'],
    })
    render(StorageApp)
    expect(await screen.findByText(ll.storageBusySystem())).toBeInTheDocument()
    expect(screen.getByText(ll.storageSystemDisk())).toBeInTheDocument()
    // Only the data volume can be unmounted; nothing here can be formatted.
    expect(screen.getAllByRole('button', { name: ll.storageUnmount() })).toHaveLength(1)
    expect(screen.queryByRole('button', { name: ll.storageFormat() })).toBeNull()
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
    expect(screen.getAllByRole('button', { name: ll.storageInitialize() })).toHaveLength(2)
    await fireEvent.click(screen.getAllByRole('button', { name: ll.storageFormat() })[0])
    await fireEvent.click(screen.getByRole('button', { name: ll.storageContinue() }))
    const go = screen.getAllByRole('button', { name: ll.storageFormat() }).at(-1)!
    expect(go).toBeDisabled()
    await fireEvent.input(screen.getByLabelText(ll.storageTypeToConfirm({ word: '/dev/sdc' })), { target: { value: '/dev/sdc' } })
    expect(go).toBeEnabled()
    await fireEvent.click(go)
    await vi.waitFor(() => expect(mocked.storageAct).toHaveBeenCalledWith({ action: 'format', device: '/dev/sdc', fstype: 'ext4', label: null }, ''))

    await fireEvent.click(screen.getByText(ll.storageRaid()))
    expect(await screen.findByText(ll.storageDegraded())).toBeInTheDocument()
  })

  it('reads SMART on its own where sudo lets it, and offers a test only where there is SMART', async () => {
    mocked.storageHealth.mockResolvedValue(structuredClone(reading))
    render(StorageApp)
    expect(await screen.findByText(ll.storageHealthWearing())).toBeInTheDocument()
    expect(mocked.storageHealth).toHaveBeenCalledWith()
    expect(screen.getByText(ll.storageHealthy())).toBeInTheDocument()
    expect(screen.getByText(ll.storageHealthUnsupported())).toBeInTheDocument()
    expect(screen.getByText(ll.storageHealthAsleep())).toBeInTheDocument()
    expect(screen.getByText(ll.storageTesting({ percent: 90 }), { exact: false })).toBeInTheDocument()
    // sda is testing already; sdb has SMART; the others have none.
    const tests = screen.getAllByRole('button', { name: ll.storageSmartTest() })
    expect(tests).toHaveLength(2)
    expect(tests[0]).toBeDisabled()
    expect(tests[1]).toBeEnabled()
  })

  it('asks for sudo\'s password to read SMART when sudo wants one', async () => {
    render(StorageApp)
    await vi.waitFor(() => expect(mocked.storageHealth).toHaveBeenCalledTimes(1))
    expect(screen.queryByRole('button', { name: ll.storageSmartTest() })).toBeNull()
    mocked.storageHealth.mockResolvedValue(structuredClone(reading))
    await fireEvent.click(screen.getByRole('button', { name: ll.storageHealthRead() }))
    await fireEvent.input(await screen.findByLabelText(ll.storageSudoPassword(), { exact: false }), { target: { value: 'pw' } })
    const read = screen.getAllByRole('button', { name: ll.storageHealthRead() }).at(-1)!
    await fireEvent.click(read)
    await vi.waitFor(() => expect(mocked.storageHealth).toHaveBeenLastCalledWith('pw'))
    expect(await screen.findByText(ll.storageHealthWearing())).toBeInTheDocument()
  })

  it('schedules maintenance and runs it now', async () => {
    const task = { task: 'scrub' as const, every: 'weekly' as const, at: '03:00', day: 6, last_run: null, last_error: null }
    mocked.setStorageMaintenance.mockResolvedValue({ maintenance: [task] })
    mocked.runStorageMaintenance.mockResolvedValue({ maintenance: [{ ...task, last_run: new Date().toISOString(), last_error: 'sudoNeedsPassword' }] })
    mocked.getStorage.mockResolvedValue({ ...structuredClone(view), account: 'sbm', maintenance: [] })
    render(StorageApp)
    await fireEvent.click(await screen.findByText(ll.storageMaintenance()))
    expect(screen.getByText(/sbm ALL=\(root\) NOPASSWD/)).toBeInTheDocument()
    await fireEvent.change(screen.getByLabelText(ll.storageTaskScrub()), { target: { value: 'weekly' } })
    await vi.waitFor(() => expect(mocked.setStorageMaintenance).toHaveBeenCalledWith('scrub', 'weekly', '03:00', 6))
    await fireEvent.click(await screen.findByRole('button', { name: ll.storageRunNow() }))
    expect(await screen.findByText(ll.storageNeedsSudo(), { exact: false })).toBeInTheDocument()
  })

  it('grows an array by one working member', async () => {
    mocked.storageAct.mockResolvedValue({ id: 2, kind: 'storage', state: 'running', error: null, lines: [], next: 0 })
    mocked.storageJob.mockResolvedValue({ id: 2, kind: 'storage', state: 'running', error: null, lines: [], next: 0 })
    render(StorageApp)
    await fireEvent.click(await screen.findByText(ll.storageRaid()))
    await fireEvent.click(await screen.findByRole('button', { name: ll.storageGrowRaid() }))
    await fireEvent.click(screen.getByRole('button', { name: ll.storageContinue() }))
    await fireEvent.input(screen.getByLabelText(ll.storageTypeToConfirm({ word: '/dev/sdc' })), { target: { value: '/dev/sdc' } })
    await fireEvent.click(screen.getAllByRole('button', { name: ll.storageGrowRaid() }).at(-1)!)
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
    await fireEvent.click(await screen.findByRole('button', { name: ll.storageUnlock() }))
    await fireEvent.input(screen.getByLabelText(ll.storagePassphrase()), { target: { value: 'correct horse' } })
    await fireEvent.click(screen.getByRole('button', { name: ll.storageContinue() }))
    await fireEvent.click(screen.getAllByRole('button', { name: ll.storageUnlock() }).at(-1)!)
    await vi.waitFor(() => expect(mocked.storageAct).toHaveBeenCalledWith({ action: 'unlock', device: '/dev/sde1' }, '', 'correct horse'))

    // An encrypted format asks for the passphrase twice.
    await fireEvent.click(screen.getAllByRole('button', { name: ll.storageFormat() })[0])
    await fireEvent.click(screen.getByRole('checkbox', { name: ll.storageEncrypt() }))
    await fireEvent.click(screen.getByRole('button', { name: ll.storageContinue() }))
    await fireEvent.input(screen.getByLabelText((label) => label.startsWith(ll.storagePassphrase())), { target: { value: 'twelve chars' } })
    await fireEvent.input(screen.getByLabelText(ll.storagePassphraseAgain()), { target: { value: 'twelve chars' } })
    await fireEvent.click(screen.getByRole('button', { name: ll.storageContinue() }))
    await fireEvent.input(screen.getByLabelText(ll.storageTypeToConfirm({ word: '/dev/sdc' })), { target: { value: '/dev/sdc' } })
    await fireEvent.click(screen.getAllByRole('button', { name: ll.storageFormat() }).at(-1)!)
    await vi.waitFor(() =>
      expect(mocked.storageAct).toHaveBeenLastCalledWith({ action: 'format', device: '/dev/sdc', fstype: 'ext4', label: null, encrypt: true }, '', 'twelve chars'),
    )
  })

  it('replaces a pool\'s device with a free one', async () => {
    const none = { replace: false, attach: false, remove: false, online: false }
    const job = { id: 4, kind: 'storage' as const, state: 'running' as const, error: null, lines: [], next: 0 }
    mocked.storageAct.mockResolvedValue(job)
    mocked.storageJob.mockResolvedValue(job)
    mocked.getStorage.mockResolvedValue({
      ...structuredClone(view),
      tools: [...view.tools, 'zpool'],
      pools: [{ name: 'tank', size: 1, allocated: 0, free: 1, health: 'DEGRADED', scan: null, vdevs: [{ name: 'mirror-0', state: 'DEGRADED', depth: 0, errors: 0, actions: none }, { name: '/dev/sdx', state: 'FAULTED', depth: 1, errors: 3, actions: { ...none, replace: true, attach: true } }] }],
    })
    render(StorageApp)
    await fireEvent.click(await screen.findByText(ll.storagePools()))
    await fireEvent.click(await screen.findByRole('button', { name: ll.storageReplace() }))
    await fireEvent.click(screen.getByRole('button', { name: ll.storageContinue() }))
    await fireEvent.input(screen.getByLabelText(ll.storageTypeToConfirm({ word: '/dev/sdc' })), { target: { value: '/dev/sdc' } })
    await fireEvent.click(screen.getAllByRole('button', { name: ll.storageReplace() }).at(-1)!)
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
    await fireEvent.click(await screen.findByRole('button', { name: ll.storageDetails() }))
    expect(screen.getByText('5 Reallocated_Sector_Ct')).toBeInTheDocument()
    expect(screen.getByText([ll.storageTestLong(), ll.storageTestFailed(), ll.storageAtHours({ hours: 30980 })].join(' · '))).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: ll.storageLongTest() }))
    await fireEvent.click(screen.getAllByRole('button', { name: ll.storageLongTest() }).at(-1)!)
    await vi.waitFor(() => expect(mocked.storageAct).toHaveBeenCalledWith({ action: 'smartTest', device: '/dev/sdb', long: true }, ''))
  })
})
