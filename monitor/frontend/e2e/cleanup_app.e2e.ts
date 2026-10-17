/// Cleanup as an installed package (`monitor/apps/cleanup`: a component
/// backend and a web UI in a sandboxed frame) on a throwaway machine: the
/// package installed and approved in Settings → Apps, then what
/// `scripts/desk-vm-e2e.sh <node> cleanup_app` left there found by a scan
/// as root (the desk's own sudo dialog, the password remembered), chosen,
/// cleaned with the remembered password, and gone from the next scan.
///
///     SBM_E2E_PANEL_URL=https://192.168.31.231:3770 SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_APP_PACKAGE=monitor/apps/cleanup/target/lollipopkit.cleanup.fsba npx playwright test cleanup_app

import { expect, test, type FrameLocator, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'
import { signIn } from './signin'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const APP = 'lollipopkit.cleanup'

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_APP_PACKAGE, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_APP_PACKAGE are not set')

/// What the run made, as the app names it.
const MADE = ['Downloaded packages', 'Packages nothing needs', 'Old logs', 'Crash reports', 'Trash', '~/.cache/sbm-e2e-app', 'npm cache', 'sbm.leftover']

async function openApp(page: Page, id: string) {
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.locator(`.apps-panel .apps-panel-app[data-app="${id}"]`).click()
}

const row = (scope: FrameLocator | Page, label: string) =>
  scope.locator('.lk-setrow').filter({ has: scope.locator('.lk-setrow__label').getByText(label, { exact: true }) })

/// The desk's sudo dialog for the app: [button] once [password] (or the
/// one remembered) and [typed] are in.
async function sudoDialog(page: Page, button: string, options: { password?: string; remember?: boolean; typed?: string }) {
  const d = page.locator('.lk-dialog').last()
  await expect(d.getByText('Cleanup asks to run this as root.')).toBeVisible()
  if (options.typed) await d.locator('input:not([type=password])').first().fill(options.typed)
  if (options.password) await fillSecret(d.getByLabel(/sudo password/), options.password)
  if (options.remember) await d.locator('.lk-check__box').click()
  await d.getByRole('button', { name: button, exact: true }).click()
  await expect(page.locator('.lk-dialog')).toHaveCount(0, { timeout: 60_000 })
}

test('Cleanup as a package installs, scans and cleans as root through the desk', async ({ page }) => {
  test.setTimeout(30 * 60_000)
  await signIn(page)

  await test.step('installed and approved in Settings → Apps', async () => {
    await openApp(page, 'serverbox.settings')
    await page.locator('.lk-side__item').filter({ has: page.locator('.lk-side__label').getByText('Apps', { exact: true }) }).click()
    await page.locator('input[type=file][accept*="fsba"]').setInputFiles(env.SBM_E2E_APP_PACKAGE!)
    const pkg = row(page, 'Cleanup').filter({ hasText: 'run scripts as root' })
    await expect(pkg).toBeVisible({ timeout: 60_000 })
    await pkg.getByRole('button', { name: 'Approve', exact: true }).click()
    const field = page.locator('.lk-dialog').last().getByLabel('Current password')
    await fillSecret(field, env.SBM_E2E_PANEL_PASSWORD!)
    await submitForm(field)
    await expect(pkg.getByRole('button', { name: 'Approve', exact: true })).toHaveCount(0, { timeout: 30_000 })
    await page.keyboard.press('Escape')
  })

  await openApp(page, APP)
  const app = page.frameLocator(`iframe[title="${APP}"]`)

  await test.step('a scan as root finds what was made; the password is remembered', async () => {
    await app.getByRole('button', { name: 'Scan', exact: true }).click()
    await sudoDialog(page, 'Scan', { password: sudo, remember: true })
    await expect(row(app, 'Can go')).toBeVisible({ timeout: 15 * 60_000 })
    for (const label of MADE) await expect(row(app, label), label).toBeVisible({ timeout: 60_000 })
    await expect(row(app, 'sbm.leftover')).toContainText(/MiB/)
  })

  await test.step('chosen and cleaned with the remembered password, the next scan finds none of it', async () => {
    for (const label of MADE) {
      await row(app, label).locator('.lk-check__box').click()
      await expect(row(app, label).getByRole('checkbox')).toBeChecked()
    }
    await app.getByRole('button', { name: 'Clean…' }).click()
    const d = page.locator('.lk-dialog').last()
    await expect(d.getByText(/Remembered for a while/)).toBeVisible()
    const title = (await d.getByRole('button').first().innerText()).trim()
    await sudoDialog(page, title, { typed: 'clean' })
    await expect(app.getByText('Done', { exact: true }).first()).toBeVisible({ timeout: 15 * 60_000 })
    await expect(app.getByText('Did not finish', { exact: true })).toHaveCount(0)
    for (const label of MADE) await expect(row(app, label), label).toHaveCount(0, { timeout: 60_000 })
    await expect(app.getByText(/MiB freed/).first()).toBeVisible()
  })
})
