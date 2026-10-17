/// The Tailscale app on a throwaway machine with a tailnet of its own
/// (`scripts/desk-vm-e2e.sh <node> tailscale`: Headscale on it and a peer
/// offering an exit node and a route), through the panel: Tailscale
/// installed, signed in with an auth key to that control server, the peer
/// listed and pinged directly, the peer's exit node used (LAN access kept,
/// so the panel stays reachable) with its routes, disconnected and connected
/// again with those settings, signed out, then signed in by opening the URL
/// the sign-in waits on (approved on Headscale).
///
///     SBM_E2E_PANEL_URL=… SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_TS_SERVER=http://127.0.0.1:8080 SBM_E2E_TS_KEY=… SBM_E2E_TS_REGISTER='ssh … headscale auth register --user e2e --auth-id' \
///     npx playwright test tailscale

import { execSync } from 'node:child_process'
import { expect, test, type Page } from '@playwright/test'
import { fillSecret } from './secret'
import { signIn } from './signin'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const server = env.SBM_E2E_TS_SERVER ?? ''

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !server || !env.SBM_E2E_TS_KEY, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD, SBM_E2E_TS_SERVER and SBM_E2E_TS_KEY are not set')

async function open(page: Page) {
  await signIn(page)
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.locator('.apps-panel .apps-panel-app').filter({ has: page.getByText('Tailscale', { exact: true }) }).click()
}

const row = (page: Page, label: string) =>
  page.locator('.lk-setrow').filter({ has: page.locator('.lk-setrow__label').getByText(label, { exact: true }) })

/// Answers the sudo dialog with [button]; with [wait], until the job ends well.
async function confirm(page: Page, button: string, wait = true) {
  const d = page.locator('.lk-dialog').last()
  await fillSecret(d.getByLabel(/sudo password/), sudo)
  await d.getByRole('button', { name: button, exact: true }).click()
  await expect(page.locator('.lk-dialog')).toHaveCount(0, { timeout: 60_000 })
  if (!wait) return
  await expect(page.getByText('Working…')).toHaveCount(0, { timeout: 15 * 60_000 })
  await expect(page.getByText('Did not finish', { exact: true })).toHaveCount(0)
}

/// The exit node picker: the select offering the peer.
const exitNodePicker = (page: Page) => page.getByRole('combobox').filter({ has: page.locator('option', { hasText: /^peer · / }) })

/// A setting's switch in the Settings group.
const toggle = (page: Page, label: string) => page.getByRole('switch', { name: label, exact: true })

async function signInForm(page: Page, key: string) {
  await page.getByLabel('Control server').fill(server)
  await page.getByLabel('Hostname').fill('main')
  if (key) await fillSecret(page.getByLabel('Auth key'), key)
  await page.getByRole('button', { name: 'Sign in', exact: true }).click()
}

test('the Tailscale app signs in, uses an exit node and signs out', async ({ page }) => {
  test.setTimeout(40 * 60_000)
  await open(page)

  await test.step('installed from its repository', async () => {
    await page.getByRole('button', { name: 'Install', exact: true }).click()
    await confirm(page, 'Install Tailscale')
    await expect(page.getByRole('button', { name: 'Sign in', exact: true })).toBeVisible({ timeout: 60_000 })
  })

  await test.step('signed in with an auth key, the peer listed and pinged', async () => {
    await signInForm(page, env.SBM_E2E_TS_KEY!)
    await confirm(page, 'Sign in to Tailscale')
    await expect(row(page, 'main')).toContainText('Connected', { timeout: 60_000 })
    await expect(row(page, 'peer')).toContainText('Online', { timeout: 60_000 })
    await expect(row(page, 'peer')).toContainText('Offers exit node')
    await row(page, 'peer').getByRole('button', { name: 'Ping' }).click()
    await expect(row(page, 'peer')).toContainText(/pong from peer/, { timeout: 30_000 })
  })

  await test.step("the peer's exit node and routes used, LAN access kept", async () => {
    const select = exitNodePicker(page)
    await select.selectOption((await select.locator('option', { hasText: /^peer · / }).getAttribute('value'))!)
    await expect(toggle(page, 'Allow LAN access while using an exit node')).toHaveAttribute('aria-checked', 'true')
    await toggle(page, 'Use routes other machines advertise').click()
    await page.getByRole('button', { name: 'Save', exact: true }).click()
    await confirm(page, 'Save Tailscale settings')
    await page.getByRole('button', { name: 'Refresh', exact: true }).click()
    await expect(row(page, 'peer')).toContainText('Exit node', { timeout: 60_000 })
    await expect(toggle(page, 'Use routes other machines advertise')).toHaveAttribute('aria-checked', 'true')
  })

  await test.step('disconnected, connected again with its settings', async () => {
    await row(page, 'main').getByRole('button', { name: 'Disconnect' }).click()
    await confirm(page, 'Disconnect')
    await expect(row(page, 'main')).toContainText('Disconnected', { timeout: 60_000 })
    await row(page, 'main').getByRole('button', { name: 'Connect' }).click()
    await confirm(page, 'Connect')
    await expect(row(page, 'main')).toContainText('Connected', { timeout: 60_000 })
    await expect(row(page, 'peer')).toContainText('Exit node', { timeout: 60_000 })
  })

  await test.step('signed out, signed in again by opening the sign-in URL', async () => {
    await exitNodePicker(page).selectOption('')
    await page.getByRole('button', { name: 'Save', exact: true }).click()
    await confirm(page, 'Save Tailscale settings')
    await page.getByRole('button', { name: 'Sign out', exact: true }).click()
    await confirm(page, 'Sign out of Tailscale')
    await expect(page.getByRole('button', { name: 'Sign in', exact: true })).toBeVisible({ timeout: 60_000 })
    await signInForm(page, '')
    await confirm(page, 'Sign in to Tailscale', false)
    const link = page.locator('a[href*="/register/"]')
    await expect(link).toBeVisible({ timeout: 60_000 })
    const id = (await link.getAttribute('href'))!.split('/').pop()!
    // Approved where a person would approve it: on the control server.
    execSync(`${env.SBM_E2E_TS_REGISTER} ${id}`, { stdio: 'ignore' })
    await expect(row(page, 'main')).toContainText('Connected', { timeout: 120_000 })
    await expect(page.getByText('Did not finish', { exact: true })).toHaveCount(0)
  })
})
