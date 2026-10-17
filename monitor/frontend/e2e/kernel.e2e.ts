/// The Kernels app on a throwaway machine, through the panel, with two real
/// restarts: another version of the running kernel installed, booted by
/// default (restart: it runs), the first one booted once (restart: it runs,
/// the other stays the default), the newest booted again, and the installed
/// one removed. `scripts/kernel-e2e.sh <node>` makes the machine and runs it.
///
///     SBM_E2E_PANEL_URL=https://192.168.31.231:3770 SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_KERNEL_VERSION=7.0.0-31-generic npx playwright test kernel
///
/// The version must be older than the running kernel, of its flavour, and
/// not installed. Never on a machine that matters: it restarts it twice.

import { expect, test, type Page } from '@playwright/test'
import { fillSecret } from './secret'
import { signIn } from './signin'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const version = env.SBM_E2E_KERNEL_VERSION ?? ''

// Bounded, so a step that cannot happen fails with its trace instead of
// waiting out the hour.
test.use({ actionTimeout: 60_000 })

test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !version, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_KERNEL_VERSION are not set')

async function open(page: Page) {
  await signIn(page)
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  // In the panel: a window restored after a restart also says "Kernels".
  await page.locator('.apps-panel .apps-panel-app').filter({ has: page.getByText('Kernels', { exact: true }) }).click()
  await expect(page.getByText('Boots by default', { exact: true })).toBeVisible({ timeout: 60_000 })
}

/// The row labelled exactly [label] (`Row`).
const row = (page: Page, label: string) =>
  page.locator('.lk-setrow').filter({ has: page.locator('.lk-setrow__label').getByText(label, { exact: true }) })
/// Answers the sudo dialog with [button] and waits for the job to end well.
async function confirm(page: Page, button: string, typed?: string) {
  const d = page.locator('.lk-dialog').last()
  if (typed) await d.locator('input:not([type=password])').first().fill(typed)
  await fillSecret(d.getByLabel(/sudo password/), sudo)
  await d.getByRole('button', { name: button, exact: true }).click()
  await expect(page.locator('.lk-dialog')).toHaveCount(0, { timeout: 60_000 })
  await expect(page.getByText('Working…')).toBeHidden({ timeout: 20 * 60_000 })
  await expect(page.getByText('Did not finish', { exact: true })).toHaveCount(0)
}

/// Restarts the machine from the app and waits until the panel is back.
async function restart(page: Page) {
  await page.getByRole('button', { name: 'Reboot…' }).click()
  const d = page.locator('.lk-dialog').last()
  await fillSecret(d.locator('#power-password'), sudo)
  await d.getByRole('button', { name: 'Reboot', exact: true }).last().click()
  await expect(d.getByText(/sent/i)).toBeVisible({ timeout: 60_000 })
  // Gone, then back: the agent is a user service that starts at boot.
  await page.waitForTimeout(20_000)
  const deadline = Date.now() + 10 * 60_000
  for (;;) {
    try {
      await open(page)
      return
    } catch (e) {
      if (Date.now() > deadline) throw e
      console.log(`not back yet: ${String(e).split('\n')[0]}`)
      await page.waitForTimeout(10_000)
    }
  }
}

test('the Kernels app installs, boots and removes a kernel', async ({ page }) => {
  test.setTimeout(60 * 60_000)
  await open(page)
  const first = (await row(page, 'Running').innerText()).replace('Running', '').trim()
  expect(first).not.toBe(version)

  await test.step(`${version} is installed`, async () => {
    const select = page.getByLabel('Version')
    await select.selectOption(`linux-image-${version}`)
    await page.getByRole('button', { name: 'Install', exact: true }).last().click()
    await confirm(page, `Install linux-image-${version}`)
    await expect(row(page, version)).toBeVisible({ timeout: 60_000 })
  })

  await test.step(`${version} is booted by default and runs after a restart`, async () => {
    await row(page, version).getByRole('button', { name: 'Boot by default' }).click()
    await confirm(page, `Boot ${version}`)
    await expect(row(page, 'Boots by default')).toContainText(version, { timeout: 60_000 })
    await expect(page.getByText(`${version} runs after a restart.`)).toBeVisible()
    await restart(page)
    await expect(row(page, 'Running')).toContainText(version)
  })

  await test.step(`${first} is booted once, ${version} stays the default`, async () => {
    await row(page, first).getByRole('button', { name: 'Boot once' }).click()
    await confirm(page, `Boot ${first} once`)
    await expect(row(page, 'Next restart only')).toContainText(first, { timeout: 60_000 })
    await restart(page)
    await expect(row(page, 'Running')).toContainText(first)
    await expect(row(page, 'Boots by default')).toContainText(version)
  })

  await test.step('the newest is booted again and the installed one removed', async () => {
    await page.getByRole('button', { name: 'Boot newest' }).click()
    await confirm(page, 'Boot the newest kernel')
    await expect(row(page, 'Boots by default')).toContainText(first, { timeout: 60_000 })
    await expect(row(page, first).getByRole('button', { name: 'Remove' })).toHaveCount(0)
    await row(page, version).getByRole('button', { name: 'Remove' }).click()
    await confirm(page, `Remove ${version}`, version)
    await expect(row(page, version)).toHaveCount(0, { timeout: 60_000 })
  })
})
