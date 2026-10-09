import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Bmc from '../desk/apps/bmc/BmcApp.svelte'
import { api, ApiError } from '../lib/api'
import { bmcErrorText, keepPasswords, prettyFingerprint } from '../lib/bmc'
import { enabledFeatures } from '../lib/features'
import type { BmcStatus, BmcTarget, Capabilities } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getBmc: vi.fn(), updateBmc: vi.fn(), probeBmc: vi.fn(), bmcStatus: vi.fn(), bmcPower: vi.fn() },
}))
const getBmc = vi.mocked(api.getBmc)
const updateBmc = vi.mocked(api.updateBmc)
const bmcStatus = vi.mocked(api.bmcStatus)
const bmcPower = vi.mocked(api.bmcPower)

const rack: BmcTarget = {
  id: 't1',
  name: 'rack-1',
  url: 'https://10.0.0.9',
  username: 'admin',
  has_password: true,
  cert_sha256: 'ab'.repeat(32),
}

const status: BmcStatus = {
  snapshot: {
    topology: {
      root: { product: null, vendor: null, version: '1.6.0' },
      system: {
        power_state: 'on',
        model: 'R740',
        manufacturer: 'Dell',
        serial: 'S1',
        bios_version: '2.1',
        health: 'OK',
      },
      has_multiple_systems: false,
    },
    sensors: { temperatures: [{ name: 'Inlet', value: 21, unit: '°C' }], fans: [], watts: 180 },
    sensors_truncated: false,
  },
  intents: ['gracefulShutdown', 'forceOff'],
}

describe('the BMC helpers', () => {
  it('offers the page to a role with virt on an agent that serves it', () => {
    const caps = (features: string[], virt: boolean) =>
      ({ features, grants: { virt: { ok: virt } } }) as unknown as Capabilities
    expect(enabledFeatures(caps(['bmc'], true)).map((f) => f.id)).toEqual(['bmc'])
    expect(enabledFeatures(caps(['bmc'], false))).toEqual([])
  })

  it('phrases the BMC failure the agent passes on, not its 502', () => {
    const e = new ApiError('bmc', 502, undefined, { error: 'bmc', failure: 'unauthorized', detail: null })
    expect(bmcErrorText(e)).toMatch(/user name or password/)
    const odd = new ApiError('bmc', 502, undefined, { error: 'bmc', failure: 'somethingNew', detail: 'x' })
    expect(bmcErrorText(odd)).toBe('somethingNew: x')
  })

  it('keeps every stored password on a write and shows a fingerprint as a console does', () => {
    expect(keepPasswords([rack])[0]).toEqual({
      id: 't1',
      name: 'rack-1',
      url: 'https://10.0.0.9',
      username: 'admin',
      password: null,
      cert_sha256: rack.cert_sha256,
    })
    expect(prettyFingerprint('abcd12')).toBe('AB:CD:12')
  })
})

describe('the BMC page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getBmc.mockResolvedValue({ targets: [rack], editable: true })
    bmcStatus.mockResolvedValue(status)
  })
  afterEach(() => vi.useRealTimers())

  it('shows the selected target’s state and offers only the actions it answers', async () => {
    render(Bmc)
    expect(await screen.findByText('R740')).toBeInTheDocument()
    expect(screen.getByText('On')).toBeInTheDocument()
    expect(screen.getByText('180 W')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /force off/i })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /power cycle/i })).not.toBeInTheDocument()
  })

  it('asks before a power action and then sends it', async () => {
    bmcPower.mockResolvedValue({ outcome: { kind: 'done' } })
    render(Bmc)
    await fireEvent.click(await screen.findByRole('button', { name: /force off/i }))
    expect(bmcPower).not.toHaveBeenCalled()
    const buttons = screen.getAllByRole('button', { name: /force off/i })
    await fireEvent.click(buttons[buttons.length - 1])
    await waitFor(() => expect(bmcPower).toHaveBeenCalledWith('t1', 'forceOff'))
  })

  it('removes a target by sending the set without it, passwords kept', async () => {
    updateBmc.mockResolvedValue({ targets: [], editable: true })
    render(Bmc)
    await screen.findByText('R740')
    await fireEvent.click(screen.getByRole('button', { name: /remove bmc/i }))
    const confirm = screen.getAllByRole('button', { name: /remove bmc/i })
    await fireEvent.click(confirm[confirm.length - 1])
    await waitFor(() => expect(updateBmc).toHaveBeenCalledWith([]))
  })
})
