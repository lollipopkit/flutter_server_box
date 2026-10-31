import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import MonitorBackupSection from '../desk/apps/settings/MonitorBackupSection.svelte'
import { api, errorFromBody } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import { noticeText } from '../desk/noticeText'
import en from '../i18n/en'
import { i18nObject } from '../i18n/i18n-util'
import { loadAllLocales } from '../i18n/i18n-util.sync'
import type { MonitorBackupFile, MonitorBackupView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    getMonitorBackup: vi.fn(),
    saveMonitorBackup: vi.fn(),
    testMonitorBackup: vi.fn(),
    setMonitorBackupKey: vi.fn(),
    runMonitorBackup: vi.fn(),
    listMonitorBackups: vi.fn(),
    restoreMonitorBackup: vi.fn(),
  },
}))

const mocked = vi.mocked(api)

const view: MonitorBackupView = {
  configured: true,
  url: 'https://dav.example.com/box/',
  username: 'me',
  has_password: true,
  allow_insecure: false,
  enabled: true,
  keep: 10,
  key_id: '0a1b2c3d',
  last_backup_at: '2026-10-21T10:15:00Z',
  last_name: 'serverbox-monitor-20261021T101500.000Z-0a1b2c3d.tar.gz.age',
  last_error: 'webdav.unauthorized',
  last_error_at: '2026-10-21T10:25:00Z',
  running: false,
  max_bytes: 100 << 20,
  min_passphrase: 12,
}

const file: MonitorBackupFile = { name: view.last_name!, size: 4096, created_at: '2026-10-21T10:15:00Z', key_id: '0a1b2c3d', instance: '5e6f7a8b', own: true, current_key: true }
const theirs: MonitorBackupFile = { ...file, name: 'serverbox-monitor-ffffffff-20260101T000000.000Z-aaaaaaaa.tar.gz.age', key_id: 'aaaaaaaa', instance: 'ffffffff', own: false, current_key: false }

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't' }]
  servers.currentId = 'local'
  mocked.getMonitorBackup.mockResolvedValue(view)
  mocked.listMonitorBackups.mockResolvedValue({ backups: [file, theirs] })
})

async function submitPassword(value: string) {
  const field = await vi.waitFor(() => {
    const f = [...document.querySelectorAll('input[autocomplete=current-password]')].at(-1) as HTMLInputElement | undefined
    if (!f) throw new Error('no password field')
    return f
  })
  await fireEvent.input(field, { target: { value } })
  await fireEvent.submit(field.form!)
}

describe('monitor backup', () => {
  it('shows the folder, the key, the last failure in words, and the backups', async () => {
    render(MonitorBackupSection)
    expect(await screen.findByDisplayValue('https://dav.example.com/box/')).toBeInTheDocument()
    expect(screen.getByText('Backups are encrypted to key 0a1b2c3d.')).toBeInTheDocument()
    expect(screen.getByText('The WebDAV server refused the user name or password.')).toBeInTheDocument()
    expect((await screen.findAllByText(/ · 0a1b2c3d$/)).length).toBe(1)
    expect(screen.getByText('Another server')).toBeInTheDocument()
  })

  it('saves with the password and keeps the saved WebDAV password unsent', async () => {
    mocked.saveMonitorBackup.mockResolvedValue(view)
    render(MonitorBackupSection)
    await screen.findByDisplayValue('https://dav.example.com/box/')
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))
    await submitPassword('pw')
    await vi.waitFor(() =>
      expect(mocked.saveMonitorBackup).toHaveBeenCalledWith(
        { url: 'https://dav.example.com/box/', username: 'me', allow_insecure: false, enabled: true, keep: 10 },
        'pw',
      ),
    )
  })

  it('says a refusal of the change in the form, and can forget the saved WebDAV password', async () => {
    mocked.saveMonitorBackup.mockRejectedValueOnce(errorFromBody(400, { error: 'passwordRequired' }))
    mocked.saveMonitorBackup.mockResolvedValueOnce({ ...view, has_password: false })
    render(MonitorBackupSection)
    await screen.findByDisplayValue('https://dav.example.com/box/')
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))
    await submitPassword('pw')
    expect(await screen.findByText('Type the password: the saved one is only sent to the server it was saved for.')).toBeInTheDocument()
    await vi.waitFor(() => expect(document.querySelector('input[autocomplete=current-password]')).toBeNull())
    await fireEvent.click(screen.getByText('Remove the saved password'))
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))
    await submitPassword('pw')
    await vi.waitFor(() => expect(mocked.saveMonitorBackup).toHaveBeenLastCalledWith(expect.objectContaining({ password: '' }), 'pw'))
  })

  it('offers no run while backups are off', async () => {
    mocked.getMonitorBackup.mockResolvedValue({ ...view, enabled: false })
    render(MonitorBackupSection)
    expect(await screen.findByText('Automatic backups are off.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Back up now' })).toBeDisabled()
  })

  it('sets a passphrase only when it is long enough and typed twice', async () => {
    mocked.setMonitorBackupKey.mockResolvedValue(view)
    render(MonitorBackupSection)
    await fireEvent.click(await screen.findByRole('button', { name: 'Change passphrase' }))
    const [first, again] = [...document.querySelectorAll('input[autocomplete=new-password]')].slice(-2) as HTMLInputElement[]
    await fireEvent.input(first, { target: { value: 'short' } })
    expect(screen.getByText('At least 12 characters.')).toBeInTheDocument()
    await fireEvent.input(first, { target: { value: 'a long enough passphrase' } })
    await fireEvent.input(again, { target: { value: 'a long enough passphrase' } })
    await fireEvent.submit(first.form!)
    await submitPassword('pw')
    await vi.waitFor(() => expect(mocked.setMonitorBackupKey).toHaveBeenCalledWith('a long enough passphrase', 'pw'))
  })

  it('restores with the passphrase and the password, and asks the passphrase again when it is wrong', async () => {
    mocked.restoreMonitorBackup.mockRejectedValueOnce(errorFromBody(400, { error: 'wrongPassphrase' }))
    mocked.restoreMonitorBackup.mockResolvedValueOnce({ restored: { tables: [], blobs: 0, config: true }, restart: true })
    render(MonitorBackupSection)
    await fireEvent.click((await screen.findAllByRole('button', { name: 'Restore' }))[0])
    const passphrase = document.querySelector('#backup-restore-passphrase') as HTMLInputElement
    await fireEvent.input(passphrase, { target: { value: 'wrong passphrase' } })
    await fireEvent.submit(passphrase.form!)
    await submitPassword('pw')
    expect(await screen.findByText('The passphrase does not open this backup.')).toBeInTheDocument()
    const again = document.querySelector('#backup-restore-passphrase') as HTMLInputElement
    await fireEvent.input(again, { target: { value: 'right passphrase' } })
    await fireEvent.submit(again.form!)
    await submitPassword('pw')
    await vi.waitFor(() => expect(mocked.restoreMonitorBackup).toHaveBeenLastCalledWith(file.name, 'right passphrase', 'pw'))
    // The session is over; the sign-in screen says why.
    await vi.waitFor(() => expect(servers.list[0].token).toBeNull())
    expect(servers.notices.local).toBe('The monitor is restarting. Sign in again with the password from the backup.')
  })

  it('words its notices in the reader language', () => {
    loadAllLocales()
    const zh = i18nObject('zh-CN')
    const n = { id: 1, created_at: '', level: 'warning' as const, source: 'backup', subject: 'Settings backup failed', body: '', read: false, kind: 'backup.failed', params: { error: 'keyMissing' } }
    expect(noticeText(n, zh, 'zh-CN')).toEqual({ subject: '设置备份失败', body: '文件夹中没有这份备份的密钥，无法打开。' })
    expect(noticeText({ ...n, kind: 'backup.back', params: {} }, i18nObject('en'), 'en').subject).toBe(en.noticeMonitorBackupBack)
  })
})
