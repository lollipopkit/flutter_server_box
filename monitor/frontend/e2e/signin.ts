import { expect, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'

/// Opens the panel and signs in with `SBM_E2E_PANEL_PASSWORD`, the agent's
/// one password, until the desk's dock is up. A tab that holds a session
/// (after a reload) is let in without the password.
export async function signIn(page: Page) {
  await page.goto('/', { timeout: 60_000 })
  const login = page.locator('input[type=password]')
  const dock = page.locator('.lk-dock')
  await expect(login.or(dock).first()).toBeVisible({ timeout: 60_000 })
  if (await login.isVisible()) {
    await fillSecret(login, process.env.SBM_E2E_PANEL_PASSWORD!)
    await submitForm(login)
  }
  await expect(dock).toBeVisible({ timeout: 30_000 })
  // A new agent's first-run guide covers the desk until it is skipped.
  const skip = page.getByRole('button', { name: 'Skip' })
  await skip.waitFor({ timeout: 3_000 }).then(() => skip.click(), () => {})
}
