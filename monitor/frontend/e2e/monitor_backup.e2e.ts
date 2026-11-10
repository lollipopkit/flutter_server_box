/// Settings → Settings backup through the panel, against a real WebDAV
/// server: the folder tested and saved, a passphrase set, a backup made and
/// listed, then restored over a change (a wrong passphrase first).
/// `scripts/monitor-backup-e2e.sh` runs it with an agent and a WebDAV server
/// on this machine; by hand:
///
///     SBM_E2E_PANEL_URL=http://127.0.0.1:3790 SBM_E2E_PANEL_PASSWORD=… \
///     SBM_E2E_WEBDAV_URL=http://127.0.0.1:18080/panel-box/ SBM_E2E_WEBDAV_USER=… SBM_E2E_WEBDAV_PASSWORD=… \
///     SBM_E2E_BACKUP_PASSPHRASE=… SBM_E2E_BACKUP_DB=/path/to/agent.db \
///     npx playwright test monitor_backup
///
/// `SBM_E2E_BACKUP_DB` is the agent's database, which the test changes with
/// `sqlite3` between the backup and the restore (the snippet the script put
/// there goes, and must come back).

import { execFileSync } from 'node:child_process'
import { expect, test, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'
import { openApp } from './desk_app'
import { signIn } from './signin'

const env = process.env
const db = env.SBM_E2E_BACKUP_DB ?? ''
const passphrase = env.SBM_E2E_BACKUP_PASSPHRASE ?? ''

test.skip(
  !env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_WEBDAV_URL || !passphrase || !db,
  'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD, SBM_E2E_WEBDAV_URL, SBM_E2E_BACKUP_PASSPHRASE and SBM_E2E_BACKUP_DB are not set',
)

const sql = (query: string) => execFileSync('sqlite3', [db, query], { encoding: 'utf8' }).trim()

/// Answers the password dialog.
async function reauth(page: Page) {
  const field = page.locator('.lk-dialog input[autocomplete=current-password]').last()
  await fillSecret(field, env.SBM_E2E_PANEL_PASSWORD!)
  await submitForm(field)
  await expect(field).toHaveCount(0, { timeout: 60_000 })
}

test.setTimeout(5 * 60_000)

test('the monitor backs its settings up to WebDAV and restores them', async ({ page }) => {
  expect(sql("SELECT name FROM snippet WHERE id = 'e2e-backup'")).toBe('Backed up')
  await signIn(page)
  await openApp(page, 'serverbox.settings')
  await page.getByRole('button', { name: 'Settings backup' }).click()

  await test.step('the folder is tested and saved', async () => {
    await page.locator('#backup-url').fill(env.SBM_E2E_WEBDAV_URL!)
    await page.locator('#backup-user').fill(env.SBM_E2E_WEBDAV_USER ?? '')
    await fillSecret(page.locator('#backup-password'), env.SBM_E2E_WEBDAV_PASSWORD ?? '')
    await page.getByRole('button', { name: 'Test', exact: true }).click()
    await expect(page.getByText('Connected. The folder will be made on the first backup.')).toBeVisible({ timeout: 30_000 })
    await page.getByRole('button', { name: 'Save', exact: true }).click()
    await reauth(page)
    await expect(page.getByText('Saved.', { exact: true })).toBeVisible()
  })

  await test.step('a passphrase is set and a backup made', async () => {
    await page.getByRole('button', { name: 'Set passphrase' }).click()
    const d = page.locator('.lk-dialog').last()
    await fillSecret(d.locator('#backup-passphrase'), passphrase)
    await fillSecret(d.locator('#backup-passphrase-again'), passphrase)
    await submitForm(d.locator('#backup-passphrase'))
    await reauth(page)
    await expect(page.getByText('Passphrase set', { exact: true })).toBeVisible({ timeout: 60_000 })
    // Setting it backs up at once.
    await expect(page.getByText(/^Last backup /)).toBeVisible({ timeout: 60_000 })
    await expect(page.getByRole('button', { name: 'Restore' })).toHaveCount(1, { timeout: 30_000 })
  })

  sql("DELETE FROM snippet WHERE id = 'e2e-backup'")

  await test.step('a wrong passphrase is refused, the right one restores', async () => {
    await page.getByRole('button', { name: 'Restore' }).click()
    let d = page.locator('.lk-dialog').last()
    await fillSecret(d.locator('#backup-restore-passphrase'), `${passphrase} not`)
    await submitForm(d.locator('#backup-restore-passphrase'))
    await reauth(page)
    await expect(page.getByText('The passphrase does not open this backup.')).toBeVisible({ timeout: 60_000 })
    d = page.locator('.lk-dialog').last()
    await fillSecret(d.locator('#backup-restore-passphrase'), passphrase)
    await submitForm(d.locator('#backup-restore-passphrase'))
    await reauth(page)
    // The password is the backup's now: back at the sign-in screen, which
    // says so. No supervisor here: it says to restart rather than restarting.
    await expect(page.getByText('Restart the monitor to apply every setting. Sign in again with the password from the backup.')).toBeVisible({ timeout: 60_000 })
    await expect(page.locator('.lk-dock')).toHaveCount(0)
  })

  expect(sql("SELECT name FROM snippet WHERE id = 'e2e-backup'")).toBe('Backed up')
})
