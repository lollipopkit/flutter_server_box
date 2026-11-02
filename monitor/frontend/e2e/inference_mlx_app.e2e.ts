/// Local inference as an installed package on a Mac with Apple silicon (an
/// agent of this build run here): installed from the App Store; llmfit's
/// models for MLX; Run opens MLX with the model; mlx-lm installed into the
/// app's own folder as a job where missing; a small model served, answering
/// on loopback and offered to Agent mode; stopped.
///
///     SBM_E2E_PANEL_URL=http://127.0.0.1:3790 SBM_E2E_PANEL_PASSWORD=… SBM_E2E_INFERENCE_MLX=1 \
///     npx playwright test inference_mlx_app
///
/// It serves `mlx-community/Qwen3-0.6B-4bit` on port 18586 and stops it at
/// the end, whatever the agent served before.

import { expect, test } from '@playwright/test'
import { signIn } from './signin'
import { frameOf, installFromStore, openApp } from './desk_app'

const env = process.env
const APP = 'serverbox.inference'
const model = 'mlx-community/Qwen3-0.6B-4bit'

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_INFERENCE_MLX, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_INFERENCE_MLX are not set')

test('Local inference as a package serves an MLX model from a recommendation', async ({ page, request }) => {
  test.setTimeout(45 * 60_000)
  await signIn(page)
  await installFromStore(page, APP, 'Local inference')
  await openApp(page, APP)
  const app = frameOf(page, APP)

  await expect(app.getByText(/Apple M\d/).first()).toBeVisible({ timeout: 60_000 })
  await expect(app.getByText('Best for this machine')).toBeVisible()

  await app.getByRole('tab', { name: 'Models' }).click()
  await expect(app.getByRole('button', { name: 'Run' }).first()).toBeVisible({ timeout: 10 * 60_000 })
  const mlx = app.getByRole('tab', { name: 'MLX' })
  if (await mlx.count()) await mlx.click()
  await app.getByRole('button', { name: 'Run' }).first().click()

  const field = app.getByLabel('Model', { exact: true })
  if (!(await field.isVisible().catch(() => false))) {
    // mlx-lm first: the field shows once it is installed.
    await app.getByRole('button', { name: 'Install' }).click()
    await expect(app.getByText('Installed', { exact: true }).first()).toBeVisible({ timeout: 20 * 60_000 })
    await expect(field).toBeVisible({ timeout: 60_000 })
  }
  expect(await field.inputValue()).not.toBe('')

  // A small one instead, to keep the download short.
  await field.fill(model)
  await app.getByLabel('Port').fill('18586')
  await app.getByRole('button', { name: /^(Start|Replace)$/ }).click()
  await expect(app.getByText(model, { exact: true })).toBeVisible({ timeout: 30_000 })
  await expect(app.getByText('Running', { exact: true })).toBeVisible({ timeout: 15 * 60_000 })
  await expect
    .poll(async () => (await request.get('http://127.0.0.1:18586/v1/models').catch(() => null))?.status() ?? 0, { timeout: 15 * 60_000, intervals: [5_000] })
    .toBe(200)

  // Agent mode offers it.
  const login = await request.post('/api/v1/login', { data: { password: env.SBM_E2E_PANEL_PASSWORD } })
  const { token } = await login.json()
  await expect
    .poll(async () => {
      const r = await request.get('/api/v1/agent/settings', { headers: { Authorization: `Bearer ${token}` } })
      return JSON.stringify((await r.json()).appProviders ?? [])
    }, { timeout: 60_000 })
    .toContain('app.mlx')

  await app.getByRole('button', { name: 'Stop' }).click()
  await expect(app.getByText(model, { exact: true })).toBeHidden({ timeout: 30_000 })
})
