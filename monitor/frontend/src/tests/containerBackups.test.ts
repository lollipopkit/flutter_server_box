import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import ContainerBackups from '../desk/apps/containers/ContainerBackups.svelte'
import { api } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import type { ContainerBackup } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    listContainerBackups: vi.fn(),
    restoreContainerBackup: vi.fn(),
    removeContainerBackup: vi.fn(),
    containerBackupJob: vi.fn(),
    cancelContainerBackupJob: vi.fn(),
  },
}))

const mocked = vi.mocked(api)

const backup: ContainerBackup = {
  id: '20261011-013000-sbm-futo-immich',
  label: 'sbm-futo-immich',
  created_at: '2026-10-11T01:30:00Z',
  created_by: 'admin',
  stopped: true,
  containers: [{ name: 'sbm-futo-immich-database-1', image: 'postgres:14', project: 'sbm-futo-immich' }],
  archives: [{ file: 'm1.tar.gz', container: 'sbm-futo-immich-database-1', mount: { kind: 'volume', name: 'pgdata', destination: '/var/lib/postgresql/data' }, bytes: 2048 }],
  skipped: [{ container: 'sbm-futo-immich-server-1', mount: { kind: 'bind', source: '/etc/localtime', destination: '/etc/localtime' }, why: 'notFolder' }],
}

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
  servers.currentId = 'local'
  mocked.listContainerBackups.mockResolvedValue({ backups: [backup], job: null })
})

describe('container backups', () => {
  it('say what each holds and left out, and restore with the password', async () => {
    const job = { id: 7, kind: 'restore' as const, state: 'running' as const, error: null, lines: [], next: 0 }
    mocked.restoreContainerBackup.mockResolvedValue(job)
    mocked.containerBackupJob.mockResolvedValue(job)
    render(ContainerBackups)
    expect(await screen.findByText('Volume pgdata → /var/lib/postgresql/data')).toBeInTheDocument()
    expect(screen.getByText('Left out: a file, not a folder')).toBeInTheDocument()
    expect(screen.getByText('Stopped while archived')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: 'Restore' }))
    const password = await vi.waitFor(() => document.querySelector('input[type=password]') as HTMLInputElement)
    await fireEvent.input(password, { target: { value: 'pw' } })
    await fireEvent.submit(password.form!)
    await vi.waitFor(() => expect(mocked.restoreContainerBackup).toHaveBeenCalledWith(backup.id, 'pw'))
    expect(await screen.findByText('Restoring…')).toBeInTheDocument()
  })
})
