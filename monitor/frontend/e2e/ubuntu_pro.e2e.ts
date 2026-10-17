/// The Ubuntu Pro app on a throwaway Ubuntu machine, through the panel:
/// unattached, the services listed and none to turn on; a token Pro refuses
/// fails the attach with Pro's words; with a real token
/// (`SBM_E2E_PRO_TOKEN`) the machine is attached without the recommended
/// services, Livepatch turned on (its state shown) and off, and the machine
/// detached again. `scripts/desk-vm-e2e.sh <node> ubuntu_pro` makes the
/// machine and runs it.
///
///     SBM_E2E_PANEL_URL=https://192.168.31.231:3770 SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_PRO_TOKEN=… npx playwright test ubuntu_pro
///
/// The token takes one of the subscription's machines until the detach.

import { expect, test, type Page } from '@playwright/test'
import { fillSecret } from './secret'
import { signIn } from './signin'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const token = env.SBM_E2E_PRO_TOKEN ?? ''

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD, 'SBM_E2E_PANEL_URL and SBM_E2E_PANEL_PASSWORD are not set')

async function open(page: Page) {
  await signIn(page)
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.locator('.apps-panel .apps-panel-app').filter({ has: page.getByText('Ubuntu Pro', { exact: true }) }).click()
  await expect(page.getByText('Subscription', { exact: true })).toBeVisible({ timeout: 60_000 })
}

/// The row labelled exactly [label] (`Row`).
const row = (page: Page, label: string) =>
  page.locator('.lk-setrow').filter({ has: page.locator('.lk-setrow__label').getByText(label, { exact: true }) })

/// Answers the sudo dialog with [button]; the job ends [ends].
async function confirm(page: Page, button: string, ends: 'Done' | 'Did not finish' = 'Done', typed?: string) {
  const d = page.locator('.lk-dialog').last()
  if (typed) await d.locator('input:not([type=password])').first().fill(typed)
  await fillSecret(d.getByLabel(/sudo password/), sudo)
  await d.getByRole('button', { name: button, exact: true }).click()
  await expect(page.locator('.lk-dialog')).toHaveCount(0, { timeout: 60_000 })
  await expect(page.getByText(ends, { exact: true }).first()).toBeVisible({ timeout: 15 * 60_000 })
}

/// Types [value] into the token field and attaches.
async function attach(page: Page, value: string, ends: 'Done' | 'Did not finish') {
  await fillSecret(page.getByLabel('Token'), value)
  await page.getByRole('button', { name: 'Attach', exact: true }).click()
  await confirm(page, 'Attach to Ubuntu Pro', ends)
}

test('the Ubuntu Pro app attaches, turns Livepatch on and off, and detaches', async ({ page }) => {
  test.setTimeout(40 * 60_000)
  await open(page)

  await test.step('unattached: services listed, none to turn on', async () => {
    await expect(row(page, 'Subscription')).toContainText('Not attached')
    await expect(row(page, 'livepatch')).toBeVisible()
    await expect(row(page, 'livepatch').getByRole('switch')).toHaveCount(0)
  })

  await test.step('a token Pro refuses fails the attach with its words', async () => {
    await attach(page, 'NotARealProToken0123456789', 'Did not finish')
    await expect(page.getByText(/Invalid token/).first()).toBeVisible()
    await page.getByRole('button', { name: 'Refresh', exact: true }).click()
    await expect(row(page, 'Subscription')).toContainText('Not attached')
  })

  test.skip(!token, 'SBM_E2E_PRO_TOKEN is not set: attaching for real is skipped')

  await test.step('attached without the recommended services', async () => {
    await attach(page, token, 'Done')
    await page.getByRole('button', { name: 'Refresh', exact: true }).click()
    await expect(row(page, 'Subscription')).toContainText('Attached', { timeout: 60_000 })
    await expect(row(page, 'livepatch').getByRole('switch')).toHaveAttribute('aria-checked', 'false')
  })

  await test.step('Livepatch is turned on, its state shown, and off again', async () => {
    await row(page, 'livepatch').getByRole('switch').click()
    await confirm(page, 'Turn on livepatch')
    await page.getByRole('button', { name: 'Refresh', exact: true }).click()
    await expect(row(page, 'livepatch').getByRole('switch')).toHaveAttribute('aria-checked', 'true', { timeout: 60_000 })
    await expect(row(page, 'Patches')).toBeVisible({ timeout: 60_000 })
    await row(page, 'livepatch').getByRole('switch').click()
    await confirm(page, 'Turn off livepatch')
    await page.getByRole('button', { name: 'Refresh', exact: true }).click()
    await expect(row(page, 'livepatch').getByRole('switch')).toHaveAttribute('aria-checked', 'false', { timeout: 60_000 })
  })

  await test.step('detached', async () => {
    await page.getByRole('button', { name: 'Detach', exact: true }).click()
    await confirm(page, 'Detach from Ubuntu Pro', 'Done', 'detach')
    await page.getByRole('button', { name: 'Refresh', exact: true }).click()
    await expect(row(page, 'Subscription')).toContainText('Not attached', { timeout: 60_000 })
  })
})
