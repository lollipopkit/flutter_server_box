import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Firewall from '../pages/Firewall.svelte'
import { ApiError, api } from '../lib/api'
import { refusalText } from '../lib/firewall'
import { servers } from '../lib/servers.svelte'
import type { FirewallPlan, FirewallView, FirewalldZone, UfwRule } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getFirewall: vi.fn(), planFirewall: vi.fn(), actFirewall: vi.fn() },
}))
const getFirewall = vi.mocked(api.getFirewall)
const planFirewall = vi.mocked(api.planFirewall)
const actFirewall = vi.mocked(api.actFirewall)

const ssh = { via: 'ssh' as const, port: 22, client: null, server: null, iface: null }

const sshRule: UfwRule = {
  action: 'allow',
  direction: 'incoming',
  routed: false,
  log: null,
  protocol: 'tcp',
  to: { address: null, port: '22', app: null },
  from: { address: null, port: null, app: null },
  interface_in: null,
  interface_out: null,
  comment: null,
  ip_version: 'v4',
  tuples: ['### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 in'],
}

const base: FirewallView = {
  available: true,
  reason_kind: null,
  reason: null,
  sudo_required: false,
  ufw_installed: true,
  firewalld_installed: null,
  kind: 'ufw',
  accesses: [{ ...ssh, reach: 'open', shut_by_reload: false }],
  proxied: true,
}

const ufwView = (): FirewallView => ({
  ...base,
  ufw: {
    active: true,
    status_line: 'Status: active',
    version: 'ufw 0.36.2',
    log_level: 'low',
    policies: { incoming: 'deny', outgoing: 'allow', routed: 'deny' },
    rules: [sshRule],
    apps: [],
  },
})

const zone = (name: string, extra: Partial<FirewalldZone> = {}): FirewalldZone => ({
  name,
  target: 'default_target',
  active: true,
  interfaces: [],
  sources: [],
  services: [],
  ports: [],
  forward_ports: [],
  rich_rules: [],
  masquerade: false,
  ...extra,
})

const firewalldView = (): FirewallView => {
  const zones = [zone('public', { interfaces: ['eth0'], services: ['ssh'] }), zone('block', { active: false })]
  return {
    ...base,
    ufw_installed: null,
    firewalld_installed: true,
    kind: 'firewalld',
    firewalld: {
      running: true,
      version: '2.1.1',
      default_zone: 'public',
      panic: false,
      runtime: zones,
      permanent: zones,
      services: {},
      service_names: ['http', 'ssh'],
      drifted: false,
      access_zones: ['public'],
    },
  }
}

const plan = (extra: Partial<FirewallPlan> = {}): FirewallPlan => ({
  commands: ['ufw --force delete 1'],
  effects: [],
  notes: [],
  destructive: true,
  confirm: true,
  keep_open: [],
  keep_open_default: false,
  countdown: false,
  ...extra,
})

/// The open add form's own button, among every list's add button.
const submitAdd = () =>
  screen.getAllByRole('button', { name: /^add$/i }).find((b) => b.getAttribute('type') === 'submit')!

const done = {
  succeeded: true,
  sudo_rejected: false,
  exit_code: 0,
  stderr: '',
  confirm_required: false,
  plan: null,
  plan_id: null,
}

describe('Firewall page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    actFirewall.mockResolvedValue(done)
  })
  afterEach(() => {
    vi.useRealTimers()
  })

  it('says why a machine has no firewall to show', async () => {
    getFirewall.mockResolvedValue({ ...base, available: false, reason_kind: 'unsupported_platform', kind: null })
    render(Firewall, { onback: () => {} })
    expect(await screen.findByText(/linux/i)).toBeInTheDocument()
  })

  it('asks for the sudo password and reads again with it', async () => {
    getFirewall.mockResolvedValueOnce({ ...base, available: false, sudo_required: true, kind: null })
    getFirewall.mockResolvedValueOnce(ufwView())
    render(Firewall, { onback: () => {} })
    await fireEvent.input(await screen.findByLabelText(/sudo password/i), { target: { value: 'hunter2' } })
    await fireEvent.click(screen.getByRole('button', { name: /^confirm$/i }))
    await waitFor(() => expect(getFirewall).toHaveBeenLastCalledWith(undefined, 'hunter2'))
    expect(await screen.findByText('ufw 0.36.2')).toBeInTheDocument()
  })

  it('deleting the rule that lets SSH in warns, counts down, and keeps SSH open first', async () => {
    getFirewall.mockResolvedValue(ufwView())
    planFirewall.mockResolvedValue({
      sudo_required: false,
      plan: plan({
        effects: [{ access: ssh, before: 'open', after: 'blocked', later: false, worse: true }],
        keep_open: ['ufw prepend allow in proto tcp from any to any port 22'],
        keep_open_default: true,
        countdown: true,
      }),
      plan_id: 'p1',
    })
    render(Firewall, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /delete rule/i }))
    const change = { kind: 'ufw', change: { type: 'delete_rule', tuples: sshRule.tuples } }
    expect(planFirewall).toHaveBeenCalledWith(change, undefined)

    expect(await screen.findByText(/SSH \(port 22\): new connections will be refused/)).toBeInTheDocument()
    expect(screen.getByRole('checkbox', { name: /keep these ports open first/i })).toBeChecked()
    // Nothing runs until the countdown is over and the user confirms.
    const confirm = screen.getByRole('button', { name: /confirm \(3\)/i })
    expect(confirm).toBeDisabled()
    expect(actFirewall).not.toHaveBeenCalled()
    await waitFor(() => expect(screen.getByRole('button', { name: /^confirm$/i })).toBeEnabled(), {
      timeout: 4000,
    })
    await fireEvent.click(screen.getByRole('button', { name: /^confirm$/i }))
    await waitFor(() => expect(actFirewall).toHaveBeenCalledWith(change, true, undefined, 'p1'))
  })

  it('a change that makes nothing worse runs without asking', async () => {
    getFirewall.mockResolvedValue(firewalldView())
    planFirewall.mockResolvedValue({
      sudo_required: false,
      plan: plan({ confirm: false, destructive: false }),
      plan_id: 'p0',
    })
    render(Firewall, { onback: () => {} })
    const add = await screen.findAllByRole('button', { name: /^add$/i })
    // Services is the third list.
    await fireEvent.click(add[2])
    await fireEvent.click(submitAdd())
    const change = { kind: 'firewalld', change: { type: 'add', zone: 'public', item: 'service', value: 'http' } }
    await waitFor(() => expect(actFirewall).toHaveBeenCalledWith(change, false, undefined, undefined))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('a plan the firewall outgrew is shown again, and only its own id runs it', async () => {
    getFirewall.mockResolvedValue(ufwView())
    planFirewall.mockResolvedValue({ sudo_required: false, plan: plan({ commands: ['ufw reload'] }), plan_id: 'old' })
    actFirewall.mockResolvedValueOnce({
      ...done,
      succeeded: false,
      confirm_required: true,
      plan: plan({
        commands: ['ufw reload'],
        effects: [{ access: ssh, before: 'open', after: 'blocked', later: false, worse: true }],
      }),
      plan_id: 'new',
    })
    render(Firewall, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^reload$/i }))
    await fireEvent.click(await screen.findByRole('button', { name: /^confirm$/i }))
    const change = { kind: 'ufw', change: { type: 'reload' } }
    await waitFor(() => expect(actFirewall).toHaveBeenCalledWith(change, false, undefined, 'old'))
    // Nothing ran; the plan as it is now is asked about instead.
    expect(await screen.findByText(/SSH \(port 22\): new connections will be refused/)).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: /^confirm$/i }))
    await waitFor(() => expect(actFirewall).toHaveBeenLastCalledWith(change, false, undefined, 'new'))
  })

  it('a plan answered after the server changed leads to nothing', async () => {
    getFirewall.mockResolvedValue(ufwView())
    let answer: (v: Awaited<ReturnType<typeof api.planFirewall>>) => void = () => {}
    planFirewall.mockReturnValue(new Promise((resolve) => (answer = resolve)))
    render(Firewall, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /^reload$/i }))
    servers.add('https://another.example')
    answer({ sudo_required: false, plan: plan({ confirm: false }), plan_id: 'p' })
    await new Promise((r) => setTimeout(r, 50))
    expect(actFirewall).not.toHaveBeenCalled()
  })

  it('a value the agent refuses is said in the viewer language', async () => {
    getFirewall.mockResolvedValue(firewalldView())
    planFirewall.mockRejectedValue(
      new ApiError('invalidInput', 400, undefined, {
        error: 'invalidInput',
        issue: { code: 'input', issue: 'invalid_source' },
      }),
    )
    render(Firewall, { onback: () => {} })
    const add = await screen.findAllByRole('button', { name: /^add$/i })
    await fireEvent.click(add[1])
    await fireEvent.input(screen.getByRole('textbox', { name: /sources/i }), { target: { value: 'not an address' } })
    await fireEvent.click(submitAdd())
    await waitFor(() => expect(planFirewall).toHaveBeenCalled())
    expect(await screen.findByText(/invalid source/i)).toBeInTheDocument()
    expect(actFirewall).not.toHaveBeenCalled()
  })
})

describe('firewall refusals', () => {
  it('a code this build does not know is shown as sent', () => {
    expect(refusalText('somethingNew')).toBe('somethingNew')
    expect(refusalText('noSuchRule')).toMatch(/no longer there/)
  })
})
