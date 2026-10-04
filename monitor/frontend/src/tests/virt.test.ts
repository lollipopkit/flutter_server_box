import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Virt from '../pages/Virt.svelte'
import { api } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import { enabledFeatures } from '../lib/features'
import { allocation, createIssueText, createSpec, issueText, lines, orderedActions, pushSample, pveDraft, refText, snapshotTree, virtErrorText, words, HISTORY_LEN, type CreateDraft } from '../lib/virt'
import type { Capabilities, VirtCreateForm, VirtCreateIssue, VirtCreateOptions, VirtGuest, VirtLoad, VirtNetwork, VirtPool, VirtSnapshot, VirtStats } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    loadVirt: vi.fn(),
    virtPower: vi.fn(),
    getPve: vi.fn(),
    setPve: vi.fn(),
    removePve: vi.fn(),
    pinPve: vi.fn(),
    pveTfa: vi.fn(),
    virtDetail: vi.fn(),
    virtHistory: vi.fn(),
    virtConsole: vi.fn(),
    virtSnapshots: vi.fn(),
    virtSnapshot: vi.fn(),
    virtSnapshotDiff: vi.fn(),
    virtStorage: vi.fn(),
    virtVolumes: vi.fn(),
    virtNetworks: vi.fn(),
    virtManage: vi.fn(),
    createForm: vi.fn(),
    createGuest: vi.fn(),
    deleteGuest: vi.fn(),
    cloneForm: vi.fn(),
    cloneGuest: vi.fn(),
    makeTemplate: vi.fn(),
    virtHardware: vi.fn(),
    virtHardwareChange: vi.fn(),
    virtHardwareRevert: vi.fn(),
    virtCloudInit: vi.fn(),
    virtSetCloudInit: vi.fn(),
    virtHostDevices: vi.fn(),
  },
}))
const loadVirt = vi.mocked(api.loadVirt)
const virtPower = vi.mocked(api.virtPower)
const getPve = vi.mocked(api.getPve)
const pinPve = vi.mocked(api.pinPve)
const pveTfa = vi.mocked(api.pveTfa)
const virtDetail = vi.mocked(api.virtDetail)
const virtConsole = vi.mocked(api.virtConsole)
const virtHistory = vi.mocked(api.virtHistory)
const virtSnapshots = vi.mocked(api.virtSnapshots)
const virtSnapshot = vi.mocked(api.virtSnapshot)
const virtStorage = vi.mocked(api.virtStorage)
const virtVolumes = vi.mocked(api.virtVolumes)
const virtNetworks = vi.mocked(api.virtNetworks)
const virtManage = vi.mocked(api.virtManage)
const createForm = vi.mocked(api.createForm)
const createGuest = vi.mocked(api.createGuest)
const deleteGuest = vi.mocked(api.deleteGuest)
const cloneForm = vi.mocked(api.cloneForm)
const cloneGuest = vi.mocked(api.cloneGuest)
const makeTemplate = vi.mocked(api.makeTemplate)
const virtHardware = vi.mocked(api.virtHardware)

function guest(over: Partial<VirtGuest>): VirtGuest {
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
    uptime: 3600,
    tags: ['prod'],
    template: false,
    autostart: null,
    actions: ['shutdown', 'reboot', 'force_stop', 'suspend'],
    ...over,
  }
}

const stats = (at: number, cpu: number): VirtStats => ({
  at,
  cpu,
  mem_used: 1024 ** 3,
  mem_total: 2 * 1024 ** 3,
  disk_used: null,
  disk_total: null,
  disk_read: 0,
  disk_write: 0,
  net_in: 1000,
  net_out: 0,
})

function loaded(guests: VirtGuest[]): VirtLoad {
  return {
    host: 'pve',
    supported: true,
    pve_configured: true,
    view: {
      host: { kind: 'pve', version: '9.2.2', hypervisor: null, nodes: [{ name: 'pve', online: true, cpu: 0.1, max_cpu: 8, mem_used: null, mem_total: 16 * 1024 ** 3, uptime: null }] },
      guests,
      stats: { 'qemu/100': stats(1_000, 25) },
      capabilities: { lxc: true, pause: true, cluster: false },
    },
    error: null,
  }
}

const failed = (error: VirtLoad['error']): VirtLoad => ({
  host: 'pve',
  supported: true,
  pve_configured: true,
  view: null,
  error,
})

function asAdmin(admin: boolean) {
  for (const entry of [...servers.list]) servers.remove(entry.id)
  servers.add('https://agent.example')
  servers.login('token', 'admin')
  capabilitiesStore.byServer[servers.currentId!] = { me: { admin } } as unknown as Capabilities
}

describe('the virtualization helpers', () => {
  it('offers the page to a role with virt on an agent that serves it', () => {
    const caps = (features: string[], virt: boolean) =>
      ({ features, grants: { virt: { ok: virt } } }) as unknown as Capabilities
    expect(enabledFeatures(caps(['virt', 'bmc'], true)).map((f) => f.id)).toEqual(['virt', 'bmc'])
    expect(enabledFeatures(caps(['virt'], false))).toEqual([])
  })

  it('phrases what the panel has to say itself, and adds the host’s words', () => {
    const e = virtErrorText({
      kind: 'permission_denied',
      message: null,
      detail: { code: 'no_privileges', token: true, account: 'root@pam!sb', command: "pveum acl modify / --tokens 'root@pam!sb'" },
      cert: null,
      previous_fingerprint: null,
    })
    expect(e).toContain("pveum acl modify / --tokens 'root@pam!sb'")
    const host = virtErrorText({ kind: 'action_failed', message: "can't lock file", detail: null, cert: null, previous_fingerprint: null })
    expect(host).toMatch(/refused the action\.\ncan't lock file/)
  })

  it('phrases a refused storage or network change', () => {
    const refused = (detail: NonNullable<Parameters<typeof virtErrorText>[0]['detail']>) =>
      virtErrorText({ kind: 'unsupported', message: null, detail, cert: null, previous_fingerprint: null })
    expect(refused({ code: 'refused', issue: 'in_use' })).toBe(issueText('in_use'))
    expect(issueText('management_iface')).toMatch(/management traffic/)
    expect(refused({ code: 'apply_touches_management', ifaces: ['vmbr0', 'nic0'] })).toContain('vmbr0, nic0')
    expect(
      refused({
        code: 'needs_privilege',
        account: 'root@pam!sb',
        privilege: 'Sys.Modify',
        path: '/nodes/pve',
        command: 'pveum role add ServerBox-SysModify --privs Sys.Modify',
      }),
    ).toContain('pveum role add ServerBox-SysModify')
    const g = [guest({})]
    expect(refText({ guest_id: null, vmid: 100, device: 'net0', mac: null, ip: null }, g)).toBe('web (net0)')
    expect(refText({ guest_id: 'gone', vmid: null, device: null, mac: null, ip: null }, g)).toBe('gone')
  })

  it('counts what runs, orders actions gentlest first, and keeps a bounded history', () => {
    const a = allocation([guest({}), guest({ id: 'b', state: 'stopped', vcpu: 4 }), guest({ id: 't', template: true, state: 'stopped' })])
    expect(a).toEqual({ running: 1, total: 2, vcpu: 2, mem: 2 * 1024 ** 3 })
    expect(orderedActions(guest({}))).toEqual(['shutdown', 'reboot', 'suspend', 'force_stop'])
    let h: VirtStats[] = []
    for (let i = 0; i < HISTORY_LEN + 5; i++) h = pushSample(h, stats(i, 1))
    expect(h).toHaveLength(HISTORY_LEN)
    expect(pushSample(h, stats(h.at(-1)!.at, 2))).toBe(h)
  })

  it('draws snapshots as a tree, oldest sibling first, orphans as roots', () => {
    const snap = (name: string, parent: string | null, at: number | null): VirtSnapshot => ({
      name, parent, description: null, created_at: at, current: false, with_memory: false, external: false, layers: [],
    })
    const order = snapshotTree([snap('b', 'a', 3), snap('a', null, 1), snap('c', 'a', 2), snap('x', 'gone', null)])
    expect(order.map(([s, d]) => `${s.name}:${d}`)).toEqual(['a:0', 'c:1', 'b:1', 'x:0'])
  })

  it('drafts the form with every secret kept', () => {
    const draft = pveDraft({
      configured: true,
      addr: 'https://127.0.0.1:8006',
      auth: 'token',
      username: null,
      has_password: false,
      token_id: 'root@pam!sb',
      has_token_secret: true,
      cert_sha256: 'ab',
      editable: true,
    })
    expect(draft).toMatchObject({ token_id: 'root@pam!sb', token_secret: null, password: null, cert_sha256: 'ab' })
  })
})

describe('the virtualization page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    asAdmin(true)
    getPve.mockResolvedValue({
      configured: true,
      addr: 'https://127.0.0.1:8006',
      auth: 'token',
      username: null,
      has_password: false,
      token_id: 'root@pam!sb',
      has_token_secret: true,
      cert_sha256: null,
      editable: true,
    })
  })

  it('lists the guests and shows the selected one with the actions it offers', async () => {
    loadVirt.mockResolvedValue(loaded([guest({}), guest({ id: 'qemu/101', name: 'db', vmid: 101, state: 'stopped', actions: ['start'] })]))
    render(Virt, { onback: () => {} })
    expect(await screen.findByText('db')).toBeInTheDocument()
    expect(screen.getAllByText('web').length).toBeGreaterThan(0)
    expect(screen.getByRole('button', { name: /force stop/i })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^resume$/i })).not.toBeInTheDocument()
    expect(screen.getByText('25.0%')).toBeInTheDocument()

    await fireEvent.click(screen.getByText('db'))
    // In the header and on the stopped card.
    expect(await screen.findAllByRole('button', { name: /^start$/i })).toHaveLength(2)
    expect(screen.getByText('Usage shows here once it runs.')).toBeInTheDocument()
  })

  it('asks before stopping, then sends it and reads the host again', async () => {
    loadVirt.mockResolvedValue(loaded([guest({})]))
    virtPower.mockResolvedValue({ error: null })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /force stop/i }))
    expect(virtPower).not.toHaveBeenCalled()
    expect(screen.getByText(/pulling the plug/)).toBeInTheDocument()
    const buttons = screen.getAllByRole('button', { name: /force stop/i })
    await fireEvent.click(buttons[buttons.length - 1])
    await waitFor(() => expect(virtPower).toHaveBeenCalledWith('qemu/100', 'force_stop', undefined))
    await waitFor(() => expect(loadVirt).toHaveBeenCalledTimes(2))
  })

  it('shows an unconfirmed certificate and lets an admin trust it', async () => {
    loadVirt.mockResolvedValueOnce(
      failed({
        kind: 'cert_unconfirmed',
        message: null,
        detail: null,
        cert: { fingerprint: 'abcd', subject: '/CN=pve', issuer: '/CN=pve', not_before: 0, not_after: 4_102_444_800 },
        previous_fingerprint: null,
      }),
    )
    loadVirt.mockResolvedValue(loaded([guest({})]))
    pinPve.mockResolvedValue({ error: null })
    render(Virt, { onback: () => {} })
    expect(await screen.findByText('AB:CD')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /trust this certificate/i }))
    await waitFor(() => expect(pinPve).toHaveBeenCalledWith('abcd'))
    expect(await screen.findByText('Certificate trusted.')).toBeInTheDocument()
  })

  it('does not offer a viewer to trust a certificate', async () => {
    asAdmin(false)
    loadVirt.mockResolvedValue(
      failed({ kind: 'cert_changed', message: null, detail: null, cert: { fingerprint: 'abcd', subject: '', issuer: '', not_before: 0, not_after: 0 }, previous_fingerprint: 'ef01' }),
    )
    render(Virt, { onback: () => {} })
    expect(await screen.findByText('EF:01')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /trust this certificate/i })).not.toBeInTheDocument()
    expect(screen.getByText(/An admin has to trust/)).toBeInTheDocument()
  })

  it('sends a TOTP code, then reads the host', async () => {
    loadVirt.mockResolvedValueOnce(failed({ kind: 'need_tfa', message: null, detail: { code: 'otp_required' }, cert: null, previous_fingerprint: null }))
    loadVirt.mockResolvedValue(loaded([guest({})]))
    pveTfa.mockResolvedValue({ error: null })
    render(Virt, { onback: () => {} })
    const code = await screen.findByPlaceholderText('123456')
    await fireEvent.input(code, { target: { value: '654321' } })
    await fireEvent.click(screen.getByRole('button', { name: /sign in/i }))
    await waitFor(() => expect(pveTfa).toHaveBeenCalledWith('654321'))
    await waitFor(() => expect(loadVirt).toHaveBeenCalledTimes(2))
  })

  it('asks a refused libvirt for the sudo password and sends it with every request', async () => {
    loadVirt.mockResolvedValueOnce({
      host: 'libvirt',
      supported: true,
      pve_configured: false,
      view: null,
      error: { kind: 'sudo_password_required', message: null, detail: null, cert: null, previous_fingerprint: null },
    })
    loadVirt.mockResolvedValue(loaded([guest({})]))
    render(Virt, { onback: () => {} })
    const field = await screen.findByPlaceholderText('sudo password')
    await fireEvent.input(field, { target: { value: 'hunter2' } })
    await fireEvent.click(screen.getByRole('button', { name: /^use$/i }))
    await waitFor(() => expect(loadVirt).toHaveBeenLastCalledWith('hunter2'))
  })

  it('tells an admin that PVE runs here and has to be set up', async () => {
    loadVirt.mockResolvedValue({ host: 'pve', supported: true, pve_configured: false, view: null, error: null })
    render(Virt, { onback: () => {} })
    expect(await screen.findByText(/Set up how this agent signs in/)).toBeInTheDocument()
  })

  it('reads a guest\'s hardware when its view opens', async () => {
    loadVirt.mockResolvedValue(loaded([guest({})]))
    createForm.mockResolvedValue({ form: null, error: null })
    virtHardware.mockResolvedValue({
      hardware: {
        kind: 'qemu',
        running: true,
        cpu: { sockets: 1, cores: 2, threads: 1, online: null, type: null },
        memory: { mib: 2048, min_mib: null, balloon: false, swap_mib: null },
        disks: [{ key: 'scsi0', kind: 'disk', source: 'local-lvm:vm-100-disk-0', size: 8 * 1024 ** 3, storage: 'local-lvm', mount_point: null, bus: 'scsi', format: 'raw', readonly: false, cache: null, cloud_init: false, resizable: true }],
        nics: [{ key: 'net0', mac: 'BC:24:11:00:00:01', type: null, source: 'vmbr0', model: 'virtio', link_up: true, firewall: true, name: null }],
        boot: ['scsi0'],
        autostart: false,
        name: 'web',
        description: null,
        protection: false,
        rename_running: true,
        pending: [],
        revision: 'd1',
        limits: { host_cpus: 8, host_memory_bytes: null },
        cpu_types: [],
        config_text: null,
        firmware: null,
        display: null,
        devices: [],
        support: { buses: [], caches: [], nic_models: [], mac: false, protocols: [], listen: false, gpus: [], uefi: false, secure_boot: false, tpm: false, usb: false, pci: false },
      },
      error: null,
    })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^hardware$/i }))
    await fireEvent.click(await screen.findByRole('button', { name: /^scsi0/ }))
    expect(await screen.findByText(/local-lvm:vm-100-disk-0/)).toBeInTheDocument()
    expect(screen.getAllByText(/vmbr0/).length).toBeGreaterThan(0)
    expect(virtHardware).toHaveBeenCalledWith('qemu/100', undefined)
  })

  it('shows what to run for a libvirt serial console', async () => {
    loadVirt.mockResolvedValue({ ...loaded([guest({ id: 'uuid-1', vmid: null, node: null })]), host: 'libvirt' })
    virtDetail.mockResolvedValue({
      detail: { disks: [], nics: [], graphics: [], display: null, consoles: ['text'], description: null, arch: null, machine: null },
      error: null,
    })
    virtConsole.mockResolvedValue({ ticket: null, vnc_password: null, password_known: true, command: "virsh --connect qemu:///system console --force --domain 'uuid-1'", error: null })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^console$/i }))
    await fireEvent.click(await screen.findByRole('button', { name: /^open$/i }))
    expect(await screen.findByText(/console --force --domain 'uuid-1'/)).toBeInTheDocument()
    expect(virtConsole).toHaveBeenCalledWith('uuid-1', 'text', undefined)
  })

  it('reads what PVE stored for a range', async () => {
    const view = loaded([guest({})])
    view.view!.capabilities.stored_history = true
    loadVirt.mockResolvedValue(view)
    virtHistory.mockResolvedValue({ history: [stats(1, 10), stats(2, 20)], error: null })
    // The chart sizes itself to its box; jsdom has no layout to observe.
    vi.stubGlobal('ResizeObserver', class { observe() {} unobserve() {} disconnect() {} })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^day$/i }))
    await waitFor(() => expect(virtHistory).toHaveBeenCalledWith('qemu/100', 'day'))
    vi.unstubAllGlobals()
  })

  it('takes a snapshot with what the host says the memory may be, and asks before a revert', async () => {
    const view = loaded([guest({})])
    view.view!.capabilities.snapshots = true
    loadVirt.mockResolvedValue(view)
    virtSnapshots.mockResolvedValue({
      snapshots: [{ name: 'pre-up', parent: null, description: 'before', created_at: 1790000000, current: true, with_memory: false, external: false, layers: [] }],
      memory: 'optional',
      refusal: null,
      chain: null,
      error: null,
    })
    virtSnapshot.mockResolvedValue({ error: null })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^snapshots$/i }))
    expect(await screen.findByText('pre-up')).toBeInTheDocument()
    await fireEvent.input(screen.getByPlaceholderText('Name'), { target: { value: 'pre-down' } })
    await fireEvent.click(screen.getByRole('button', { name: /take snapshot/i }))
    await waitFor(() =>
      expect(virtSnapshot).toHaveBeenCalledWith(
        'qemu/100',
        { op: 'create', name: 'pre-down', description: null, memory: true, external: false, pool: null },
        undefined,
      ),
    )
    await fireEvent.click(screen.getAllByRole('button', { name: /^revert$/i })[0])
    expect(screen.getByText(/disks go back to then/)).toBeInTheDocument()
    expect(virtSnapshot).toHaveBeenCalledTimes(1)
    // The dialog closes and the revert it asked about is the one sent.
    const reverts = screen.getAllByRole('button', { name: /^revert$/i })
    await fireEvent.click(reverts[reverts.length - 1])
    await waitFor(() => expect(virtSnapshot).toHaveBeenLastCalledWith('qemu/100', { op: 'revert', name: 'pre-up', start: false }, undefined))
  })

  it('says why a snapshot cannot be taken, instead of the form', async () => {
    const view = loaded([guest({})])
    view.view!.capabilities.snapshots = true
    loadVirt.mockResolvedValue(view)
    virtSnapshots.mockResolvedValue({ snapshots: [], memory: 'optional', refusal: 'snapshot feature is not available: local', chain: null, error: null })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^snapshots$/i }))
    expect(await screen.findByText(/not available: local/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /take snapshot/i })).not.toBeInTheDocument()
  })
})


describe('the virtualization page: storage and networks', () => {
  const pool = (over: Partial<VirtPool>): VirtPool => ({
    id: 'pve/local',
    name: 'local',
    node: 'pve',
    type: 'dir',
    path: '/var/lib/vz',
    source: null,
    capacity: 1000,
    used: 400,
    available: 600,
    active: true,
    autostart: null,
    enabled: true,
    shared: false,
    content: ['images', 'iso'],
    volume_count: null,
    ...over,
  })
  const net = (over: Partial<VirtNetwork>): VirtNetwork => ({
    id: 'pve/vmbr0',
    name: 'vmbr0',
    node: 'pve',
    mode: 'bridge',
    bridge: null,
    cidrs: ['192.168.31.20/24'],
    gateway: '192.168.31.1',
    dhcp_ranges: [],
    ports: ['nic0'],
    vlan_aware: null,
    vlan_id: null,
    vlan_device: null,
    bond_mode: null,
    active: true,
    autostart: true,
    comment: null,
    hosts: [],
    xml: '',
    pending_restart: false,
    management_editable: false,
    users: [{ guest_id: 'qemu/100', vmid: 100, device: 'net0', mac: null, ip: null }],
    ...over,
  })

  function withResources(): VirtLoad {
    const view = loaded([guest({})])
    Object.assign(view.view!.capabilities, {
      storage: true,
      network: true,
      storage_edit: true,
      network_edit: true,
      pool_types: ['dir', 'nfs'],
      network_modes: ['bridge'],
    })
    return view
  }

  beforeEach(() => {
    vi.clearAllMocks()
    asAdmin(true)
    getPve.mockResolvedValue({
      configured: true,
      addr: 'https://127.0.0.1:8006',
      auth: 'token',
      username: null,
      has_password: false,
      token_id: 'root@pam!sb',
      has_token_secret: true,
      cert_sha256: null,
      editable: true,
    })
    loadVirt.mockResolvedValue(withResources())
  })

  it('lists the pools and a pool\'s volumes with who uses them, and says why a delete is refused', async () => {
    virtStorage.mockResolvedValue({ pools: [pool({})], rules: { 'pve/local': { formats: ['qcow2', 'raw'], resizable: false } }, error: null })
    virtVolumes.mockResolvedValue({
      volumes: [
        {
          id: 'local:100/vm-100-disk-0.qcow2',
          name: 'vm-100-disk-0.qcow2',
          path: null,
          format: 'qcow2',
          content: 'images',
          capacity: 8 * 1024 ** 3,
          allocation: null,
          backing: null,
          created_at: null,
          users: [{ guest_id: null, vmid: 100, device: null, mac: null, ip: null }],
          backs: [],
        },
      ],
      error: null,
    })
    virtManage.mockResolvedValue({
      error: { kind: 'unsupported', message: null, detail: { code: 'refused', issue: 'in_use' }, cert: null, previous_fingerprint: null },
    })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^storage$/i }))
    expect(await screen.findByText('vm-100-disk-0.qcow2')).toBeInTheDocument()
    expect(virtVolumes).toHaveBeenCalledWith('pve/local', undefined)
    expect(screen.getByText(/Used by web/)).toBeInTheDocument()
    const deletes = screen.getAllByRole('button').filter((b) => b.querySelector('.lucide-trash-2'))
    await fireEvent.click(deletes[deletes.length - 1])
    await fireEvent.click(screen.getByRole('button', { name: /^delete$/i }))
    await waitFor(() =>
      expect(virtManage).toHaveBeenCalledWith({ op: 'volume_delete', pool: 'pve/local', volume: 'local:100/vm-100-disk-0.qcow2' }, undefined),
    )
    expect(await screen.findByText(issueText('in_use'))).toBeInTheDocument()
  })

  it('shows a node\'s pending changes, keeps the management bridge locked, and asks before applying', async () => {
    virtNetworks.mockResolvedValue({
      networks: [net({}), net({ id: 'pve/vmbr9', name: 'vmbr9', cidrs: [], gateway: null, ports: [], users: [], management_editable: true })],
      changes: [{ node: 'pve', diff: '--- a\n+++ b\n+auto vmbr9\n' }],
      error: null,
    })
    virtManage.mockResolvedValue({ error: null })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^networks$/i }))
    expect(await screen.findByText('vmbr9')).toBeInTheDocument()
    // Only the bridge of its own is editable.
    expect(screen.getAllByRole('button', { name: /^edit$/i })).toHaveLength(1)
    expect(screen.getByText(/Pending changes on pve/)).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /^apply$/i }))
    expect(virtManage).not.toHaveBeenCalled()
    expect(screen.getByText(/reloads its networking/)).toBeInTheDocument()
    const applies = screen.getAllByRole('button', { name: /^apply$/i })
    await fireEvent.click(applies[applies.length - 1])
    await waitFor(() => expect(virtManage).toHaveBeenCalledWith({ op: 'network_apply', node: 'pve' }, undefined))
  })
})

const CREATE_ISSUES: VirtCreateIssue[] = [
  'name_empty', 'name_invalid', 'name_taken', 'vmid_invalid', 'vmid_taken', 'node', 'cores', 'memory', 'storage',
  'disk_size', 'template', 'media', 'credentials', 'password', 'ssh_keys', 'image', 'image_size', 'network',
  'secure_boot', 'not_offered', 'ci_user', 'ci_credentials', 'ci_hostname', 'ci_address', 'ci_gateway', 'ci_dns',
  'ci_search', 'clone_linked_target', 'clone_storage', 'clone_storage_content', 'clone_storage_shared',
  'clone_node_unknown', 'not_stopped', 'is_template', 'not_found', 'unsupported',
]

const OPTIONS: VirtCreateOptions = {
  buses: ['virtio', 'scsi'],
  nic_models: ['virtio', 'e1000e'],
  uefi: true,
  tpm: true,
  secure_boot: true,
  cloud_images: true,
  cloud_init: true,
  cloud_init_missing: null,
}

function draft(over: Partial<CreateDraft>): CreateDraft {
  return {
    kind: 'qemu',
    name: ' web ',
    node: 'pve',
    vmid: '105',
    cores: '2',
    memoryGib: '1.5',
    storage: 'pve/local-lvm',
    diskGib: '32',
    source: 'media',
    media: 'pve/local\nlocal:iso/debian.iso',
    image: 'pve/local\nlocal:import/noble.qcow2',
    network: 'pve/vmbr0',
    password: '',
    sshKeys: '',
    unprivileged: true,
    bus: 'scsi',
    nicModel: 'virtio',
    uefi: true,
    secureBoot: true,
    tpm: false,
    ci: { user: '', password: '', sshKeys: '', hostname: '', static: false, address: '', gateway: '', dns: '', search: '' },
    start: true,
    ...over,
  }
}

describe('creating, copying and deleting guests: the helpers', () => {
  it('phrases every refusal of a create, clone, delete or template', () => {
    const texts = CREATE_ISSUES.map((issue) => createIssueText(issue))
    for (const t of texts) expect(t).toMatch(/\S/)
    expect(new Set(texts).size).toBeGreaterThan(CREATE_ISSUES.length - 3)
    for (const issue of CREATE_ISSUES) {
      const kind = issue === 'name_taken' || issue === 'vmid_taken' ? 'exists' : 'unsupported'
      expect(virtErrorText({ kind, message: null, detail: { code: 'create_refused', issue }, cert: null, previous_fingerprint: null })).toBe(
        createIssueText(issue),
      )
    }
    expect(createIssueText('secure_boot')).toMatch(/UEFI/)
  })

  it('splits keys by line and lists by spaces or commas', () => {
    expect(lines(' ssh-ed25519 A a@b \r\n\n  ssh-rsa B  \n')).toEqual(['ssh-ed25519 A a@b', 'ssh-rsa B'])
    expect(words(' 1.1.1.1, 9.9.9.9  lan ')).toEqual(['1.1.1.1', '9.9.9.9', 'lan'])
  })

  it('builds a PVE VM from install media: trimmed, its media by pool and volume, MiB from GiB', () => {
    const spec = createSpec(draft({}), 'pve', OPTIONS)
    expect(spec).toEqual({
      kind: 'qemu',
      name: 'web',
      node: 'pve',
      vmid: 105,
      cores: 2,
      memory_mib: 1536,
      storage: 'pve/local-lvm',
      disk_gib: 32,
      media: { pool: 'pve/local', volume: 'local:iso/debian.iso' },
      network: 'pve/vmbr0',
      ssh_keys: [],
      unprivileged: true,
      bus: 'scsi',
      nic_model: 'virtio',
      uefi: true,
      secure_boot: true,
      tpm: false,
      start: true,
    })
    // An empty VMID takes the next free one; no network, no Secure Boot without UEFI.
    const bare = createSpec(draft({ vmid: '', network: '', uefi: false }), 'pve', OPTIONS)
    expect(bare).not.toHaveProperty('vmid')
    expect(bare).not.toHaveProperty('network')
    expect(bare.secure_boot).toBe(false)
  })

  it('builds a VM from a cloud image without its media, cloud-init only when something is typed', () => {
    const plain = createSpec(draft({ source: 'image' }), 'libvirt', OPTIONS)
    expect(plain.image).toEqual({ pool: 'pve/local', volume: 'local:import/noble.qcow2' })
    expect(plain).not.toHaveProperty('media')
    expect(plain).not.toHaveProperty('cloud_init')
    // libvirt has no node or VMID.
    expect(plain).not.toHaveProperty('node')
    expect(plain).not.toHaveProperty('vmid')

    const ci = { user: ' ubuntu ', password: '', sshKeys: 'ssh-ed25519 A\n', hostname: ' box ', static: true, address: '10.0.0.5/24 ', gateway: '', dns: '1.1.1.1 9.9.9.9', search: '' }
    expect(createSpec(draft({ source: 'image', ci }), 'libvirt', OPTIONS).cloud_init).toEqual({
      user: 'ubuntu',
      ssh_keys: ['ssh-ed25519 A'],
      hostname: 'box',
      address: '10.0.0.5/24',
      dns: ['1.1.1.1', '9.9.9.9'],
      search_domains: [],
    })
    // PVE names the guest itself; DHCP sends no address.
    const pve = createSpec(draft({ source: 'image', ci: { ...ci, static: false } }), 'pve', OPTIONS).cloud_init
    expect(pve).not.toHaveProperty('hostname')
    expect(pve).not.toHaveProperty('address')
    // Not offered: install media, no cloud-init.
    const off = createSpec(draft({ source: 'image', ci }), 'pve', { ...OPTIONS, cloud_images: false })
    expect(off.media).toBeDefined()
    expect(off).not.toHaveProperty('image')
    expect(off).not.toHaveProperty('cloud_init')
  })

  it('builds a container: its template, root login, no VM hardware', () => {
    const spec = createSpec(
      draft({ kind: 'lxc', media: 'pve/local\nlocal:vztmpl/debian-12.tar.zst', password: 'secret1', sshKeys: 'ssh-ed25519 A\n\nssh-rsa B', unprivileged: false }),
      'pve',
      OPTIONS,
    )
    expect(spec).toMatchObject({
      kind: 'lxc',
      media: { pool: 'pve/local', volume: 'local:vztmpl/debian-12.tar.zst' },
      password: 'secret1',
      ssh_keys: ['ssh-ed25519 A', 'ssh-rsa B'],
      unprivileged: false,
      uefi: false,
      secure_boot: false,
      tpm: false,
    })
    expect(spec).not.toHaveProperty('bus')
    expect(spec).not.toHaveProperty('nic_model')
    expect(createSpec(draft({ kind: 'lxc' }), 'pve', OPTIONS)).not.toHaveProperty('password')
  })
})

describe('the virtualization page: creating, copying and deleting', () => {
  const form = (): VirtCreateForm => ({
    options: OPTIONS,
    next_vmid: 105,
    storages: [
      { id: 'pve/local-lvm', name: 'local-lvm', node: 'pve', type: 'lvmthin', path: null, source: null, capacity: null, used: null, available: 100 * 1024 ** 3, active: true, autostart: null, enabled: true, shared: false, content: ['images'], volume_count: null },
    ],
    networks: [],
    media: [
      {
        pool: 'pve/local',
        volume: { id: 'local:iso/debian.iso', name: 'debian.iso', path: null, format: 'iso', content: 'iso', capacity: null, allocation: null, backing: null, created_at: null, users: [], backs: [] },
      },
    ],
    images: [],
  })

  function withCreate(guests: VirtGuest[]): VirtLoad {
    const view = loaded(guests)
    Object.assign(view.view!.capabilities, { create: true, clone: true, template: true, linked_clone: true, clone_target: true })
    return view
  }

  beforeEach(() => {
    vi.clearAllMocks()
    asAdmin(false)
    createForm.mockResolvedValue({ form: form(), error: null })
    cloneForm.mockResolvedValue({ storages: [], error: null })
    virtHardware.mockResolvedValue({ hardware: null, error: null })
  })

  it('creates a VM from the form, says why the host refused, then selects the new guest', async () => {
    loadVirt.mockResolvedValue(withCreate([guest({})]))
    createGuest.mockResolvedValueOnce({
      created: null,
      error: { kind: 'exists', message: null, detail: { code: 'create_refused', issue: 'vmid_taken' }, cert: null, previous_fingerprint: null },
    })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^new$/i }))
    expect(await screen.findByText('debian.iso')).toBeInTheDocument()
    expect(createForm).toHaveBeenCalledWith('qemu', 'pve', undefined)
    const submit = screen.getByRole('button', { name: /^create vm$/i })
    await fireEvent.click(submit)
    await waitFor(() => expect(createGuest).toHaveBeenCalledTimes(1))
    const [spec] = createGuest.mock.calls[0]
    expect(spec).toMatchObject({
      kind: 'qemu',
      name: 'vm-105',
      node: 'pve',
      vmid: 105,
      storage: 'pve/local-lvm',
      media: { pool: 'pve/local', volume: 'local:iso/debian.iso' },
      bus: 'virtio',
      start: true,
    })
    expect(await screen.findByText(createIssueText('vmid_taken'))).toBeInTheDocument()

    createGuest.mockResolvedValueOnce({ created: { id: 'qemu/105', start_error: 'kvm: no space', disk_kept_bytes: null }, error: null })
    loadVirt.mockResolvedValue(withCreate([guest({}), guest({ id: 'qemu/105', name: 'vm-105', vmid: 105, state: 'stopped' })]))
    await fireEvent.click(screen.getByRole('button', { name: /^create vm$/i }))
    expect(await screen.findByText(/did not start: kvm: no space/)).toBeInTheDocument()
    await waitFor(() => expect(screen.getByRole('button', { current: true })).toHaveTextContent('vm-105'))
  })

  it('deletes a stopped guest only on the second click, and clones with the name it was given', async () => {
    loadVirt.mockResolvedValue(withCreate([guest({ state: 'stopped', actions: ['start'] })]))
    deleteGuest.mockResolvedValue({ error: null })
    cloneGuest.mockResolvedValue({ id: 'qemu/106', error: null })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^settings$/i }))
    await fireEvent.click(await screen.findByRole('button', { name: /^delete guest$/i }))
    expect(deleteGuest).not.toHaveBeenCalled()
    await fireEvent.click(screen.getByRole('button', { name: /^confirm: delete web$/i }))
    await waitFor(() => expect(deleteGuest).toHaveBeenCalledWith('qemu/100', true, undefined))
    expect(await screen.findByText('Deleted web.')).toBeInTheDocument()

    await fireEvent.click(screen.getByRole('button', { name: /^settings$/i }))
    await fireEvent.click(await screen.findByRole('button', { name: /^clone$/i }))
    await waitFor(() => expect(cloneGuest).toHaveBeenCalledWith('qemu/100', { name: 'web-clone', full: true }, undefined))
    expect(makeTemplate).not.toHaveBeenCalled()
  })

  it('keeps delete closed while the guest runs', async () => {
    loadVirt.mockResolvedValue(withCreate([guest({})]))
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^settings$/i }))
    expect(await screen.findByRole('button', { name: /^delete guest$/i })).toBeDisabled()
    expect(screen.getAllByText('Shut it down first.').length).toBeGreaterThan(0)
  })
})
