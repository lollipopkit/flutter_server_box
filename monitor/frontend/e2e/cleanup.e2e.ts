/// The Cleanup app on a throwaway machine, through the panel: a scan finds
/// what `scripts/desk-vm-e2e.sh <node> cleanup` left there (a downloaded
/// package, one nothing needs, old logs, a crash report, the account's trash
/// and caches, a removed web app's folder with a file of root's), they are
/// chosen and cleaned, and the scan that follows finds none of them.
///
///     SBM_E2E_PANEL_URL=https://192.168.31.231:3770 SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_CLEANUP=1 npx playwright test cleanup

import { expect, test, type Page } from '@playwright/test'
import { fillSecret } from './secret'
import { signIn } from './signin'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_CLEANUP, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_CLEANUP are not set')

/// What the run made, as the app names it.
const MADE = ['Downloaded packages', 'Packages nothing needs', 'Old logs', 'Crash reports', 'Trash', '~/.cache/sbm-e2e-app', 'npm cache', 'sbm.leftover']

async function open(page: Page) {
  await signIn(page)
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.locator('.apps-panel .apps-panel-app').filter({ has: page.getByText('Cleanup', { exact: true }) }).click()
}

const row = (page: Page, label: string) =>
  page.locator('.lk-setrow').filter({ has: page.locator('.lk-setrow__label').getByText(label, { exact: true }) })

/// Answers the sudo dialog with [button] and waits for the job to end well:
/// a clean says Done; a scan shows what it found.
async function confirm(page: Page, button: string, typed?: string) {
  const d = page.locator('.lk-dialog').last()
  if (typed) await d.locator('input:not([type=password])').first().fill(typed)
  await fillSecret(d.getByLabel(/sudo password/), sudo)
  await d.getByRole('button', { name: button, exact: true }).click()
  await expect(page.locator('.lk-dialog')).toHaveCount(0, { timeout: 60_000 })
  await expect(page.getByText(/^(Scanning|Cleaning)…$/)).toHaveCount(0, { timeout: 15 * 60_000 })
  await expect(page.getByText('Did not finish', { exact: true })).toHaveCount(0)
}

test('the Cleanup app finds junk and removes it', async ({ page }) => {
  test.setTimeout(30 * 60_000)
  await open(page)

  await test.step('a scan finds what was made', async () => {
    await page.getByRole('button', { name: 'Scan', exact: true }).first().click()
    await confirm(page, 'Scan')
    await expect(row(page, 'Can go')).toBeVisible()
    for (const label of MADE) await expect(row(page, label), label).toBeVisible({ timeout: 60_000 })
    await expect(row(page, 'sbm.leftover')).toContainText(/MiB/)
  })

  await test.step('chosen and cleaned, the next scan finds none of it', async () => {
    for (const label of MADE) {
      // The box drawn over the input is what a person clicks.
      await row(page, label).locator('.lk-check__box').click()
      await expect(row(page, label).getByRole('checkbox')).toBeChecked()
    }
    await page.getByRole('button', { name: 'Clean…' }).click()
    const title = await page.locator('.lk-dialog').last().getByRole('button').first().innerText()
    await confirm(page, title.trim(), 'clean')
    await expect(page.getByText('Done', { exact: true }).first()).toBeVisible()
    for (const label of MADE) await expect(row(page, label), label).toHaveCount(0, { timeout: 60_000 })
    await expect(page.getByText(/MiB freed/).first()).toBeVisible()
  })
})
