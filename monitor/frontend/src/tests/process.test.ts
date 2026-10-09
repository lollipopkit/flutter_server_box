import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Process from '../desk/apps/process/ProcessApp.svelte'
import { api } from '../lib/api'
import { enabledFeatures } from '../lib/features'
import type { Capabilities, ProcessSignalResult, ProcessView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getProcess: vi.fn(), signalProcess: vi.fn() },
}))
const getProcess = vi.mocked(api.getProcess)
const signalProcess = vi.mocked(api.signalProcess)

const view = (): ProcessView =>
  ({
    available: true,
    reason_kind: null,
    reason: null,
    procs: [
      {
        pid: 4242,
        ppid: 1,
        user: 'www',
        cpu: 1.5,
        mem: 0.4,
        command: '/usr/sbin/nginx -g daemon off;',
        start_id: '777',
        name: 'nginx',
        rss_kb: 2048,
        is_kernel_thread: false,
        killable: true,
      },
    ],
    issue: null,
    load: null,
    sampled_at_millis: Date.now(),
    columns: { user: true, cpu: true, mem: true, rss: true, read: false, write: false, read_speed: false, write_speed: false },
    sorts: ['cpu', 'pid', 'name'],
    sort: 'cpu',
    ascending: false,
    signals: ['term', 'kill'],
  }) as unknown as ProcessView

const answer = (over: Partial<ProcessSignalResult>): ProcessSignalResult =>
  ({ outcome: 'failed', exit_code: 1, stdout: '', stderr: '', sudo_rejected: false, ...over }) as ProcessSignalResult

describe('Process page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getProcess.mockResolvedValue(view())
  })

  it('asks for a password when root needed one, and sends it on the retry', async () => {
    render(Process)
    // Select the row, then stop it from the status bar, which asks first.
    await fireEvent.click(await screen.findByText('nginx'))
    await fireEvent.click(await screen.findByRole('button', { name: /^stop$/i }))
    expect(screen.getByText(/Stop nginx \(4242\)\?/)).toBeInTheDocument()

    // The agent already tried `sudo -n`; that it wanted a password is a
    // question for the user, not a refused password.
    signalProcess.mockResolvedValueOnce(answer({ outcome: 'failed', sudo_rejected: true }))
    await fireEvent.click(screen.getByRole('button', { name: /SIGTERM/ }))
    const password = await screen.findByLabelText('Sudo password')
    expect(screen.queryByText(/refused that password/)).not.toBeInTheDocument()
    // Nothing to retry with until a password is typed.
    expect(screen.getByRole('button', { name: /retry as root/i })).toBeDisabled()

    signalProcess.mockResolvedValueOnce(answer({ outcome: 'succeeded', exit_code: 0 }))
    await fireEvent.input(password, { target: { value: 'hunter2' } })
    await fireEvent.click(screen.getByRole('button', { name: /retry as root/i }))
    await waitFor(() =>
      expect(signalProcess).toHaveBeenLastCalledWith(expect.objectContaining({ pid: 4242, start_id: '777', password: 'hunter2' })),
    )
  })
})

describe('enabledFeatures', () => {
  it('offers a page the agent serves and the role may use', () => {
    const caps = (features: string[], shell: boolean) =>
      ({ features, grants: { shell: { ok: shell } } }) as unknown as Capabilities
    expect(enabledFeatures(caps(['power', 'process'], true)).map((f) => f.id)).toEqual(['process'])
    expect(enabledFeatures(caps(['process'], false))).toEqual([])
    expect(enabledFeatures(caps(['power'], true))).toEqual([])
  })
})
