import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import VirtHardware from '../components/VirtHardware.svelte'
import VirtManage from '../components/VirtManage.svelte'
import { api } from '../lib/api'
import {
  bootDraft,
  bootOrder,
  ciDraft,
  cloudInitEdit,
  cpuChange,
  cpuDraft,
  diskUpdate,
  displayChange,
  displayDraft,
  gibBytes,
  hwIssueText,
  memoryChange,
  memoryDraft,
  moveItem,
  nicDraft,
  nicHardware,
  nicUpdate,
  num,
  outcomeText,
  virtErrorText,
} from '../lib/virt'
import type { VirtCloudInitState, VirtError, VirtGuest, VirtHardware as Hw, VirtHostView, VirtHwIssue } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    virtHardware: vi.fn(),
    virtHardwareChange: vi.fn(),
    virtHardwareRevert: vi.fn(),
    virtCloudInit: vi.fn(),
    virtSetCloudInit: vi.fn(),
    virtHostDevices: vi.fn(),
    virtVolumes: vi.fn(),
    createForm: vi.fn(),
    cloneForm: vi.fn(),
  },
}))
const virtHardware = vi.mocked(api.virtHardware)
const virtHardwareChange = vi.mocked(api.virtHardwareChange)
const virtHardwareRevert = vi.mocked(api.virtHardwareRevert)
const virtCloudInit = vi.mocked(api.virtCloudInit)
const virtSetCloudInit = vi.mocked(api.virtSetCloudInit)
const createForm = vi.mocked(api.createForm)
const cloneForm = vi.mocked(api.cloneForm)

const HW_ISSUES: VirtHwIssue[] = [
  'cpu_count',
  'cpu_online',
  'memory',
  'memory_min',
  'disk_shrink',
  'disk_size',
  'storage_space',
  'mount_point',
  'boot_empty',
  'name_invalid',
  'name_running',
  'description',
  'mac',
  'stop_first',
  'storage_missing',
  'device',
  'volume_in_use',
  'media',
  'not_offered',
  'not_found',
  'unsupported',
]

function hardware(over: Partial<Hw> = {}): Hw {
  return {
    kind: 'qemu',
    running: true,
    cpu: { sockets: 1, cores: 2, threads: 1, online: null, type: null },
    memory: { mib: 2048, min_mib: 1024, balloon: true, swap_mib: null },
    disks: [
      { key: 'scsi0', kind: 'disk', source: 'local-lvm:vm-100-disk-0', size: 8 * 1024 ** 3, storage: 'local-lvm', mount_point: null, bus: 'scsi', format: 'raw', readonly: false, cache: null, cloud_init: false, resizable: true },
      { key: 'ide2', kind: 'cdrom', source: 'local:iso/debian.iso', size: null, storage: 'local', mount_point: null, bus: 'ide', format: null, readonly: true, cache: null, cloud_init: false, resizable: false },
    ],
    nics: [{ key: 'net0', mac: 'BC:24:11:00:00:01', type: null, source: 'vmbr0', model: 'virtio', link_up: true, firewall: true, name: null }],
    boot: ['scsi0', 'ide2'],
    autostart: false,
    name: 'web',
    description: 'notes',
    protection: false,
    rename_running: true,
    pending: [],
    revision: 'd1',
    limits: { host_cpus: 8, host_memory_bytes: 16 * 1024 ** 3 },
    cpu_types: ['host', 'kvm64'],
    config_text: 'cores: 2',
    firmware: { uefi: false, secure_boot: false, vars_storage: null },
    display: { protocol: null, listen: null, gpu: 'std', port: null },
    devices: [{ key: 'usb0', kind: 'usb', detail: '0bda:b023', mapping: false }],
    support: {
      buses: ['scsi', 'virtio', 'sata'],
      caches: ['default', 'none', 'writeback'],
      nic_models: ['virtio', 'e1000'],
      mac: true,
      protocols: [],
      listen: false,
      gpus: ['std', 'virtio', 'qxl'],
      uefi: true,
      secure_boot: true,
      tpm: true,
      usb: true,
      pci: true,
    },
    ...over,
  }
}

const err = (over: Partial<VirtError>): VirtError => ({ kind: 'unsupported', message: null, detail: null, cert: null, previous_fingerprint: null, ...over })

const GUEST: VirtGuest = {
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
}

function hostView(kind: 'pve' | 'libvirt' = 'pve'): VirtHostView {
  return {
    host: { kind, version: null, hypervisor: null, nodes: [{ name: 'pve', online: true, cpu: null, max_cpu: 8, mem_used: null, mem_total: null, uptime: null }] },
    guests: [GUEST],
    stats: {},
    capabilities: { lxc: true, pause: true, cluster: false },
  }
}

describe('hardware and settings: the helpers', () => {
  it('phrases every refusal of a hardware change, also as a host error', () => {
    const texts = HW_ISSUES.map((i) => hwIssueText(i))
    for (const t of texts) expect(t).toMatch(/\S/)
    expect(new Set(texts).size).toBeGreaterThan(HW_ISSUES.length - 3)
    for (const issue of HW_ISSUES) {
      expect(virtErrorText(err({ detail: { code: 'hardware_refused', issue } }))).toBe(hwIssueText(issue))
    }
  })

  it('says what a change came to', () => {
    expect(outcomeText(null)).toBe('Saved.')
    expect(outcomeText({ live_error: 'hotplug failed', volume_kept: false })).toMatch(/next start: hotplug failed/)
    expect(outcomeText({ live_error: null, volume_kept: true })).toMatch(/volume was kept/)
  })

  it('reads numbers as typed and sizes in GiB', () => {
    expect(num('')).toBeNull()
    expect(num(null)).toBeNull()
    expect(num('abc')).toBeNull()
    expect(num(4)).toBe(4)
    expect(num(' 2.5 ')).toBe(2.5)
    expect(gibBytes('10')).toBe(10 * 1024 ** 3)
    expect(gibBytes('')).toBeNull()
  })

  it('moves a boot entry within the list, never out of it', () => {
    expect(moveItem(['a', 'b', 'c'], 1, -1)).toEqual(['b', 'a', 'c'])
    expect(moveItem(['a', 'b', 'c'], 1, 1)).toEqual(['a', 'c', 'b'])
    const list = ['a', 'b']
    expect(moveItem(list, 0, -1)).toBe(list)
    expect(moveItem(list, 1, 1)).toBe(list)
    const h = hardware()
    const draft = bootDraft(h)
    expect(draft).toEqual([
      { key: 'scsi0', on: true },
      { key: 'ide2', on: true },
      { key: 'net0', on: false },
    ])
    draft[2].on = true
    expect(bootOrder(moveItem(draft, 2, -1))).toEqual(['scsi0', 'net0', 'ide2'])
  })

  it('builds CPU and memory changes: empty online is all, the balloon only where there is one', () => {
    const h = hardware()
    expect(cpuChange(cpuDraft(h))).toEqual({ op: 'set_cpu', sockets: 1, cores: 2, online: null, type: null })
    expect(cpuChange({ sockets: '2', cores: 4 as unknown as string, online: '6', type: 'host' })).toEqual({ op: 'set_cpu', sockets: 2, cores: 4, online: 6, type: 'host' })
    expect(memoryChange(memoryDraft(h), h)).toEqual({ op: 'set_memory', mib: 2048, min_mib: 1024, swap_mib: null })
    expect(memoryChange({ gib: '1.5', minGib: '', swapMib: '512' }, h)).toEqual({ op: 'set_memory', mib: 1536, min_mib: null, swap_mib: null })
    const ct = hardware({ kind: 'lxc', memory: { mib: 512, min_mib: null, balloon: false, swap_mib: 512 } })
    expect(memoryChange({ gib: '1', minGib: '0.5', swapMib: '256' }, ct)).toEqual({ op: 'set_memory', mib: 1024, min_mib: null, swap_mib: 256 })
  })

  it('sends only what changed of a disk, a NIC and the display', () => {
    const h = hardware()
    const disk = h.disks[0]
    expect(diskUpdate(disk, 'scsi', 'default')).toBeNull()
    expect(diskUpdate(disk, 'virtio', 'default')).toEqual({ op: 'update_disk', key: 'scsi0', bus: 'virtio', cache: null })
    expect(diskUpdate(disk, 'scsi', 'writeback')).toEqual({ op: 'update_disk', key: 'scsi0', bus: null, cache: 'writeback' })

    const nic = h.nics[0]
    const d = nicDraft(nic)
    expect(nicUpdate(nic, d)).toBeNull()
    expect(nicHardware(nic, d)).toBeNull()
    expect(nicUpdate(nic, { ...d, linkUp: false })).toEqual({ op: 'update_nic', key: 'net0', network: null, link_up: false, firewall: null })
    expect(nicUpdate(nic, { ...d, network: 'pve/vmbr1', firewall: false })).toEqual({ op: 'update_nic', key: 'net0', network: 'pve/vmbr1', link_up: true, firewall: false })
    // The same MAC in another case is no change.
    expect(nicHardware(nic, { ...d, mac: 'bc:24:11:00:00:01' })).toBeNull()
    expect(nicHardware(nic, { ...d, model: 'e1000', mac: ' 52:54:00:aa:bb:cc ' })).toEqual({ op: 'set_nic_hardware', key: 'net0', model: 'e1000', mac: '52:54:00:aa:bb:cc' })
    // libvirt has no firewall: never sent.
    const lv = { ...nic, firewall: null }
    expect(nicUpdate(lv, { ...nicDraft(lv), firewall: true, linkUp: false })).toMatchObject({ firewall: null })

    expect(displayChange(h, displayDraft(h))).toBeNull()
    expect(displayChange(h, { ...displayDraft(h), gpu: 'qxl' })).toEqual({ op: 'set_display', protocol: null, listen: null, gpu: 'qxl' })
  })

  it('builds a cloud-init edit from the read: a new password, or the one set kept or removed', () => {
    const state: VirtCloudInitState = {
      user: 'ubuntu',
      ssh_keys: ['ssh-ed25519 A'],
      hostname: 'box',
      address: '10.0.0.5/24',
      gateway: '10.0.0.1',
      dns: ['1.1.1.1'],
      search_domains: ['lan'],
      nics: 1,
      password_set: true,
      password_expires: false,
      network: true,
      foreign: false,
      revision: 'r1',
    }
    const d = ciDraft(state)
    expect(cloudInitEdit(d, state, 'libvirt')).toEqual({
      values: { user: 'ubuntu', ssh_keys: ['ssh-ed25519 A'], hostname: 'box', address: '10.0.0.5/24', gateway: '10.0.0.1', dns: ['1.1.1.1'], search_domains: ['lan'] },
      remove_password: false,
      password_expires: false,
      revision: 'r1',
    })
    const pve = cloudInitEdit({ ...d, password: 'secret', static: false, passwordExpires: true }, state, 'pve')
    expect(pve.values).toEqual({ user: 'ubuntu', password: 'secret', ssh_keys: ['ssh-ed25519 A'], dns: ['1.1.1.1'], search_domains: ['lan'] })
    expect(pve.password_expires).toBe(false)
    const removed = cloudInitEdit({ ...d, password: 'typed', removePassword: true }, state, 'libvirt')
    expect(removed.remove_password).toBe(true)
    expect(removed.values).not.toHaveProperty('password')
  })
})

describe('the hardware view', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    virtHardware.mockResolvedValue({ hardware: hardware(), error: null })
    createForm.mockResolvedValue({ form: null, error: null })
  })

  function show() {
    const onchanged = vi.fn()
    render(VirtHardware, { view: hostView(), guest: GUEST, sudoPassword: null, onchanged })
    return onchanged
  }

  it('sends a change with the revision it was read with, then reads again', async () => {
    virtHardwareChange.mockResolvedValue({ outcome: { live_error: 'CPU hotplug is off', volume_kept: false }, error: null })
    const onchanged = show()
    const cores = await screen.findByLabelText('Cores')
    const save = screen.getAllByRole('button', { name: /^save$/i })[0]
    expect(save).toBeDisabled()
    await fireEvent.input(cores, { target: { value: '4' } })
    expect(save).toBeEnabled()
    await fireEvent.click(save)
    await waitFor(() => expect(virtHardwareChange).toHaveBeenCalledWith('qemu/100', 'd1', { op: 'set_cpu', sockets: 1, cores: 4, online: null, type: null }, undefined))
    expect(await screen.findByText(/next start: CPU hotplug is off/)).toBeInTheDocument()
    expect(virtHardware).toHaveBeenCalledTimes(2)
    expect(onchanged).toHaveBeenCalled()
  })

  it('shows why the host refused, and reads again on a stale read', async () => {
    virtHardwareChange.mockResolvedValueOnce({ outcome: null, error: err({ detail: { code: 'hardware_refused', issue: 'cpu_count' } }) })
    show()
    await fireEvent.input(await screen.findByLabelText('Cores'), { target: { value: '64' } })
    await fireEvent.click(screen.getAllByRole('button', { name: /^save$/i })[0])
    expect(await screen.findByText(hwIssueText('cpu_count'))).toBeInTheDocument()
    expect(virtHardware).toHaveBeenCalledTimes(1)

    virtHardwareChange.mockResolvedValueOnce({ outcome: null, error: err({ kind: 'conflict', message: 'Read the hardware again' }) })
    virtHardware.mockResolvedValue({ hardware: hardware({ revision: 'd2' }), error: null })
    await fireEvent.input(screen.getByLabelText('Cores'), { target: { value: '3' } })
    await fireEvent.click(screen.getAllByRole('button', { name: /^save$/i })[0])
    expect(await screen.findByText(/changed since it was read/)).toBeInTheDocument()
    await waitFor(() => expect(virtHardware).toHaveBeenCalledTimes(2))
  })

  it('removes a disk only on the second click, with the volume as asked', async () => {
    virtHardwareChange.mockResolvedValue({ outcome: { live_error: null, volume_kept: true }, error: null })
    show()
    await fireEvent.click(await screen.findByRole('button', { name: /^scsi0/ }))
    await fireEvent.click(screen.getAllByRole('button', { name: /^remove$/i })[0])
    expect(virtHardwareChange).not.toHaveBeenCalled()
    await fireEvent.click(screen.getByLabelText('Also delete its volume'))
    await fireEvent.click(screen.getByRole('button', { name: /^confirm: remove scsi0$/i }))
    await waitFor(() => expect(virtHardwareChange).toHaveBeenCalledWith('qemu/100', 'd1', { op: 'remove_disk', key: 'scsi0', delete_volume: true }, undefined))
    expect(await screen.findByText(/volume was kept/)).toBeInTheDocument()
  })

  it('asks before changing the firmware', async () => {
    virtHardware.mockResolvedValue({ hardware: hardware({ running: false }), error: null })
    virtHardwareChange.mockResolvedValue({ outcome: null, error: err({ detail: { code: 'hardware_refused', issue: 'storage_missing' } }) })
    show()
    await fireEvent.click(await screen.findByRole('button', { name: 'UEFI' }))
    expect(screen.getByText(/unable to boot/)).toBeInTheDocument()
    expect(virtHardwareChange).not.toHaveBeenCalled()
  })

  it('lists pending changes and reverts them all on the second click', async () => {
    virtHardware.mockResolvedValue({ hardware: hardware({ pending: [{ key: 'cores', current: '2', pending: '4', delete: false }] }), error: null })
    virtHardwareRevert.mockResolvedValue({ error: null })
    show()
    expect(await screen.findByText(/2 → 4/)).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /^revert all$/i }))
    expect(virtHardwareRevert).not.toHaveBeenCalled()
    await fireEvent.click(screen.getByRole('button', { name: /^confirm: revert all$/i }))
    await waitFor(() => expect(virtHardwareRevert).toHaveBeenCalledWith('qemu/100', 'd1', undefined))
  })

  it('reverts one pending change on PVE', async () => {
    virtHardware.mockResolvedValue({ hardware: hardware({ pending: [{ key: 'cores', current: '2', pending: '4', delete: false }] }), error: null })
    virtHardwareChange.mockResolvedValue({ outcome: null, error: null })
    show()
    await fireEvent.click(await screen.findByRole('button', { name: /^revert$/i }))
    await waitFor(() => expect(virtHardwareChange).toHaveBeenCalledWith('qemu/100', 'd1', { op: 'revert', keys: ['cores'] }, undefined))
  })
})

describe('the settings view: general and cloud-init', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    cloneForm.mockResolvedValue({ storages: [], error: null })
  })

  const props = (kind: 'pve' | 'libvirt' = 'pve') => ({
    view: hostView(kind),
    guest: GUEST,
    sudoPassword: null,
    oncloned: () => {},
    ontemplated: () => {},
    ondeleted: () => {},
  })

  it('renames with the read\'s revision, and edits cloud-init on a VM with its drive', async () => {
    const withCi = hardware({ disks: [...hardware().disks, { key: 'ide0', kind: 'cdrom', source: 'local-lvm:vm-100-cloudinit', size: null, storage: null, mount_point: null, bus: 'ide', format: null, readonly: true, cache: null, cloud_init: true, resizable: false }] })
    virtHardware.mockResolvedValue({ hardware: withCi, error: null })
    virtHardwareChange.mockResolvedValue({ outcome: null, error: null })
    virtCloudInit.mockResolvedValue({
      cloud_init: { user: 'debian', ssh_keys: [], hostname: null, address: null, gateway: null, dns: [], search_domains: [], nics: 2, password_set: true, password_expires: false, network: true, foreign: false, revision: 'c1' },
      error: null,
    })
    virtSetCloudInit.mockResolvedValueOnce({ error: err({ kind: 'unsupported', detail: { code: 'create_refused', issue: 'ci_credentials' } }) })
    render(VirtManage, props())
    const name = await screen.findByDisplayValue('web')
    await fireEvent.input(name, { target: { value: 'web2' } })
    await fireEvent.click(screen.getAllByRole('button', { name: /^save$/i })[0])
    await waitFor(() => expect(virtHardwareChange).toHaveBeenCalledWith('qemu/100', 'd1', { op: 'set_name', name: 'web2' }, undefined))

    expect(await screen.findByText(/only the first is edited/)).toBeInTheDocument()
    await fireEvent.click(screen.getByLabelText('Remove the password'))
    const ciSave = screen.getAllByRole('button', { name: /^save$/i }).at(-1)!
    await fireEvent.click(ciSave)
    await waitFor(() =>
      expect(virtSetCloudInit).toHaveBeenCalledWith(
        'qemu/100',
        { values: { user: 'debian', ssh_keys: [], dns: [], search_domains: [] }, remove_password: true, password_expires: false, revision: 'c1' },
        undefined,
      ),
    )
    expect(await screen.findByText('cloud-init needs a password or an SSH key for the user.')).toBeInTheDocument()
  })

  it('says a PVE VM without a cloud-init drive has none, and toggles autostart', async () => {
    virtHardware.mockResolvedValue({ hardware: hardware(), error: null })
    virtHardwareChange.mockResolvedValue({ outcome: null, error: null })
    render(VirtManage, props())
    expect(await screen.findByText('This VM has no cloud-init drive.')).toBeInTheDocument()
    expect(virtCloudInit).not.toHaveBeenCalled()
    await fireEvent.click(screen.getByLabelText(/Starts with the host/))
    await waitFor(() => expect(virtHardwareChange).toHaveBeenCalledWith('qemu/100', 'd1', { op: 'set_autostart', on: true }, undefined))
  })

  it('says a libvirt guest has no seed of this app when the read refuses', async () => {
    virtHardware.mockResolvedValue({ hardware: hardware({ protection: null }), error: null })
    virtCloudInit.mockResolvedValue({ cloud_init: null, error: err({ kind: 'unsupported', message: 'web has no cloud-init seed of this app' }) })
    render(VirtManage, props('libvirt'))
    expect(await screen.findByText('This guest has no cloud-init seed made by this app.')).toBeInTheDocument()
    expect(screen.queryByText('Protection')).not.toBeInTheDocument()
  })
})
