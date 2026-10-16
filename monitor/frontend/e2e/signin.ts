import { expect, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'

/// Opens the panel and signs in with `SBM_E2E_PANEL_PASSWORD`, the agent's
/// one password, until the desk's dock is up.
export async function signIn(page: Page) {
  await page.goto('/')
  const login = page.locator('input[type=password]')
  await fillSecret(login, process.env.SBM_E2E_PANEL_PASSWORD!)
  await submitForm(login)
  await expect(page.locator('.lk-dock')).toBeVisible({ timeout: 30_000 })
}
