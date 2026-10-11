/// The Sharing app on a real machine, through the panel: Samba and the NFS
/// server installed where missing, an SMB share added, made read only and
/// removed, an account's SMB password set, an NFS export added and removed.
/// It changes ServerBox's own share files only (`/etc/samba/serverbox.conf`,
/// `/etc/exports.d/serverbox.exports`).
///
///     SBM_E2E_PANEL_URL=http://127.0.0.1:3770 SBM_E2E_PANEL_USER=admin \
///     SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_SHARE_FOLDER=/srv/share SBM_E2E_SHARE_ACCOUNT=alice \
///     npx playwright test sharing
///
/// The folder must exist; the account is optional (its SMB password is set
/// to a random one).

import { expect, test, type Page } from '@playwright/test'

const env = process.env
const folder = env.SBM_E2E_SHARE_FOLDER ?? ''
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''

test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !folder, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_SHARE_FOLDER are not set')

async function open(page: Page) {
  await page.goto('/')
  await page.getByPlaceholder('Username').fill(env.SBM_E2E_PANEL_USER ?? 'admin')
  await page.locator('input[type=password]').fill(env.SBM_E2E_PANEL_PASSWORD!)
  await page.keyboard.press('Enter')
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.getByText('Sharing', { exact: true }).first().click()
  await expect(page.getByText('SMB', { exact: true }).first()).toBeVisible({ timeout: 30_000 })
}

/// Installs [what] from the app when it is missing; the job must succeed.
async function installIfMissing(page: Page, what: string) {
  const button = page.getByRole('button', { name: what })
  await expect(page.getByText('Service', { exact: true }).or(button)).toBeVisible({ timeout: 30_000 })
  if (!(await button.count())) return
  await button.click()
  await confirm(page, what)
  await expect(page.getByText('Installing…')).toBeHidden({ timeout: 15 * 60_000 })
  await expect(page.getByText('Did not finish', { exact: true })).toHaveCount(0)
  await expect(page.getByText('Service', { exact: true })).toBeVisible({ timeout: 30_000 })
}

/// Answers the sudo dialog with [title] and waits for it to close.
async function confirm(page: Page, title: string) {
  const d = page.locator('.lk-dialog').last()
  await d.getByLabel(/sudo password/).fill(sudo)
  await d.getByRole('button', { name: title, exact: true }).click()
  await expect(page.locator('.lk-dialog')).toHaveCount(0, { timeout: 60_000 })
}

/// The group titled [title].
const group = (page: Page, title: string) => page.locator('.lk-group, section').filter({ has: page.getByText(title, { exact: true }) }).last()

test('the Sharing app manages SMB shares and NFS exports', async ({ page }) => {
  await open(page)

  await test.step('an SMB share is added, made read only and removed', async () => {
    await installIfMissing(page, 'Install Samba')
    await page.getByRole('button', { name: 'Add share' }).click()
    const d = page.locator('.lk-dialog').last()
    await d.getByLabel('Name').fill('sbme2e')
    await d.getByLabel(/^Folder/).fill(folder)
    await d.getByRole('button', { name: 'Continue' }).click()
    await confirm(page, 'Save')
    await expect(page.getByText('sbme2e', { exact: true })).toBeVisible()
    await group(page, 'sbme2e').getByRole('button', { name: 'Edit' }).click()
    await page.locator('.lk-dialog').last().locator('.lk-check', { hasText: 'Read only' }).click()
    await page.locator('.lk-dialog').last().getByRole('button', { name: 'Continue' }).click()
    await confirm(page, 'Save')
    await expect(group(page, 'sbme2e').getByText(/^Read only/)).toBeVisible()
    await group(page, 'sbme2e').getByRole('button', { name: 'Remove' }).click()
    await confirm(page, 'Remove')
    await expect(page.getByText('sbme2e', { exact: true })).toHaveCount(0)
  })

  if (env.SBM_E2E_SHARE_ACCOUNT) {
    await test.step('an account\'s SMB password is set', async () => {
      const account = env.SBM_E2E_SHARE_ACCOUNT!
      const passwords = group(page, 'SMB passwords')
      const pick = passwords.locator('select')
      if (await pick.count()) await pick.selectOption(account)
      else await passwords.getByLabel('Account').fill(account)
      await passwords.getByRole('button', { name: 'Set password' }).click()
      const secret = `e2e-${Math.random().toString(36).slice(2)}`
      const d = page.locator('.lk-dialog').last()
      await d.getByLabel('New SMB password').fill(secret)
      await d.getByLabel('The same again').fill(secret)
      await d.getByRole('button', { name: 'Continue' }).click()
      await confirm(page, 'Set password')
    })
  }

  await test.step('an NFS export is added and removed', async () => {
    await page.getByText('NFS', { exact: true }).first().click()
    await installIfMissing(page, 'Install NFS server')
    await page.getByRole('button', { name: 'Add export' }).click()
    const d = page.locator('.lk-dialog').last()
    await d.getByLabel(/^Folder/).fill(folder)
    await d.getByRole('textbox', { name: 'Client' }).fill('192.168.77.0/24')
    await d.getByRole('button', { name: 'Continue' }).click()
    await confirm(page, 'Save')
    const exported = group(page, folder)
    await expect(exported.getByText('192.168.77.0/24', { exact: true })).toBeVisible()
    await exported.getByRole('button', { name: 'Remove' }).click()
    await confirm(page, 'Remove')
    await expect(page.getByText('192.168.77.0/24', { exact: true })).toHaveCount(0)
  })
})
