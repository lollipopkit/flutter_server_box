/// Cleanup as an installed package (`monitor/apps/cleanup`: a component
/// backend and a web UI in a sandboxed frame) on a throwaway machine: the
/// signed package the agent ships, installed on its own and on its App Store
/// page, then what
/// `scripts/desk-vm-e2e.sh <node> cleanup_app` left there found by a scan
/// as root (the desk's own sudo dialog, the password remembered), chosen,
/// cleaned with the remembered password, and gone from the next scan.
///
///     SBM_E2E_PANEL_URL=https://192.168.31.231:3770 SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     npx playwright test cleanup_app

import { expect, test } from '@playwright/test'
import { frameOf, installFromStore, openApp, row, sudoDialog } from './desk_app'
import { signIn } from './signin'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const APP = 'serverbox.cleanup'

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_CLEANUP, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_CLEANUP are not set')

/// What the run made, as the app names it.
const MADE = ['Downloaded packages', 'Packages nothing needs', 'Old logs', 'Crash reports', 'Trash', '~/.cache/sbm-e2e-app', 'npm cache', 'sbm.leftover']

test('Cleanup as a package installs, scans and cleans as root through the desk', async ({ page }) => {
  test.setTimeout(30 * 60_000)
  await signIn(page)

  await test.step('installed on its own, signed, and on its App Store page', async () => {
    await installFromStore(page, APP, 'Cleanup')
  })

  await openApp(page, APP)
  const app = frameOf(page, APP)

  await test.step('a scan as root finds what was made; the password is remembered', async () => {
    await app.getByRole('button', { name: 'Scan', exact: true }).click()
    await sudoDialog(page, 'Cleanup', 'Scan', { password: sudo, remember: true })
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
    await sudoDialog(page, 'Cleanup', title, { typed: 'clean' })
    await expect(app.getByText('Done', { exact: true }).first()).toBeVisible({ timeout: 15 * 60_000 })
    await expect(app.getByText('Did not finish', { exact: true })).toHaveCount(0)
    for (const label of MADE) await expect(row(app, label), label).toHaveCount(0, { timeout: 60_000 })
    await expect(app.getByText(/MiB freed/).first()).toBeVisible()
  })
})
