/// Tailscale as an installed package (`monitor/apps/tailscale`) on a
/// throwaway machine with a tailnet of its own
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
///     npx playwright test tailscale_app

import { execSync } from 'node:child_process'
import { expect, test, type Page } from '@playwright/test'
import { fillSecret } from './secret'
import { signIn } from './signin'
import { frameOf, installFromStore, openApp, sudoDialog } from './desk_app'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const server = env.SBM_E2E_TS_SERVER ?? ''

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !server || !env.SBM_E2E_TS_KEY, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD, SBM_E2E_TS_SERVER and SBM_E2E_TS_KEY are not set')

const APP = 'serverbox.tailscale'

/// Inside the app's frame.
const app = (page: Page) => frameOf(page, APP)

const row = (page: Page, label: string) =>
  app(page).locator('.lk-setrow').filter({ has: app(page).locator('.lk-setrow__label').getByText(label, { exact: true }) })

/// Answers the desk's sudo dialog with [button]; with [wait], until the job
/// ends well.
async function confirm(page: Page, button: string, wait = true) {
  await sudoDialog(page, 'Tailscale', button, { password: sudo })
  if (!wait) return
  await expect(app(page).getByText('Working…')).toHaveCount(0, { timeout: 15 * 60_000 })
  await expect(app(page).getByText('Did not finish', { exact: true })).toHaveCount(0)
}

/// The exit node picker: the select offering the peer.
const exitNodePicker = (page: Page) => app(page).getByRole('combobox').filter({ has: app(page).locator('option', { hasText: /^peer · / }) })

/// A setting's switch in the Settings group.
const toggle = (page: Page, label: string) => app(page).getByRole('switch', { name: label, exact: true })

async function signInForm(page: Page, key: string) {
  await app(page).getByLabel('Control server').fill(server)
  await app(page).getByLabel('Hostname').fill('main')
  if (key) await fillSecret(app(page).getByLabel('Auth key'), key)
  await app(page).getByRole('button', { name: 'Sign in', exact: true }).click()
}

test('Tailscale as a package signs in, uses an exit node and signs out', async ({ page }) => {
  test.setTimeout(40 * 60_000)
  await signIn(page)
  await installFromStore(page, APP, 'Tailscale')
  await openApp(page, APP)

  await test.step('installed from its repository', async () => {
    await app(page).getByRole('button', { name: 'Install', exact: true }).click()
    await confirm(page, 'Install Tailscale')
    await expect(app(page).getByRole('button', { name: 'Sign in', exact: true })).toBeVisible({ timeout: 60_000 })
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
    await app(page).getByRole('button', { name: 'Save', exact: true }).click()
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
    await app(page).getByRole('button', { name: 'Save', exact: true }).click()
    await confirm(page, 'Save Tailscale settings')
    await app(page).getByRole('button', { name: 'Sign out', exact: true }).click()
    await confirm(page, 'Sign out of Tailscale')
    await expect(app(page).getByRole('button', { name: 'Sign in', exact: true })).toBeVisible({ timeout: 60_000 })
    await signInForm(page, '')
    await confirm(page, 'Sign in to Tailscale', false)
    const link = app(page).locator('a[href*="/register/"]')
    await expect(link).toBeVisible({ timeout: 60_000 })
    const id = (await link.getAttribute('href'))!.split('/').pop()!
    // Approved where a person would approve it: on the control server.
    execSync(`${env.SBM_E2E_TS_REGISTER} ${id}`, { stdio: 'ignore' })
    await expect(row(page, 'main')).toContainText('Connected', { timeout: 120_000 })
    await expect(app(page).getByText('Did not finish', { exact: true })).toHaveCount(0)
  })
})
