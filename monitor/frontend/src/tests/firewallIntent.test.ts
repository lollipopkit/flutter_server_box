import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Firewall from '../desk/apps/firewall/FirewallApp.svelte'
import { parseAllowPorts } from '../desk/apps/firewall/intent'
import { WINDOW, type WindowHandle } from '../desk/sys/window.svelte'
import { WindowChrome } from '../desk/window/chrome.svelte'
import { api } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import { emptyDraft } from '../lib/firewall'
import type { Intent } from '../desk/windows.svelte'
import type { FirewallView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getFirewall: vi.fn(), planFirewall: vi.fn(), actFirewall: vi.fn() },
}))

const getFirewall = vi.mocked(api.getFirewall)
const planFirewall = vi.mocked(api.planFirewall)

const intent = (data: unknown, from = 'serverbox.sharing'): Intent => ({ action: 'allowPorts', data, from })

const ufwView: FirewallView = {
  available: true,
  reason_kind: null,
  reason: null,
  sudo_required: false,
  ufw_installed: true,
  firewalld_installed: null,
  kind: 'ufw',
  accesses: [],
  proxied: false,
  ufw: {
    active: true,
    status_line: 'Status: active',
    version: 'ufw 0.36.2',
    log_level: null,
    policies: {},
    rules: [],
    apps: [],
  },
}

function windowContext(intents: Intent[]): Map<unknown, unknown> {
  const chrome = new WindowChrome()
  chrome.deliver(...intents)
  const handle = {
    id: 'w1',
    appId: 'serverbox.firewall',
    appState: null,
    setAppState() {},
    setTitle() {},
    setAppName() {},
    setIcon() {},
    setBadge() {},
    close() {},
    open: () => null,
    openWindow: () => null,
    canOpenWindow: false,
    notify() {},
    handlers: () => [],
    storage: { get: async () => undefined, set: async () => {}, remove: async () => {}, keys: async () => [] },
    addPathIcon() {},
    active: true,
    closed: false,
    lifecycle: 'active',
    panes: null,
    chrome,
  } as unknown as WindowHandle
  return new Map([[WINDOW, handle]])
}

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't' }]
  servers.currentId = 'local'
  getFirewall.mockResolvedValue(structuredClone(ufwView))
})

describe('allowPorts intent', () => {
  it('accepts the valid shape from Sharing', () => {
    expect(parseAllowPorts(intent({ label: 'SMB', ports: [{ port: '445', protocol: 'tcp' }] }))).toEqual({
      label: 'SMB',
      ports: [{ port: '445', protocol: 'tcp' }],
    })
  })

  it('refuses another sender', () => {
    expect(parseAllowPorts(intent({ label: 'SMB', ports: [{ port: '445', protocol: 'tcp' }] }, 'serverbox.sharing.evil'))).toBeNull()
  })

  it('refuses invalid ports and more than eight ports', () => {
    expect(parseAllowPorts(intent({ label: 'SMB', ports: [{ port: 'abc', protocol: 'tcp' }] }))).toBeNull()
    expect(
      parseAllowPorts(
        intent({ label: 'SMB', ports: Array.from({ length: 9 }, () => ({ port: '445', protocol: 'tcp' })) }),
      ),
    ).toBeNull()
  })

  it('plans an incoming ufw allow rule for the requested port', async () => {
    planFirewall.mockResolvedValue({
      sudo_required: false,
      plan: {
        commands: ['ufw allow in proto tcp from any to any port 445 comment SMB'],
        effects: [],
        notes: [],
        destructive: false,
        confirm: false,
        keep_open: [],
        keep_open_default: false,
        countdown: false,
      },
      plan_id: 'p1',
    })

    render(Firewall, { context: windowContext([intent({ label: 'SMB', ports: [{ port: '445', protocol: 'tcp' }] })]) })

    const draft = { ...emptyDraft(), action: 'allow', direction: 'incoming', port: '445', protocol: 'tcp', comment: 'SMB' }
    await waitFor(() =>
      expect(planFirewall).toHaveBeenCalledWith({ kind: 'ufw', change: { type: 'add_rule', draft } }, undefined),
    )
    expect(api.actFirewall).not.toHaveBeenCalled()
    expect(await screen.findByRole('dialog')).toBeInTheDocument()
  })
})
