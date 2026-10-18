/// AI agents as an installed package (`monitor/apps/agent_tools`) on a
/// throwaway machine (`scripts/desk-vm-e2e.sh <node> agent_tools_app`):
/// installed from the App Store; an Agent mode provider added through the
/// API; opencode installed by its own installer as a job, pointed at that
/// provider (its file 0600 with the provider's address and key, read over
/// SSH), and removed with its data. (opencode: its installer is on GitHub,
/// which the test network reaches.)
///
///     SBM_E2E_PANEL_URL=… SBM_E2E_PANEL_PASSWORD=… \
///     SBM_E2E_VM='ssh … root@…' npx playwright test agent_tools_app

import { execSync } from 'node:child_process'
import { expect, test, type APIRequestContext } from '@playwright/test'
import { signIn } from './signin'
import { frameOf, installFromStore, openApp, row, navigate } from './desk_app'

const env = process.env
const APP = 'serverbox.agent_tools'
/// A key made for the run: it must reach opencode's file and nothing else.
const KEY = `sk-e2e-${Date.now().toString(36)}`

test.use({ actionTimeout: 60_000 })
test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || !env.SBM_E2E_VM, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_VM are not set')

/// [command] as the agent's account on the machine.
const onVm = (command: string) => execSync(`${env.SBM_E2E_VM} "su - sbm -c '${command.replaceAll('$', '\\$')}'"`, { encoding: 'utf8' })

/// An Agent mode provider speaking Chat Completions, as the operator adds one.
async function addProvider(request: APIRequestContext) {
  const login = await request.post('/api/v1/login', { data: { password: env.SBM_E2E_PANEL_PASSWORD } })
  expect(login.ok()).toBeTruthy()
  const { token } = await login.json()
  const put = await request.put('/api/v1/agent/settings', {
    headers: { Authorization: `Bearer ${token}` },
    data: {
      model: { provider: 'e2e', id: 'e2e-model' },
      providers: [{ id: 'e2e', name: 'E2E provider', api: 'openai-completions', baseUrl: 'http://127.0.0.1:18181/v1', models: [{ id: 'e2e-model' }] }],
      credentials: { e2e: KEY },
    },
  })
  expect(put.ok(), await put.text()).toBeTruthy()
}

test('AI agents as a package installs opencode, points it at a provider and removes it', async ({ page, request }) => {
  test.setTimeout(30 * 60_000)
  await addProvider(request)
  await signIn(page)
  await installFromStore(page, APP, 'AI agents')
  await openApp(page, APP)
  const app = frameOf(page, APP)

  await test.step('opencode installed by its installer as a job', async () => {
    await navigate(page, APP, 'opencode')
    await expect(row(app, 'opencode').first()).toContainText('Not installed', { timeout: 60_000 })
    await app.getByRole('button', { name: 'Install', exact: true }).click()
    await expect(app.getByText('Done', { exact: true })).toBeVisible({ timeout: 10 * 60_000 })
    await expect(app.locator('.lk-badge').first()).toBeVisible({ timeout: 60_000 })
    expect(onVm('$HOME/.opencode/bin/opencode --version')).toMatch(/\d+\.\d+/)
  })

  await test.step('pointed at the provider: its file 0600 with the address and key', async () => {
    await expect(app.getByLabel('Provider')).toHaveValue('e2e')
    await app.getByRole('button', { name: 'Use', exact: true }).click()
    await expect(app.getByText('Now uses e2e-model.')).toBeVisible()
    expect(onVm('stat -c %a $HOME/.config/opencode/opencode.json').trim()).toBe('600')
    const config = JSON.parse(onVm('cat $HOME/.config/opencode/opencode.json'))
    expect(config.provider.serverbox.options).toEqual({ baseURL: 'http://127.0.0.1:18181/v1', apiKey: KEY })
    expect(Object.keys(config.provider.serverbox.models)).toEqual(['e2e-model'])
  })

  await test.step('removed with its data', async () => {
    await app.getByRole('button', { name: 'Remove', exact: true }).click()
    await app.locator('.lk-check__box').click()
    await app.getByRole('button', { name: 'Remove', exact: true }).last().click()
    await expect(app.getByText('Done', { exact: true })).toBeVisible({ timeout: 5 * 60_000 })
    await expect(row(app, 'opencode').first()).toContainText('Not installed', { timeout: 60_000 })
    expect(onVm('test -e $HOME/.opencode/bin/opencode && echo there || echo gone').trim()).toBe('gone')
  })
})
