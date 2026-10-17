/// Local inference as an installed package (`monitor/apps/inference`) on a
/// throwaway machine with Docker and a fake Ollama on 127.0.0.1:11434
/// (`scripts/desk-vm-e2e.sh <node> inference_app`): installed from the App
/// Store; the machine and its engines read; llmfit fetched from its release
/// (checked by its SHA-256) and its models listed; Run on a llama.cpp model
/// opens the desk's own setup sheet with the model filled in (nothing is
/// deployed); Ollama's models listed, one pulled with its progress in the
/// job's log, and removed.
///
///     SBM_E2E_PANEL_URL=… SBM_E2E_PANEL_PASSWORD=… npx playwright test inference_app

import { expect, test } from '@playwright/test'
import { signIn } from './signin'
import { frameOf, installFromStore, openApp, row } from './desk_app'

const env = process.env
const APP = 'serverbox.inference'

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_INFERENCE_APP, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_INFERENCE_APP are not set')

test('Local inference as a package reads the machine, scores models and pulls to Ollama', async ({ page }) => {
  test.setTimeout(20 * 60_000)
  await signIn(page)
  await installFromStore(page, APP, 'Local inference')
  await openApp(page, APP)
  const app = frameOf(page, APP)

  await test.step('the machine and its engines', async () => {
    await expect(row(app, 'Memory')).toBeVisible({ timeout: 60_000 })
    await expect(row(app, 'Docker')).toContainText('Without GPU access')
    await expect(row(app, 'llama.cpp')).toContainText('Can run here')
    await expect(row(app, 'Ollama')).toContainText('Found on this machine')
    await expect(row(app, 'MLX')).toContainText('Needs a Mac with Apple silicon')
  })

  await test.step("llmfit's models; Run opens the desk's setup with the model", async () => {
    await app.getByRole('tab', { name: 'Models' }).click()
    await expect(app.getByRole('button', { name: 'Run' }).first()).toBeVisible({ timeout: 10 * 60_000 })
    await app.getByRole('tab', { name: 'llama.cpp' }).click()
    const first = app.locator('.lk-setrow').filter({ has: app.getByRole('button', { name: 'Run' }) }).first()
    const sub = (await first.locator('.lk-setrow__hint').innerText()).split(' · ')
    // The GGUF repository and quantization, as llama.cpp's setting takes it.
    const setting = sub.find((s) => s.includes(':')) ?? ''
    expect(setting).toMatch(/^[\w.-]+\/[\w.-]+:\w+$/)
    await first.getByRole('button', { name: 'Run' }).click()
    const sheet = page.locator('.lk-dialog').last()
    await expect(sheet).toContainText('llama.cpp', { timeout: 60_000 })
    await expect.poll(() => sheet.locator('input').evaluateAll((els) => els.map((e) => (e as HTMLInputElement).value))).toContain(setting)
    await sheet.getByRole('button', { name: 'Close', exact: true }).click()
    await expect(page.locator('.lk-dialog')).toHaveCount(0)
  })

  await test.step("Ollama's models: one pulled with its progress, then removed", async () => {
    await app.getByRole('tab', { name: 'This machine' }).click()
    await row(app, 'Ollama').click()
    await expect(row(app, 'tiny:latest')).toContainText('Loaded', { timeout: 60_000 })
    await app.getByLabel('Model to pull').fill('tiny2:latest')
    await app.getByRole('button', { name: 'Pull', exact: true }).click()
    await expect(app.getByText('Pulled', { exact: true })).toBeVisible({ timeout: 60_000 })
    await expect(app.getByText('downloading 50%')).toBeVisible()
    await expect(row(app, 'tiny2:latest')).toBeVisible({ timeout: 30_000 })
    await row(app, 'tiny2:latest').getByRole('button', { name: 'Remove model' }).click()
    await expect(row(app, 'tiny2:latest')).toHaveCount(0, { timeout: 30_000 })
  })
})
