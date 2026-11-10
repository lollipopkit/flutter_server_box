/// The desk apps the agent ships, on a fresh Ubuntu machine, through the
/// panel's App Store: each installed on its own (Ubuntu Pro too, the machine
/// being Ubuntu), its page with what it does and asks for, uninstalled with
/// the password, left uninstalled when the catalog is read again, and
/// installed again from its page.
///
///     SBM_E2E_PANEL_URL=… SBM_E2E_PANEL_PASSWORD=… npx playwright test desk_apps
///     scripts/desk-vm-e2e.sh <node> desk_apps

import { expect, test, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'
import { signIn } from './signin'
import { openApp } from './desk_app'

const env = process.env

test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD, 'SBM_E2E_PANEL_URL and SBM_E2E_PANEL_PASSWORD are not set')
test.use({ actionTimeout: 60_000 })

const SHIPPED = ['AI agents', 'Cleanup', 'Local inference', 'Kernels', 'Reverse proxy', 'Tailscale', 'Ubuntu Pro']

const store = (page: Page) => page.locator('.desk-window').filter({ has: page.locator('.lk-window__sidebar').getByRole('button', { name: 'Desk apps' }) })
const card = (page: Page, title: string) => store(page).locator('.lk-card').filter({ has: page.getByText(title, { exact: true }) })

/// The App Store's Desk apps place.
async function deskApps(page: Page) {
  await store(page).locator('.lk-window__sidebar').getByRole('button', { name: 'Desk apps' }).click()
}

async function password(page: Page) {
  const field = page.locator('.lk-dialog').last().getByLabel('Current password')
  await fillSecret(field, env.SBM_E2E_PANEL_PASSWORD!)
  await submitForm(field)
  await expect(page.locator('.lk-dialog')).toHaveCount(0, { timeout: 60_000 })
}

/// Whether All Apps lists the app [id].
async function listed(page: Page, id: string): Promise<number> {
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  const n = await page.locator(`.apps-panel .apps-panel-app[data-app="${id}"]`).count()
  await page.keyboard.press('Escape')
  return n
}

test('the shipped desk apps are installed on their own, and one uninstalled stays so until installed again', async ({ page }) => {
  test.setTimeout(10 * 60_000)
  await signIn(page)
  await openApp(page, 'serverbox.store')
  await deskApps(page)

  await test.step('every shipped app installed, Ubuntu Pro too on Ubuntu', async () => {
    for (const title of SHIPPED) await expect(card(page, title).getByText('Installed', { exact: true })).toBeVisible({ timeout: 60_000 })
    expect(await listed(page, 'serverbox.cleanup')).toBe(1)
  })

  await test.step('its page says what it does and asks for', async () => {
    await card(page, 'Cleanup').click()
    await expect(store(page).getByText(/Finds what can go/)).toBeVisible()
    await expect(store(page).getByText(/run scripts as root/)).toBeVisible()
    await expect(store(page).getByText('Shipped with the agent')).toBeVisible()
    await expect(store(page).getByRole('button', { name: 'Open', exact: true })).toBeVisible()
  })

  await test.step('uninstalled with the password, and not back after the catalog is read', async () => {
    await store(page).getByRole('button', { name: 'Uninstall', exact: true }).click()
    await password(page)
    await expect(store(page).getByRole('button', { name: 'Install', exact: true })).toBeVisible({ timeout: 60_000 })
    expect(await listed(page, 'serverbox.cleanup')).toBe(0)
    await store(page).getByRole('button', { name: 'Back' }).first().click()
    await store(page).getByRole('button', { name: 'Check for new apps and versions' }).click()
    await deskApps(page)
    await expect(card(page, 'Kernels').getByText('Installed', { exact: true })).toBeVisible({ timeout: 60_000 })
    await expect(card(page, 'Cleanup').getByText('Installed', { exact: true })).toHaveCount(0)
  })

  await test.step('installed again from its page', async () => {
    await card(page, 'Cleanup').click()
    await store(page).getByRole('button', { name: 'Install', exact: true }).click()
    await password(page)
    await expect(store(page).getByRole('button', { name: 'Open', exact: true })).toBeVisible({ timeout: 60_000 })
    expect(await listed(page, 'serverbox.cleanup')).toBe(1)
  })
})
