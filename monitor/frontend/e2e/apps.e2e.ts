/// Store web apps through the panel on a real agent: a deployed app opened
/// from the App Store in a window of its own, its first sign-in read in its
/// page (the agent's password asked) and used inside the window, and the
/// Agent settings pages for MCP servers and skills.
///
///     SBM_E2E_PANEL_URL=http://127.0.0.1:3770 SBM_E2E_PANEL_PASSWORD=… npx playwright test apps
///
/// The tests deploy and remove nothing: each app's test runs when it is
/// deployed with its defaults, and is skipped otherwise. FreshRSS
/// (`freshrss.freshrss`), Home Assistant (`homeassistant.home_assistant`),
/// Transmission (`transmission.transmission`), AriaNg (`mayswind.ariang`).

import { expect, test, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'
import { signIn } from './signin'

const env = process.env

test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD, 'SBM_E2E_PANEL_URL and SBM_E2E_PANEL_PASSWORD are not set')

async function openApp(page: Page, title: string) {
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.getByRole('dialog', { name: 'All Apps' }).getByRole('button', { name: title, exact: true }).click()
}

test('a deployed web app opens in its own window and its sign-in works there', async ({ page }) => {
  await signIn(page)

  let password = ''
  await test.step('the sign-in is shown after the agent password', async () => {
    await openApp(page, 'App Store')
    await page.getByPlaceholder('Search apps').fill('FreshRSS')
    await page.getByText('FreshRSS', { exact: true }).first().click()
    const deployed = await page.getByRole('button', { name: 'Open' }).waitFor({ timeout: 15_000 }).then(() => true, () => false)
    test.skip(!deployed, 'FreshRSS is not deployed')
    const signInGroup = page.locator('.lk-group, section').filter({ has: page.getByText('Sign-in', { exact: true }) }).last()
    await expect(signInGroup.getByText('admin', { exact: true })).toHaveCount(1)
    await signInGroup.getByRole('button', { name: 'Show password' }).click()
    const field = page.locator('.lk-dialog').last().locator('input[type=password]')
    await fillSecret(field, env.SBM_E2E_PANEL_PASSWORD!)
    await submitForm(field)
    const shown = signInGroup.locator('.select-all')
    await expect(shown).toBeVisible({ timeout: 30_000 })
    password = (await shown.textContent())?.trim() ?? ''
    expect(password.length).toBeGreaterThanOrEqual(16)
  })

  await test.step('the window shows the app, and the password signs in', async () => {
    await page.getByRole('button', { name: 'Open' }).click()
    const frame = page.frameLocator('.desk-window iframe').last()
    const user = frame.locator('input[name=username]')
    await expect(user).toBeVisible({ timeout: 60_000 })
    await user.fill('admin')
    const pass = frame.locator('input[type=password]').first()
    // Its form is ready once bcrypt.js has loaded: the button is enabled then.
    await expect(frame.locator('form.crypto-form [type=submit]')).toBeEnabled({ timeout: 30_000 })
    await fillSecret(pass, password)
    await submitForm(pass)
    await expect(frame.locator('[formaction*="a=logout"]').first()).toBeAttached({ timeout: 60_000 })
  })
})

test('Home Assistant opens through the proxy, its forwarded requests trusted', async ({ page }) => {
  await signIn(page)
  await openApp(page, 'App Store')
  await page.getByPlaceholder('Search apps').fill('Home Assistant')
  await page.getByText('Home Assistant', { exact: true }).first().click()
  const open = page.getByRole('button', { name: 'Open' })
  const deployed = await open.waitFor({ timeout: 15_000 }).then(() => true, () => false)
  test.skip(!deployed, 'Home Assistant is not deployed')
  await open.click()
  const frame = page.frameLocator('.desk-window iframe').last()
  // Its own page (sign-in or onboarding), not the 400 an untrusted proxy gets.
  await expect(frame.locator('ha-authorize, ha-onboarding, home-assistant').first()).toBeAttached({ timeout: 60_000 })
})

test('Transmission opens signed in: the proxy answers its basic auth', async ({ page }) => {
  await signIn(page)
  await openApp(page, 'App Store')
  await page.getByPlaceholder('Search apps').fill('Transmission')
  await page.getByText('Transmission', { exact: true }).first().click()
  const open = page.getByRole('button', { name: 'Open' })
  const deployed = await open.waitFor({ timeout: 15_000 }).then(() => true, () => false)
  test.skip(!deployed, 'Transmission is not deployed')
  await open.click()
  const frame = page.frameLocator('.desk-window iframe').last()
  await expect(frame.locator('#mainwin-toolbar')).toBeVisible({ timeout: 60_000 })
  // The speeds come from its RPC: the page's own requests were let in too.
  await expect(frame.locator('#speed-down')).toHaveText(/B\/s/, { timeout: 30_000 })
})

test('AriaNg reaches aria2 through its own window, with the revealed secret', async ({ page }) => {
  await signIn(page)
  await openApp(page, 'App Store')
  await page.getByPlaceholder('Search apps').fill('AriaNg')
  await page.getByText('AriaNg', { exact: true }).first().click()
  const open = page.getByRole('button', { name: 'Open' })
  const deployed = await open.waitFor({ timeout: 15_000 }).then(() => true, () => false)
  test.skip(!deployed, 'AriaNg is not deployed')

  const signInGroup = page.locator('.lk-group, section').filter({ has: page.getByText('Sign-in', { exact: true }) }).last()
  await signInGroup.getByRole('button', { name: 'Show password' }).click()
  const field = page.locator('.lk-dialog').last().locator('input[type=password]')
  await fillSecret(field, env.SBM_E2E_PANEL_PASSWORD!)
  await submitForm(field)
  const shown = signInGroup.locator('.select-all')
  await expect(shown).toBeVisible({ timeout: 30_000 })
  const secret = (await shown.textContent())?.trim() ?? ''
  expect(secret.length).toBeGreaterThanOrEqual(16)

  await open.click()
  const frame = page.frameLocator('.desk-window iframe').last()
  await expect(frame.getByText('Aria2 Status')).toBeVisible({ timeout: 60_000 })
  const win = (await (await page.locator('.desk-window iframe').last().elementHandle())!.contentFrame())!
  // Its default RPC address is the window's own: the patched default port.
  // AriaNg writes its settings a moment after it starts.
  await expect
    .poll(() => win.evaluate(() => JSON.parse(localStorage.getItem('AriaNg.Options') ?? '{}').rpcPort), { timeout: 20_000 })
    .toBe(new URL(win.url()).port)
  // The secret as AriaNg's settings page keeps it (base64), without a focused field.
  await win.evaluate((s) => {
    const o = JSON.parse(localStorage.getItem('AriaNg.Options') ?? '{}')
    o.secret = btoa(s)
    localStorage.setItem('AriaNg.Options', JSON.stringify(o))
    location.reload()
  }, secret)
  await expect(frame.getByText('Connected', { exact: true })).toBeVisible({ timeout: 30_000 })
})

test('Settings → Agent has MCP servers and skills', async ({ page }) => {
  await signIn(page)
  await openApp(page, 'Settings')
  await page.getByText('Agent', { exact: true }).first().click()
  await page.getByText('MCP servers', { exact: true }).first().click()
  await expect(page.getByRole('button', { name: 'Add server' })).toBeVisible({ timeout: 30_000 })
  await expect(page.getByText('No servers', { exact: true })).toBeVisible()
  await page.locator('.desk-window').last().getByRole('button', { name: /back/i }).first().click()
  await page.getByText('Skills', { exact: true }).first().click()
  await expect(page.getByText('GitHub repository', { exact: true })).toBeVisible({ timeout: 30_000 })
})
