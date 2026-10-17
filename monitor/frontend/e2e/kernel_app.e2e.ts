/// Kernels as an installed package (`monitor/apps/kernel`) on a throwaway
/// machine, with two real restarts: installed from the App Store, another
/// version of the running kernel installed, booted by default (restart: it
/// runs), the first one booted once (restart: it runs, the other stays the
/// default), the newest booted again, and the installed one removed.
/// `scripts/desk-vm-e2e.sh <node> kernel_app` makes the machine and runs it.
///
///     SBM_E2E_PANEL_URL=… SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_KERNEL_VERSION=7.0.0-31-generic npx playwright test kernel_app
///
/// Never on a machine that matters: it restarts it twice.

import { expect, test, type Page } from '@playwright/test'
import { fillSecret } from './secret'
import { signIn } from './signin'
import { frameOf, installFromStore, openApp, row, sudoDialog } from './desk_app'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const version = env.SBM_E2E_KERNEL_VERSION ?? ''
const APP = 'serverbox.kernel'

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !version, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_KERNEL_VERSION are not set')

async function open(page: Page) {
  await signIn(page)
  await openApp(page, APP)
  await expect(row(frameOf(page, APP), 'Boots by default')).toBeVisible({ timeout: 60_000 })
}

/// Answers the desk's sudo dialog and waits for the job to end well.
async function confirm(page: Page, button: string, typed?: string) {
  await sudoDialog(page, 'Kernels', button, { password: sudo, typed })
  const app = frameOf(page, APP)
  await expect(app.getByText('Working…')).toBeHidden({ timeout: 20 * 60_000 })
  await expect(app.getByText('Did not finish', { exact: true })).toHaveCount(0)
}

/// Restarts the machine through the desk's dialog and waits for the panel.
async function restart(page: Page) {
  await frameOf(page, APP).getByRole('button', { name: 'Reboot…' }).click()
  const d = page.locator('.lk-dialog').last()
  await fillSecret(d.locator('#power-password'), sudo)
  await d.getByRole('button', { name: 'Reboot', exact: true }).last().click()
  await expect(d.getByText(/sent/i)).toBeVisible({ timeout: 60_000 })
  await page.waitForTimeout(20_000)
  const deadline = Date.now() + 10 * 60_000
  for (;;) {
    try {
      await page.goto('/')
      await open(page)
      return
    } catch (e) {
      if (Date.now() > deadline) throw e
      console.log(`not back yet: ${String(e).split('\n')[0]}`)
      await page.waitForTimeout(10_000)
    }
  }
}

test('Kernels as a package installs, boots and removes a kernel', async ({ page }) => {
  test.setTimeout(60 * 60_000)
  await signIn(page)
  await installFromStore(page, APP, 'Kernels')
  await open(page)
  const app = frameOf(page, APP)
  const first = (await row(app, 'Running').innerText()).replace('Running', '').trim()
  expect(first).not.toBe(version)

  await test.step(`${version} is installed`, async () => {
    await app.getByLabel('Version').selectOption(`linux-image-${version}`)
    await app.getByRole('button', { name: 'Install', exact: true }).last().click()
    await confirm(page, `Install linux-image-${version}`)
    await expect(row(app, version)).toBeVisible({ timeout: 60_000 })
  })

  await test.step(`${version} is booted by default and runs after a restart`, async () => {
    await row(app, version).getByRole('button', { name: 'Boot by default' }).click()
    await confirm(page, `Boot ${version}`)
    await expect(row(app, 'Boots by default')).toContainText(version, { timeout: 60_000 })
    await expect(app.getByText(`${version} runs after a restart.`)).toBeVisible()
    await restart(page)
    await expect(row(frameOf(page, APP), 'Running')).toContainText(version)
  })

  await test.step(`${first} is booted once, ${version} stays the default`, async () => {
    const app = frameOf(page, APP)
    await row(app, first).getByRole('button', { name: 'Boot once' }).click()
    await confirm(page, `Boot ${first} once`)
    await expect(row(app, 'Next restart only')).toContainText(first, { timeout: 60_000 })
    await restart(page)
    await expect(row(frameOf(page, APP), 'Running')).toContainText(first)
    await expect(row(frameOf(page, APP), 'Boots by default')).toContainText(version)
  })

  await test.step('the newest is booted again and the installed one removed', async () => {
    const app = frameOf(page, APP)
    await app.getByRole('button', { name: 'Boot newest' }).click()
    await confirm(page, 'Boot the newest kernel')
    await expect(row(app, 'Boots by default')).toContainText(first, { timeout: 60_000 })
    await expect(row(app, first).getByRole('button', { name: 'Remove' })).toHaveCount(0)
    await row(app, version).getByRole('button', { name: 'Remove' }).click()
    await confirm(page, `Remove ${version}`, version)
    await expect(row(app, version)).toHaveCount(0, { timeout: 60_000 })
  })
})
