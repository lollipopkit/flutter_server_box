import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Virt from '../pages/Virt.svelte'
import { api } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import { enabledFeatures } from '../lib/features'
import { allocation, orderedActions, pushSample, pveDraft, virtErrorText, HISTORY_LEN } from '../lib/virt'
import type { Capabilities, VirtGuest, VirtLoad, VirtStats } from '../types'

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

  it('counts what runs, orders actions gentlest first, and keeps a bounded history', () => {
    const a = allocation([guest({}), guest({ id: 'b', state: 'stopped', vcpu: 4 }), guest({ id: 't', template: true, state: 'stopped' })])
    expect(a).toEqual({ running: 1, total: 2, vcpu: 2, mem: 2 * 1024 ** 3 })
    expect(orderedActions(guest({}))).toEqual(['shutdown', 'reboot', 'suspend', 'force_stop'])
    let h: VirtStats[] = []
    for (let i = 0; i < HISTORY_LEN + 5; i++) h = pushSample(h, stats(i, 1))
    expect(h).toHaveLength(HISTORY_LEN)
    expect(pushSample(h, stats(h.at(-1)!.at, 2))).toBe(h)
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
    virtDetail.mockResolvedValue({
      detail: {
        disks: [{ device: 'disk', source_type: null, source: 'local-lvm:vm-100-disk-0', target: 'scsi0', bus: 'scsi', format: null, readonly: false, size: 8 * 1024 ** 3 }],
        nics: [{ kind: 'net0', mac: 'BC:24:11:00:00:01', source: 'vmbr0', model: 'virtio', target: null }],
        graphics: [],
        display: null,
        consoles: ['vnc'],
        description: null,
        arch: null,
        machine: 'l26',
      },
      error: null,
    })
    render(Virt, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^hardware$/i }))
    expect(await screen.findByText(/local-lvm:vm-100-disk-0/)).toBeInTheDocument()
    expect(screen.getByText(/vmbr0/)).toBeInTheDocument()
    expect(virtDetail).toHaveBeenCalledWith('qemu/100', undefined)
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
})

