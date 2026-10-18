/// Ubuntu Pro as an installed package (`monitor/apps/ubuntu_pro`) on a
/// throwaway Ubuntu machine: installed from the App Store, unattached, the
/// services listed and none to turn on; a token Pro refuses fails the attach
/// with Pro's words; with a real token (`SBM_E2E_PRO_TOKEN`) attached
/// without the recommended services, Livepatch on (its state shown) and
/// off, and detached again. `scripts/desk-vm-e2e.sh <node> ubuntu_pro_app`.
///
/// The token takes one of the subscription's machines until the detach.

import { expect, test, type Page } from '@playwright/test'
import { fillSecret } from './secret'
import { signIn } from './signin'
import { frameOf, installFromStore, openApp, row, sudoDialog, navigate } from './desk_app'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const token = env.SBM_E2E_PRO_TOKEN ?? ''
const APP = 'serverbox.ubuntu_pro'

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD, 'SBM_E2E_PANEL_URL and SBM_E2E_PANEL_PASSWORD are not set')

/// Answers the desk's sudo dialog; the job ends [ends].
async function confirm(page: Page, button: string, ends: 'Done' | 'Did not finish' = 'Done', typed?: string) {
  await sudoDialog(page, 'Ubuntu Pro', button, { password: sudo, typed })
  await expect(frameOf(page, APP).getByText(ends, { exact: true }).first()).toBeVisible({ timeout: 15 * 60_000 })
}

async function attach(page: Page, value: string, ends: 'Done' | 'Did not finish') {
  const app = frameOf(page, APP)
  await fillSecret(app.getByLabel('Token'), value)
  await app.getByRole('button', { name: 'Attach', exact: true }).click()
  await confirm(page, 'Attach to Ubuntu Pro', ends)
}

test('Ubuntu Pro as a package attaches, turns Livepatch on and off, and detaches', async ({ page }) => {
  test.setTimeout(40 * 60_000)
  await signIn(page)
  await installFromStore(page, APP, 'Ubuntu Pro')
  await openApp(page, APP)
  const app = frameOf(page, APP)
  await expect(app.getByText('Subscription', { exact: true })).toBeVisible({ timeout: 60_000 })

  await test.step('unattached: services listed, none to turn on', async () => {
    await expect(row(app, 'Subscription')).toContainText('Not attached')
    await navigate(page, APP, 'Services')
    await expect(row(app, 'livepatch')).toBeVisible()
    await expect(row(app, 'livepatch').getByRole('switch')).toHaveCount(0)
    await navigate(page, APP, 'Subscription')
  })

  await test.step('a token Pro refuses fails the attach with its words', async () => {
    await attach(page, 'NotARealProToken0123456789', 'Did not finish')
    await expect(app.getByText(/Invalid token/).first()).toBeVisible()
    await page.getByRole('button', { name: 'Refresh', exact: true }).click()
    await expect(row(app, 'Subscription')).toContainText('Not attached')
  })

  test.skip(!token, 'SBM_E2E_PRO_TOKEN is not set: attaching for real is skipped')

  await test.step('attached without the recommended services', async () => {
    await attach(page, token, 'Done')
    await expect(row(app, 'Subscription')).toContainText('Attached', { timeout: 60_000 })
    await navigate(page, APP, 'Services')
    await expect(row(app, 'livepatch').getByRole('switch')).toHaveAttribute('aria-checked', 'false')
  })

  await test.step('Livepatch is turned on, its state shown, and off again', async () => {
    await row(app, 'livepatch').getByRole('switch').click()
    await confirm(page, 'Turn on livepatch')
    await expect(row(app, 'livepatch').getByRole('switch')).toHaveAttribute('aria-checked', 'true', { timeout: 60_000 })
    await navigate(page, APP, 'Livepatch')
    await expect(row(app, 'Patches')).toBeVisible({ timeout: 60_000 })
    await navigate(page, APP, 'Services')
    await row(app, 'livepatch').getByRole('switch').click()
    await confirm(page, 'Turn off livepatch')
    await expect(row(app, 'livepatch').getByRole('switch')).toHaveAttribute('aria-checked', 'false', { timeout: 60_000 })
  })

  await test.step('detached', async () => {
    await navigate(page, APP, 'Subscription')
    await app.getByRole('button', { name: 'Detach', exact: true }).click()
    await confirm(page, 'Detach from Ubuntu Pro', 'Done', 'detach')
    await expect(row(app, 'Subscription')).toContainText('Not attached', { timeout: 60_000 })
  })
})
