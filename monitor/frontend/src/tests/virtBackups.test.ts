import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor, within } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import VirtBackups from '../components/VirtBackups.svelte'
import VirtBackupJobs from '../components/VirtBackupJobs.svelte'
import Virt from '../pages/Virt.svelte'
import { api } from '../lib/api'
import {
  backupIssueText,
  createIssueText,
  jobDraft,
  jobEdit,
  modeText,
  newestFirst,
  ownJob,
  ownJobDraft,
  pruneString,
  pruneText,
  retentionDraft,
  selectionText,
  storageNames,
  virtErrorText,
  vmidList,
} from '../lib/virt'
import type { VirtBackup, VirtBackupIssue, VirtBackupJob, VirtError, VirtGuest, VirtHostView, VirtPool } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    virtBackups: vi.fn(),
    virtBackup: vi.fn(),
    virtRestoreBackup: vi.fn(),
    virtEditBackup: vi.fn(),
    virtDeleteBackup: vi.fn(),
    backupJobs: vi.fn(),
    editBackupJob: vi.fn(),
    runBackupJob: vi.fn(),
    checkBackupSchedule: vi.fn(),
    virtStorage: vi.fn(),
    loadVirt: vi.fn(),
  },
}))
const virtBackups = vi.mocked(api.virtBackups)
const virtBackup = vi.mocked(api.virtBackup)
const virtRestoreBackup = vi.mocked(api.virtRestoreBackup)
const virtEditBackup = vi.mocked(api.virtEditBackup)
const virtDeleteBackup = vi.mocked(api.virtDeleteBackup)
const backupJobs = vi.mocked(api.backupJobs)
const editBackupJob = vi.mocked(api.editBackupJob)
const runBackupJob = vi.mocked(api.runBackupJob)
const checkBackupSchedule = vi.mocked(api.checkBackupSchedule)
const virtStorage = vi.mocked(api.virtStorage)
const loadVirt = vi.mocked(api.loadVirt)

const ISSUES: VirtBackupIssue[] = [
  'schedule_empty',
  'schedule_invalid',
  'storage',
  'mode',
  'compress',
  'guests',
  'node_offline',
  'not_stopped',
  'not_found',
  'unsupported',
]

const err = (over: Partial<VirtError>): VirtError => ({ kind: 'unsupported', message: null, detail: null, cert: null, previous_fingerprint: null, ...over })

function job(over: Partial<VirtBackupJob> = {}): VirtBackupJob {
  return {
    id: 'backup-1',
    schedule: '02:00',
    storage: 'nfs-backup',
    mode: 'snapshot',
    compress: 'zstd',
    enabled: true,
    all: false,
    vmids: [100],
    exclude: [],
    pool: null,
    node: null,
    comment: null,
    notes_template: null,
    mail_notification: null,
    prune: 'keep-last=7',
    ...over,
  }
}

function backup(over: Partial<VirtBackup> = {}): VirtBackup {
  return {
    id: 'nfs-backup:backup/vzdump-qemu-100-2026_09_24-02_00_00.vma.zst',
    storage: 'nfs-backup',
    node: 'pve',
    vmid: 100,
    created_at: 1_790_000_000,
    size: 2 * 1024 ** 3,
    format: 'vma.zst',
    notes: 'nightly',
    protected: false,
    verification: 'ok',
    kind: 'qemu',
    ...over,
  }
}

function pool(name: string, node: string | null = 'pve', content = ['backup']): VirtPool {
  return { id: `${node}/${name}`, name, node, type: 'dir', path: null, source: null, capacity: null, used: null, available: null, active: true, autostart: null, enabled: true, shared: false, content, volume_count: null }
}

function guest(over: Partial<VirtGuest> = {}): VirtGuest {
  return {
    id: 'qemu/100',
    name: 'web',
    kind: 'qemu',
    state: 'running',
    state_reason: null,
    vmid: 100,
    node: 'pve',
    vcpu: 2,
    mem_bytes: 2 * 1024 ** 3,
    uptime: 60,
    tags: [],
    template: false,
    autostart: false,
    actions: ['shutdown'],
    ...over,
  }
}

function hostView(): VirtHostView {
  return {
    host: {
      kind: 'pve',
      version: null,
      hypervisor: null,
      nodes: [
        { name: 'pve', online: true, cpu: null, max_cpu: 8, mem_used: null, mem_total: null, uptime: null },
        { name: 'pve2', online: true, cpu: null, max_cpu: 8, mem_used: null, mem_total: null, uptime: null },
      ],
    },
    guests: [guest()],
    stats: {},
    capabilities: { lxc: true, pause: true, cluster: true, backup: true, backup_jobs: true },
  }
}

describe('backups: the helpers', () => {
  it('phrases every refusal of a backup request, also as a host error', () => {
    const texts = ISSUES.map((i) => backupIssueText(i))
    for (const t of texts) expect(t).toMatch(/\S/)
    expect(new Set(texts).size).toBe(ISSUES.length)
    for (const issue of ISSUES) {
      expect(virtErrorText(err({ detail: { code: 'backup_refused', issue } }))).toBe(backupIssueText(issue))
    }
    // A restore as a taken VMID is the create refusal.
    expect(virtErrorText(err({ detail: { code: 'create_refused', issue: 'vmid_taken' } }))).toBe(createIssueText('vmid_taken'))
  })

  it('finds the guest\'s own job: its VMID and no other guest', () => {
    const own = job({ id: 'own' })
    expect(ownJob([job({ id: 'all', all: true, vmids: [] }), own], 100)).toBe(own)
    expect(ownJob([job({ vmids: [100, 101] })], 100)).toBeNull()
    expect(ownJob([job({ pool: 'prod' })], 100)).toBeNull()
    expect(ownJob([job({ all: true, exclude: [101] })], 100)).toBeNull()
    expect(ownJob([job()], 101)).toBeNull()
    expect(ownJob([job()], null)).toBeNull()
  })

  it('says which guests a job takes, and how', () => {
    expect(selectionText(job({ all: true, vmids: [] }))).toBe('All guests')
    expect(selectionText(job({ all: true, vmids: [], exclude: [101, 102] }))).toBe('All guests except 101, 102')
    expect(selectionText(job({ vmids: [100, 101] }))).toBe('VMID 100, 101')
    expect(selectionText(job({ pool: 'prod' }))).toBe('Pool prod')
    expect(modeText('stop', '0')).toBe('stop · none')
    expect(modeText(null, null)).toBe('snapshot · none')
    expect(modeText('snapshot', 'zstd')).toBe('snapshot · zstd')
  })

  it('reads VMIDs as typed, whole numbers only', () => {
    expect(vmidList('100, 101 102,,abc 1.5 -3')).toEqual([100, 101, 102])
    expect(vmidList('')).toEqual([])
  })

  it('builds the retention string and keeps what it does not edit', () => {
    const d = retentionDraft('keep-last=7, keep-daily=4,keep-all=0')
    expect(d.keep['keep-last']).toBe('7')
    expect(d.keep['keep-daily']).toBe('4')
    expect(d.keep['keep-weekly']).toBe('')
    expect(d.extra).toEqual(['keep-all=0'])
    expect(pruneString(d)).toBe('keep-last=7,keep-daily=4,keep-all=0')
    d.keep['keep-weekly'] = 2 as unknown as string
    d.keep['keep-last'] = ''
    expect(pruneString(d)).toBe('keep-daily=4,keep-weekly=2,keep-all=0')
    expect(pruneString(retentionDraft(null))).toBeNull()
    expect(pruneText('keep-last=7,keep-daily=4')).toBe('Last 7 · Daily 4')
    expect(pruneText(null)).toBe('The storage\'s own')
  })

  it('turns a job into its editor and back, every field carried', () => {
    const j = job({ node: 'pve', comment: 'nightly', notes_template: '{{guestname}}', mail_notification: 'failure', compress: null, all: true, vmids: [], exclude: [101] })
    expect(jobEdit(jobDraft(j))).toEqual({
      id: 'backup-1',
      is_new: false,
      node: 'pve',
      storage: 'nfs-backup',
      schedule: '02:00',
      mode: 'snapshot',
      compress: '0',
      enabled: true,
      all: true,
      vmids: [],
      exclude: [101],
      comment: 'nightly',
      notes_template: '{{guestname}}',
      mail_notification: 'failure',
      prune: 'keep-last=7',
    })
    // A new job: PVE names it, no node, the storage given.
    const fresh = jobEdit({ ...jobDraft(null, 'local'), selection: 'pool', pool: ' prod ', notesTemplate: '' })
    expect(fresh).toEqual({ is_new: true, storage: 'local', schedule: '02:00', mode: 'snapshot', compress: 'zstd', enabled: true, all: false, vmids: [], exclude: [], pool: 'prod' })
    // The guest's own: its VMID alone, whatever the job held.
    expect(jobEdit(ownJobDraft(null, 100, 'local'))).toMatchObject({ is_new: true, all: false, vmids: [100], exclude: [] })
    expect(jobEdit(ownJobDraft(job({ id: 'own' }), 100))).toMatchObject({ id: 'own', is_new: false, vmids: [100] })
  })

  it('offers a job the storages of its node, each name once', () => {
    const storages = [pool('local', 'pve'), pool('local', 'pve2'), pool('nfs', 'pve2')]
    expect(storageNames(storages, '')).toEqual(['local', 'nfs'])
    expect(storageNames(storages, 'pve')).toEqual(['local'])
  })

  it('sorts backups newest first, undated last', () => {
    const a = backup({ id: 'a', created_at: 1 })
    const b = backup({ id: 'b', created_at: 3 })
    const c = backup({ id: 'c', created_at: null })
    expect(newestFirst([a, c, b]).map((x) => x.id)).toEqual(['b', 'a', 'c'])
  })
})

describe('a guest\'s backups', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    virtStorage.mockResolvedValue({ pools: [pool('local-lvm', 'pve', ['images']), pool('nfs-backup')], rules: null, error: null })
  })

  function listing(over: { backups?: VirtBackup[]; jobs?: VirtBackupJob[] } = {}) {
    return { backups: over.backups ?? [backup()], jobs: over.jobs ?? [], storages: [pool('nfs-backup'), pool('local')], error: null }
  }

  it('backs up now with what the form says, and reads the list again', async () => {
    virtBackups.mockResolvedValue(listing({ backups: [] }))
    virtBackup.mockResolvedValue({ error: null })
    render(VirtBackups, { view: hostView(), guest: guest(), onchanged: () => {} })
    expect(await screen.findByText('No backups.')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /^back up now$/i }))
    await fireEvent.click(screen.getByRole('button', { name: /^stop$/i }))
    await fireEvent.click(screen.getByRole('button', { name: /^lzo$/i }))
    await fireEvent.input(screen.getByPlaceholderText('Optional'), { target: { value: ' before upgrade ' } })
    await fireEvent.click(screen.getByRole('checkbox', { name: /protected/i }))
    await fireEvent.click(screen.getByRole('button', { name: /^start backup$/i }))
    await waitFor(() =>
      expect(virtBackup).toHaveBeenCalledWith('qemu/100', { storage: 'local', mode: 'stop', compress: 'lzo', protected: true, notes: 'before upgrade' }),
    )
    expect(await screen.findByText('Backed up web.')).toBeInTheDocument()
    expect(virtBackups).toHaveBeenCalledTimes(2)
  })

  it('says why the host refused a backup', async () => {
    virtBackups.mockResolvedValue(listing())
    virtBackup.mockResolvedValue({ error: err({ detail: { code: 'backup_refused', issue: 'storage' } }) })
    render(VirtBackups, { view: hostView(), guest: guest(), onchanged: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^back up now$/i }))
    await fireEvent.click(screen.getByRole('button', { name: /^start backup$/i }))
    expect(await screen.findByText(backupIssueText('storage'))).toBeInTheDocument()
  })

  it('restores over the guest only while it is stopped, and only on the second click', async () => {
    virtBackups.mockResolvedValue(listing())
    virtRestoreBackup.mockResolvedValue({ error: null })
    const onchanged = vi.fn()
    const { rerender } = render(VirtBackups, { view: hostView(), guest: guest(), onchanged })
    await fireEvent.click(await screen.findByRole('button', { expanded: false }))
    // Running: as a new guest is what is offered first; over it is closed.
    await fireEvent.click(screen.getByRole('button', { name: /^over this guest$/i }))
    expect(screen.getByRole('button', { name: /^restore$/i })).toBeDisabled()
    expect(screen.getByText('Shut it down first.')).toBeInTheDocument()

    await rerender({ view: hostView(), guest: guest({ state: 'stopped' }), onchanged })
    const restore = screen.getByRole('button', { name: /^restore$/i })
    expect(restore).toBeEnabled()
    await fireEvent.click(restore)
    expect(virtRestoreBackup).not.toHaveBeenCalled()
    await fireEvent.click(screen.getByRole('button', { name: /^confirm: overwrite web$/i }))
    await waitFor(() => expect(virtRestoreBackup).toHaveBeenCalledWith('qemu/100', backup().id, {}))
    expect(await screen.findByText('Restored web from the backup.')).toBeInTheDocument()
    expect(onchanged).toHaveBeenCalled()
  })

  it('restores as a new VMID on one click, with the storage picked', async () => {
    virtBackups.mockResolvedValue(listing())
    virtRestoreBackup.mockResolvedValue({ error: err({ kind: 'exists', detail: { code: 'create_refused', issue: 'vmid_taken' } }) })
    render(VirtBackups, { view: hostView(), guest: guest(), onchanged: () => {} })
    await fireEvent.click(await screen.findByRole('button', { expanded: false }))
    await fireEvent.input(screen.getByPlaceholderText('Next free'), { target: { value: '120' } })
    const storage = await screen.findByRole('option', { name: 'local-lvm · dir' })
    await fireEvent.change(storage.closest('select')!, { target: { value: 'local-lvm' } })
    await fireEvent.click(screen.getByRole('button', { name: /^restore$/i }))
    await waitFor(() => expect(virtRestoreBackup).toHaveBeenCalledWith('qemu/100', backup().id, { vmid: 120, storage: 'local-lvm' }))
    expect(await screen.findByText(createIssueText('vmid_taken'))).toBeInTheDocument()
  })

  it('keeps a protected backup from deletion, edits its notes, and deletes on the second click', async () => {
    virtBackups.mockResolvedValue(listing({ backups: [backup({ protected: true })] }))
    virtEditBackup.mockResolvedValue({ error: null })
    virtDeleteBackup.mockResolvedValue({ error: null })
    render(VirtBackups, { view: hostView(), guest: guest(), onchanged: () => {} })
    await fireEvent.click(await screen.findByRole('button', { expanded: false }))
    expect(screen.getByRole('button', { name: /^delete$/i })).toBeDisabled()
    await fireEvent.input(screen.getByDisplayValue('nightly'), { target: { value: 'kept' } })
    await fireEvent.click(screen.getByRole('checkbox', { name: /protected/i }))
    await fireEvent.click(screen.getByRole('button', { name: /^save$/i }))
    await waitFor(() => expect(virtEditBackup).toHaveBeenCalledWith('qemu/100', backup().id, { notes: 'kept', protected: false }))

    virtBackups.mockResolvedValue(listing())
    virtBackups.mock.calls.length = 0
    render(VirtBackups, { view: hostView(), guest: guest({ id: 'qemu/101' }), onchanged: () => {} })
    const rows = await screen.findAllByRole('button', { expanded: false })
    await fireEvent.click(rows.at(-1)!)
    const del = screen.getAllByRole('button', { name: /^delete$/i }).find((b) => !(b as HTMLButtonElement).disabled)!
    await fireEvent.click(del)
    expect(virtDeleteBackup).not.toHaveBeenCalled()
    await fireEvent.click(screen.getByRole('button', { name: /^confirm: delete backup$/i }))
    await waitFor(() => expect(virtDeleteBackup).toHaveBeenCalledWith('qemu/101', backup().id))
  })

  it('edits the guest\'s own job and leaves the others to the datacenter view', async () => {
    const own = job({ id: 'own' })
    const shared = job({ id: 'nightly', all: true, vmids: [] })
    virtBackups.mockResolvedValue(listing({ jobs: [shared, own] }))
    editBackupJob.mockResolvedValue({ error: null })
    const onjobs = vi.fn()
    render(VirtBackups, { view: hostView(), guest: guest(), onchanged: () => {}, onjobs })
    expect(await screen.findByText('This job also takes other guests. Edit it under Backup jobs.')).toBeInTheDocument()
    expect(screen.getAllByText('Last 7').length).toBe(2)
    await fireEvent.click(screen.getByRole('button', { name: /datacenter/i }))
    expect(onjobs).toHaveBeenCalled()

    await fireEvent.click(screen.getByRole('button', { name: /^edit$/i }))
    await fireEvent.input(screen.getByDisplayValue('02:00'), { target: { value: 'sat 03:00' } })
    await fireEvent.click(screen.getByRole('button', { name: /^save$/i }))
    await waitFor(() => expect(editBackupJob).toHaveBeenCalledTimes(1))
    expect(editBackupJob.mock.calls[0][0]).toMatchObject({ id: 'own', is_new: false, schedule: 'sat 03:00', vmids: [100], all: false, prune: 'keep-last=7' })

    await fireEvent.click(await screen.findByRole('button', { name: /^remove schedule$/i }))
    expect(editBackupJob).toHaveBeenCalledTimes(1)
    await fireEvent.click(screen.getByRole('button', { name: /^confirm: remove job own$/i }))
    await waitFor(() => expect(editBackupJob).toHaveBeenLastCalledWith(expect.objectContaining({ id: 'own' }), true))
  })

  it('adds a job for the guest alone when none is its own', async () => {
    virtBackups.mockResolvedValue(listing({ jobs: [] }))
    editBackupJob.mockResolvedValue({ error: null })
    render(VirtBackups, { view: hostView(), guest: guest(), onchanged: () => {} })
    expect(await screen.findByText('No backup job takes this guest.')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /^add a schedule$/i }))
    await fireEvent.click(screen.getByRole('button', { name: /^save$/i }))
    await waitFor(() =>
      expect(editBackupJob).toHaveBeenCalledWith(expect.objectContaining({ is_new: true, storage: 'local', vmids: [100], all: false, schedule: '02:00' })),
    )
  })
})

describe('the datacenter\'s backup jobs', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    backupJobs.mockResolvedValue({ jobs: [job({ id: 'nightly', all: true, vmids: [], exclude: [101] })], storages: [pool('local', 'pve'), pool('nfs', 'pve2')], error: null })
  })

  it('validates a schedule: the next runs in local time, or PVE\'s refusal', async () => {
    checkBackupSchedule.mockResolvedValueOnce({ check: { error: null, next: [1_790_000_000, 1_790_086_400, 1_790_172_800] }, error: null })
    checkBackupSchedule.mockResolvedValueOnce({ check: { error: 'value \'25:00\' out of range', next: [] }, error: null })
    render(VirtBackupJobs, { view: hostView() })
    await fireEvent.click(await screen.findByRole('button', { name: /^new job$/i }))
    await fireEvent.click(screen.getByRole('button', { name: /^validate$/i }))
    await waitFor(() => expect(checkBackupSchedule).toHaveBeenCalledWith('02:00'))
    expect(await screen.findByText(new Date(1_790_086_400 * 1000).toLocaleString())).toBeInTheDocument()

    await fireEvent.input(screen.getByDisplayValue('02:00'), { target: { value: '25:00' } })
    expect(screen.queryByText(new Date(1_790_086_400 * 1000).toLocaleString())).not.toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /^validate$/i }))
    expect(await screen.findByText('PVE does not take this schedule: value \'25:00\' out of range')).toBeInTheDocument()
  })

  it('offers the chosen node\'s storages and sends the whole job', async () => {
    editBackupJob.mockResolvedValue({ error: null })
    render(VirtBackupJobs, { view: hostView() })
    await fireEvent.click(await screen.findByRole('button', { name: /^new job$/i }))
    const node = screen.getByRole('option', { name: 'Any node' }).closest('select')!
    await fireEvent.change(node, { target: { value: 'pve2' } })
    const storage = screen.getByRole('option', { name: 'Pick a storage' }).closest('select')!
    expect(within(storage).queryByRole('option', { name: 'nfs' })).toBeInTheDocument()
    await fireEvent.change(storage, { target: { value: 'nfs' } })
    await fireEvent.input(screen.getByPlaceholderText('101, 102'), { target: { value: '101 102' } })
    await fireEvent.click(screen.getByRole('button', { name: /^save$/i }))
    await waitFor(() =>
      expect(editBackupJob).toHaveBeenCalledWith(expect.objectContaining({ is_new: true, node: 'pve2', storage: 'nfs', all: true, exclude: [101, 102], vmids: [] })),
    )
  })

  it('runs a job now only on the second click, and shows it running', async () => {
    let finish: (v: { error: null }) => void = () => {}
    runBackupJob.mockReturnValue(new Promise((r) => (finish = r)))
    render(VirtBackupJobs, { view: hostView() })
    expect(await screen.findByText(/All guests except 101/)).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { expanded: false }))
    await fireEvent.click(screen.getByRole('button', { name: /^run now$/i }))
    expect(runBackupJob).not.toHaveBeenCalled()
    await fireEvent.click(screen.getByRole('button', { name: /^confirm: run nightly now$/i }))
    expect(runBackupJob).toHaveBeenCalledWith('nightly')
    expect(await screen.findByText('Running job nightly…')).toBeInTheDocument()
    finish({ error: null })
    expect(await screen.findByText('Job nightly finished.')).toBeInTheDocument()
  })
})

describe('the virtualization page: backups', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    virtBackups.mockResolvedValue({ backups: [], jobs: [], storages: [pool('local')], error: null })
    backupJobs.mockResolvedValue({ jobs: [], storages: [], error: null })
  })

  it('offers the Backup tab and the jobs section where the host keeps backups, for a template too', async () => {
    const view = hostView()
    view.guests = [guest({ template: true, state: 'stopped', actions: [] })]
    loadVirt.mockResolvedValue({ host: 'pve', supported: true, pve_configured: true, view, error: null })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^backup$/i }))
    expect(await screen.findByRole('button', { name: /^back up now$/i })).toBeInTheDocument()
    expect(virtBackups).toHaveBeenCalledWith('qemu/100')
    await fireEvent.click(screen.getByRole('button', { name: /datacenter/i }))
    expect(await screen.findByText('No backup jobs.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /^backup jobs$/i })).toHaveAttribute('aria-current', 'page')
  })

  it('offers neither where it does not (libvirt)', async () => {
    const view = hostView()
    view.host.kind = 'libvirt'
    view.capabilities = { lxc: false, pause: true, cluster: false, backup: false, backup_jobs: false }
    loadVirt.mockResolvedValue({ host: 'libvirt', supported: true, pve_configured: false, view, error: null })
    render(Virt, { onback: () => {} })
    expect(await screen.findByRole('button', { name: /^overview$/i })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^backup$/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^backup jobs$/i })).not.toBeInTheDocument()
  })
})
