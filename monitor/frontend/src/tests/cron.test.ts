import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import Cron from '../pages/Cron.svelte'
import { api, ApiError } from '../lib/api'
import type { CronView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getCron: vi.fn(), editCron: vi.fn() },
}))
const getCron = vi.mocked(api.getCron)
const editCron = vi.mocked(api.editCron)

const view = (): CronView =>
  ({
    available: true,
    reason_kind: null,
    reason: null,
    user: 'sbm',
    now: '2026-10-02T10:00',
    jobs: [
      {
        line_index: 3,
        schedule: '0 3 * * *',
        command: '/usr/local/bin/backup',
        enabled: true,
        expansion: null,
        next_run: null,
      },
    ],
    preserved: [],
  }) as unknown as CronView

describe('Cron page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getCron.mockResolvedValue(view())
  })

  it('removes a job by the line its listing gave it', async () => {
    editCron.mockResolvedValue({ ...view(), jobs: [] })
    render(Cron, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /delete job/i }))
    await waitFor(() => expect(editCron).toHaveBeenCalledWith({ op: 'remove', line_index: 3 }))
  })

  it('reads the schedule again when the line moved under the page', async () => {
    editCron.mockRejectedValue(new ApiError('unknownLine', 400))
    render(Cron, { onback: () => {} })
    await fireEvent.click(await screen.findByRole('button', { name: /delete job/i }))
    expect(await screen.findByText(/no longer at that position/i)).toBeInTheDocument()
    await waitFor(() => expect(getCron).toHaveBeenCalledTimes(2))
  })
})
