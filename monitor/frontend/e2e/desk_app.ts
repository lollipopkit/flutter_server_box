/// Installed first-party desk apps in the panel (`monitor/apps/<name>`): the
/// App Store install, the app's frame, the desk's sudo dialog for it.

import { expect, type FrameLocator, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'

/// Opens the app [id] from All Apps.
export async function openApp(page: Page, id: string) {
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.locator(`.apps-panel .apps-panel-app[data-app="${id}"]`).click()
}

/// Installs and approves the app titled [title] from the App Store's desk
/// apps (the signed package the agent ships), unless it is there already;
/// the built-in app of its id gives way to it.
export async function installFromStore(page: Page, id: string, title: string) {
  await openApp(page, 'serverbox.store')
  const store = page.locator('.desk-window').filter({ has: page.getByPlaceholder('Search apps') })
  await store.locator('.lk-window__sidebar').getByRole('button', { name: 'Desk apps' }).click()
  const card = store.locator('.lk-card').filter({ has: page.getByText(title, { exact: true }) }).filter({ hasText: 'ServerBox' })
  const open = card.getByRole('button', { name: 'Open', exact: true })
  const install = card.getByRole('button', { name: 'Install', exact: true })
  await expect(open.or(install)).toBeVisible({ timeout: 60_000 })
  if (await install.isVisible()) {
    await install.click()
    const field = page.locator('.lk-dialog').last().getByLabel('Current password')
    await fillSecret(field, process.env.SBM_E2E_PANEL_PASSWORD!)
    await submitForm(field)
    await expect(open).toBeVisible({ timeout: 60_000 })
  }
  await page.keyboard.press('Escape')
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await expect(page.locator(`.apps-panel .apps-panel-app[data-app="${id}"]`)).toHaveCount(1)
  await page.keyboard.press('Escape')
}

export const frameOf = (page: Page, id: string): FrameLocator => page.frameLocator(`iframe[title="${id}"]`)

/// Chooses the place labelled [label] in the sidebar of app [id]'s window
/// (`desk.sidebar`).
export async function navigate(page: Page, id: string, label: string) {
  const win = page.locator('.desk-window').filter({ has: page.locator(`iframe[title="${id}"]`) })
  await win.locator('.lk-window__sidebar').getByRole('button', { name: new RegExp(`^${label}`) }).click()
}

/// The row labelled exactly [label] (`Row`), in the page or a frame.
export const row = (scope: FrameLocator | Page, label: string) =>
  scope.locator('.lk-setrow').filter({ has: scope.locator('.lk-setrow__label').getByText(label, { exact: true }) })

/// The desk's sudo dialog for [app]: [button] once the password (or the
/// one remembered) and [typed] are in.
export async function sudoDialog(page: Page, app: string, button: string, options: { password?: string; remember?: boolean; typed?: string } = {}) {
  const d = page.locator('.lk-dialog').last()
  await expect(d.getByText(`${app} asks to run this as root.`)).toBeVisible()
  if (options.typed) await d.locator('input:not([type=password])').first().fill(options.typed)
  if (options.password) await fillSecret(d.getByLabel(/sudo password/), options.password)
  if (options.remember) await d.locator('.lk-check__box').click()
  await d.getByRole('button', { name: button, exact: true }).click()
  await expect(page.locator('.lk-dialog')).toHaveCount(0, { timeout: 60_000 })
}
