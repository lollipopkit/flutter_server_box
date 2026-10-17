/// Reverse proxy as an installed package (`monitor/apps/proxy`) on a
/// throwaway machine with a small web service on 127.0.0.1:18080
/// (`scripts/desk-vm-e2e.sh <node> proxy_app`): installed from the App
/// Store; Caddy installed and a site sending to the service, answered
/// through Caddy; then (Caddy stopped) nginx and its firewall installed, the
/// firewall blocking, a site behind it: a plain request passes, a script in
/// the query is refused, and the refusal is in its events.
///
///     SBM_E2E_PANEL_URL=… SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_VM='ssh … root@…' npx playwright test proxy_app

import { execSync } from 'node:child_process'
import { expect, test, type Page } from '@playwright/test'
import { signIn } from './signin'
import { frameOf, installFromStore, openApp, row, sudoDialog } from './desk_app'

const env = process.env
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const APP = 'serverbox.proxy'

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_VM, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_VM are not set')

/// What the machine answers for [host] on port 80 [path]: the status and body.
function fetchOn(host: string, path = '/'): { status: number; body: string } {
  const out = execSync(`${env.SBM_E2E_VM} "curl -s -o /tmp/sbm-e2e-body -w '%{http_code}' -H 'Host: ${host}' 'http://127.0.0.1${path}'; echo; cat /tmp/sbm-e2e-body"`, { encoding: 'utf8' })
  const [status, ...body] = out.split('\n')
  return { status: Number(status), body: body.join('\n') }
}

/// A job's sudo dialog answered; the job ends well.
async function job(page: Page, button: string) {
  await sudoDialog(page, 'Reverse proxy', button, { password: sudo })
  const app = frameOf(page, APP)
  await expect(app.getByText('Working…').or(app.getByText('Installing…'))).toHaveCount(0, { timeout: 20 * 60_000 })
  await expect(app.getByText('Did not finish', { exact: true })).toHaveCount(0)
}

async function addSite(page: Page, server: string, domain: string, withWaf: boolean) {
  const app = frameOf(page, APP)
  await page.getByRole('button', { name: 'Add site', exact: true }).click()
  const d = app.locator('.lk-dialog')
  await d.getByLabel('Domains').fill(domain)
  await d.getByLabel('Send to').fill('http://127.0.0.1:18080')
  if (await d.getByRole('switch', { name: 'HTTPS' }).getAttribute('aria-checked') === 'true') await d.getByRole('switch', { name: 'HTTPS' }).click()
  if (withWaf) await d.getByRole('switch', { name: 'Web application firewall' }).click()
  await d.getByRole('button', { name: 'Save', exact: true }).click()
  await sudoDialog(page, 'Reverse proxy', `Save the site on ${server}`, { password: sudo })
  await expect(row(app, domain)).toBeVisible({ timeout: 60_000 })
}

test('Reverse proxy as a package serves sites through Caddy and nginx behind the firewall', async ({ page }) => {
  test.setTimeout(40 * 60_000)
  await signIn(page)
  await installFromStore(page, APP, 'Reverse proxy')
  await openApp(page, APP)
  const app = frameOf(page, APP)

  await test.step('Caddy installed, a site answered through it', async () => {
    await app.getByRole('tab', { name: 'Caddy' }).click()
    await app.getByRole('button', { name: 'Install', exact: true }).click()
    await job(page, 'Install Caddy')
    await expect(row(app, 'Caddy')).toContainText('Running', { timeout: 60_000 })
    await addSite(page, 'Caddy', 'caddy.e2e.test', false)
    await expect.poll(() => fetchOn('caddy.e2e.test').body, { timeout: 60_000 }).toContain('sbm-e2e-ok')
    execSync(`${env.SBM_E2E_VM} "systemctl disable --now caddy"`, { stdio: 'ignore' })
  })

  await test.step('nginx and its firewall installed, blocking', async () => {
    await page.getByRole('button', { name: 'Refresh', exact: true }).click()
    await app.getByRole('tab', { name: 'nginx' }).click()
    await app.getByRole('button', { name: 'Install', exact: true }).click()
    await job(page, 'Install nginx')
    await expect(row(app, 'nginx')).toContainText('Running', { timeout: 60_000 })
    await app.getByRole('button', { name: 'Install', exact: true }).click()
    await job(page, 'Install the firewall')
    await app.getByRole('tab', { name: 'Block' }).click()
    await app.getByRole('button', { name: 'Save', exact: true }).click()
    await sudoDialog(page, 'Reverse proxy', "Save the firewall's settings", { password: sudo })
    await expect(app.getByRole('button', { name: 'Read', exact: true })).toBeVisible({ timeout: 60_000 })
  })

  await test.step('a site behind it: a plain request passes, a script is refused and listed', async () => {
    await addSite(page, 'nginx', 'nginx.e2e.test', true)
    await expect.poll(() => fetchOn('nginx.e2e.test').body, { timeout: 60_000 }).toContain('sbm-e2e-ok')
    expect(fetchOn('nginx.e2e.test', '/?q=%3Cscript%3Ealert(1)%3C/script%3E').status).toBe(403)
    await app.getByRole('button', { name: 'Read', exact: true }).click()
    await sudoDialog(page, 'Reverse proxy', 'Recent events', { password: sudo })
    await expect(app.getByText('Refused', { exact: true }).first()).toBeVisible({ timeout: 60_000 })
  })
})
