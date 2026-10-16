/// Local inference on a Mac with Apple silicon, through the panel: the
/// machine read, llmfit's models for MLX, mlx-lm installed where missing, a
/// small model served, answering on loopback, and stopped.
///
///     SBM_E2E_PANEL_URL=http://127.0.0.1:3790 SBM_E2E_PANEL_PASSWORD=… SBM_E2E_INFERENCE_MLX=1 \
///     npx playwright test inference
///
/// It serves `mlx-community/Qwen3-0.6B-4bit` on port 18586 and stops it at
/// the end, whatever the agent served before.

import { expect, test, type Page } from '@playwright/test'
import { signIn } from './signin'

const env = process.env
const model = 'mlx-community/Qwen3-0.6B-4bit'

test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_INFERENCE_MLX, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_INFERENCE_MLX are not set')

async function open(page: Page) {
  await signIn(page)
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.getByText('Local inference', { exact: true }).first().click()
  await expect(page.getByText('This machine', { exact: true }).first()).toBeVisible({ timeout: 30_000 })
}

test('serves an MLX model from a recommendation', async ({ page, request }) => {
  await open(page)
  const win = page.locator('.desk-window').last()
  // The machine and the engine best for it.
  await expect(win.getByText(/Apple M\d/).first()).toBeVisible({ timeout: 30_000 })
  await expect(win.getByText('Best for this machine')).toBeVisible()

  // llmfit's models for it; one is run, which opens MLX with it.
  await win.getByText('Models', { exact: true }).first().click()
  await expect(win.getByRole('button', { name: 'Run' }).first()).toBeVisible({ timeout: 5 * 60_000 })
  await win.getByRole('button', { name: 'Run' }).first().click()
  const field = win.getByLabel('Model')
  await expect(field).toBeVisible({ timeout: 30_000 }).catch(async () => {
    // mlx-lm first: the field shows once it is installed.
    await win.getByRole('button', { name: 'Install' }).click()
    await expect(win.getByText('Installing mlx-lm…')).toBeHidden({ timeout: 15 * 60_000 })
    await expect(field).toBeVisible({ timeout: 30_000 })
  })
  expect(await field.inputValue()).not.toBe('')

  // A small one instead, to keep the download short.
  await field.fill(model)
  await win.getByLabel('Port').fill('18586')
  await win.getByRole('button', { name: /^(Start|Replace)$/ }).click()
  await expect(win.getByText(model, { exact: true })).toBeVisible({ timeout: 30_000 })
  await expect(win.getByText('Running', { exact: true })).toBeVisible({ timeout: 15 * 60_000 })

  // It answers on this machine.
  await expect
    .poll(async () => (await request.get('http://127.0.0.1:18586/v1/models').catch(() => null))?.status() ?? 0, { timeout: 15 * 60_000, intervals: [5_000] })
    .toBe(200)

  await win.getByRole('button', { name: 'Stop' }).click()
  await expect(win.getByText(model, { exact: true })).toBeHidden({ timeout: 30_000 })
})
