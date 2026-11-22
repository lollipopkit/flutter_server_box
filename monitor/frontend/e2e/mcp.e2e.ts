/// Settings → MCP access and `/api/v1/mcp` against a live Monitor (#1681):
/// top-level Settings section, token minting (re-authenticated), all 30 MCP
/// tools, filesystem + command execution, live global and per-token permission
/// narrowing, audit logging, and revocation.
///
///     SBM_E2E_PANEL_URL=http://127.0.0.1:13770 SBM_E2E_PANEL_PASSWORD=… \
///     npx playwright test mcp

import { expect, test, type APIRequestContext, type Locator, type Page } from '@playwright/test'
import { openApp } from './desk_app'
import { fillSecret, submitForm } from './secret'
import { signIn } from './signin'

const env = process.env

test.skip(
  !env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD,
  'SBM_E2E_PANEL_URL and SBM_E2E_PANEL_PASSWORD are not set',
)

const PROTO_HEADERS = { 'X-SBM-Protocol': '2', Connection: 'close' }

const rowIn = (page: Page, scope: Locator, label: string) =>
  scope.locator('.lk-setrow').filter({ has: page.locator('.lk-setrow__label').getByText(label, { exact: true }) })

async function reauth(page: Page, password: string) {
  const field = page.locator('.lk-dialog input[autocomplete=current-password]').last()
  await fillSecret(field, password)
  await submitForm(field)
}

async function setCheck(page: Page, scope: Locator, label: string, on: boolean) {
  const item = scope.locator('label.lk-check').filter({
    has: page.locator('span').getByText(label, { exact: true }),
  })
  const box = item.locator('input[type=checkbox]')
  await expect(item).toBeVisible()
  if ((await box.isChecked()) !== on) {
    await item.click()
  }
  await expect(box).toBeChecked({ checked: on })
}

async function mcpRpc(
  request: APIRequestContext,
  token: string,
  body: Record<string, unknown>,
  extraHeaders: Record<string, string> = {},
) {
  return request.post('/api/v1/mcp', {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Accept: 'application/json, text/event-stream',
      'MCP-Protocol-Version': '2025-11-25',
      Connection: 'close',
      ...extraHeaders,
    },
    data: body,
  })
}

async function callTool(
  request: APIRequestContext,
  token: string,
  name: string,
  args: Record<string, unknown> = {},
) {
  const res = await mcpRpc(request, token, {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: { name, arguments: args },
  })
  expect(res.status()).toBe(200)
  const payload = await res.json()
  return payload.result as { isError?: boolean; content: Array<{ type: string; text: string }> }
}

test('Settings → MCP access mints, restricts and revokes a live MCP token', async ({ page, request }) => {
  test.setTimeout(5 * 60_000)

  const runId = Date.now().toString(36)
  const tokenName = `mcp-e2e-${runId}`

  const loginRes = await request.post('/api/v1/login', {
    headers: PROTO_HEADERS,
    data: { password: env.SBM_E2E_PANEL_PASSWORD, name: `mcp-e2e-${runId}` },
  })
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy()
  const { token: adminJwt } = (await loginRes.json()) as { token: string }
  const adminHeaders = { ...PROTO_HEADERS, Authorization: `Bearer ${adminJwt}` }

  const origPolicyRes = await request.get('/api/v1/api-tokens/policy', { headers: adminHeaders })
  expect(origPolicyRes.ok()).toBeTruthy()
  const origPolicy = (await origPolicyRes.json()) as {
    scopes: string[]
    commands: { mode: string; allow: string[]; deny: string[] }
  }

  let scratchDir: string | null = null
  let mintedToken = ''

  try {
    await signIn(page)
    await openApp(page, 'serverbox.settings')
    const settingsWin = page
      .locator('.desk-window')
      .filter({ has: page.locator('.lk-window__sidebar').getByRole('button', { name: 'Account' }) })
      .last()
    await expect(settingsWin).toBeVisible()

    const mcpSidebarBtn = settingsWin.locator('.lk-window__sidebar').getByRole('button', { name: 'MCP access' })
    await expect(mcpSidebarBtn).toBeVisible()
    await mcpSidebarBtn.click()

    await expect(rowIn(page, settingsWin, 'Endpoint')).toContainText('/api/v1/mcp')
    const globalGroup = settingsWin.locator('section.lk-setgroup').filter({
      has: page.locator('.lk-setgroup__title', { hasText: 'Global permissions' }),
    })
    const tokensGroup = settingsWin.locator('section.lk-setgroup').filter({
      has: page.locator('.lk-setgroup__title', { hasText: 'Tokens' }),
    })
    await expect(globalGroup).toBeVisible()
    await expect(tokensGroup).toBeVisible()

    await test.step('minting a token rejects a wrong password without losing form state, then reveals the secret once', async () => {
      const newRow = rowIn(page, tokensGroup, 'New token')
      await expect(newRow).toContainText('All permissions')
      const nameInput = newRow.getByPlaceholder('Name')
      await nameInput.fill(tokenName)
      await newRow.getByRole('button', { name: 'Create token' }).click()

      await reauth(page, `${env.SBM_E2E_PANEL_PASSWORD}-wrong`)
      await expect(page.locator('.lk-dialog [role=alert]')).toBeVisible()
      await expect(nameInput).toHaveValue(tokenName)

      await reauth(page, env.SBM_E2E_PANEL_PASSWORD!)
      await expect(page.locator('.lk-dialog input[autocomplete=current-password]')).toHaveCount(0, {
        timeout: 30_000,
      })

      const createdRow = rowIn(page, tokensGroup, 'Token')
      await expect(createdRow).toContainText(tokenName)
      const secretInput = createdRow.locator('input[readonly]')
      mintedToken = await secretInput.inputValue()
      expect(mintedToken.startsWith('sbt_')).toBeTruthy()
      expect(mintedToken.length).toBe(68)

      await createdRow.getByRole('button', { name: 'Done' }).click()
      await expect(createdRow).toHaveCount(0)
      await expect(rowIn(page, tokensGroup, tokenName)).toContainText('All permissions')
      await expect(rowIn(page, tokensGroup, tokenName)).toContainText('Never used')
    })

    await test.step('MCP token cannot access management endpoints', async () => {
      const mcpAsAdminHeaders = { ...PROTO_HEADERS, Authorization: `Bearer ${mintedToken}` }
      const listAttempt = await request.get('/api/v1/api-tokens', { headers: mcpAsAdminHeaders })
      expect(listAttempt.status()).toBe(401)
      const policyAttempt = await request.put('/api/v1/api-tokens/policy', {
        headers: mcpAsAdminHeaders,
        data: { scopes: ['read'], commands: { mode: 'allow_all', allow: [], deny: [] } },
      })
      expect(policyAttempt.status()).toBe(401)
    })

    await test.step('MCP protocol handshake, header validation, 30 tools, readings, fs ops and command execution', async () => {
      const getRes = await request.get('/api/v1/mcp')
      expect(getRes.status()).toBe(405)
      expect(getRes.headers()['allow']).toBe('POST')

      const badVer = await mcpRpc(
        request,
        mintedToken,
        { jsonrpc: '2.0', id: 1, method: 'ping' },
        { 'MCP-Protocol-Version': '1999-01-01' },
      )
      expect(badVer.status()).toBe(400)

      const initRes = await request.post('/api/v1/mcp', {
        headers: {
          Authorization: `Bearer ${mintedToken}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        data: {
          jsonrpc: '2.0',
          id: 1,
          method: 'initialize',
          params: {
            protocolVersion: '2025-11-25',
            capabilities: {},
            clientInfo: { name: 'playwright-mcp-e2e', version: '1.0.0' },
          },
        },
      })
      expect(initRes.status()).toBe(200)
      const initBody = await initRes.json()
      expect(initBody.result.protocolVersion).toBe('2025-11-25')
      expect(initBody.result.serverInfo.name).toBe('serverbox-monitor')

      const notifRes = await mcpRpc(request, mintedToken, {
        jsonrpc: '2.0',
        method: 'notifications/initialized',
      })
      expect(notifRes.status()).toBe(202)

      const listRes = await mcpRpc(request, mintedToken, {
        jsonrpc: '2.0',
        id: 2,
        method: 'tools/list',
      })
      expect(listRes.status()).toBe(200)
      const tools = ((await listRes.json()).result.tools as Array<{ name: string }>).map((t) => t.name)
      expect(tools.length).toBe(30)
      expect(tools).toEqual(
        expect.arrayContaining([
          'machine_status',
          'machine_metrics',
          'machine_capabilities',
          'processes',
          'services',
          'containers',
          'cron',
          'tmux',
          'firewall',
          'storage',
          'virt',
          'stacks',
          'system_users',
          'fs_roots',
          'fs_list',
          'fs_stat',
          'fs_read',
          'fs_write',
          'fs_mkdir',
          'fs_rename',
          'fs_chmod',
          'fs_remove',
          'run_command',
          'kill_process',
          'service_action',
          'container_action',
          'cron_edit',
          'virt_power',
          'stack_action',
          'power',
        ]),
      )

      const statusRes = await callTool(request, mintedToken, 'machine_status')
      expect(statusRes.isError).toBeFalsy()
      const statusJson = JSON.parse(statusRes.content[0].text)
      expect(typeof statusJson.cpu).toBe('string')
      expect(statusJson.name).toBeTruthy()

      const capsRes = await callTool(request, mintedToken, 'machine_capabilities')
      expect(capsRes.isError).toBeFalsy()
      expect(JSON.parse(capsRes.content[0].text).features).toContain('mcp')

      for (const toolName of ['processes', 'services', 'containers', 'cron', 'storage', 'stacks', 'system_users']) {
        const r = await callTool(request, mintedToken, toolName)
        expect(r.isError, `${toolName}: ${r.content[0]?.text}`).toBeFalsy()
      }

      const rootsRes = await callTool(request, mintedToken, 'fs_roots')
      expect(rootsRes.isError).toBeFalsy()
      const roots = JSON.parse(rootsRes.content[0].text).roots as string[]
      expect(roots.length).toBeGreaterThan(0)
      scratchDir = `${roots[0]}/.cache/sbm-mcp-e2e-${runId}`

      expect((await callTool(request, mintedToken, 'fs_mkdir', { path: scratchDir })).isError).toBeFalsy()
      const fileA = `${scratchDir}/hello.txt`
      const fileB = `${scratchDir}/moved.txt`
      const writeRes = await callTool(request, mintedToken, 'fs_write', {
        path: fileA,
        content: '你好-mcp-e2e',
      })
      expect(writeRes.isError).toBeFalsy()
      const version = JSON.parse(writeRes.content[0].text).version as string
      expect(version).toBeTruthy()

      const staleWrite = await callTool(request, mintedToken, 'fs_write', {
        path: fileA,
        content: 'conflict',
        if_version: 'stale-version',
      })
      expect(staleWrite.isError).toBe(true)

      // 4 bytes cuts inside the second 3-byte UTF-8 character ('好'), so UTF-8
      // boundary alignment must return the 3-byte '你' cleanly.
      const truncRead = await callTool(request, mintedToken, 'fs_read', { path: fileA, max_bytes: 4 })
      expect(truncRead.isError).toBeFalsy()
      const truncJson = JSON.parse(truncRead.content[0].text)
      expect(truncJson.content).toBe('你')
      expect(truncJson.truncated).toBe(true)

      expect((await callTool(request, mintedToken, 'fs_chmod', { path: fileA, mode: 0o600 })).isError).toBeFalsy()
      expect((await callTool(request, mintedToken, 'fs_rename', { from: fileA, to: fileB })).isError).toBeFalsy()
      const dirEntries = JSON.parse(
        (await callTool(request, mintedToken, 'fs_list', { path: scratchDir })).content[0].text,
      ).entries as Array<{ name: string }>
      expect(dirEntries.map((e) => e.name)).toEqual(['moved.txt'])
      expect((await callTool(request, mintedToken, 'fs_remove', { path: scratchDir, recursive: true })).isError).toBeFalsy()
      scratchDir = null

      const execRes = await callTool(request, mintedToken, 'run_command', {
        command: 'printf "mcp-e2e-ok\\n" && uname -s',
      })
      expect(execRes.isError).toBeFalsy()
      const execJson = JSON.parse(execRes.content[0].text)
      expect(execJson.exit_code).toBe(0)
      expect(execJson.stdout).toContain('mcp-e2e-ok')
      expect(execJson.stdout).toContain('Linux')
    })

    await test.step('Global permissions in Web UI live-restrict scopes and command allowlist', async () => {
      await setCheck(page, globalGroup, 'Write files', false)
      await setCheck(page, globalGroup, 'Power', false)
      await globalGroup.getByRole('tab', { name: 'Allowlist' }).click()
      await globalGroup.getByLabel('Deny').fill('uname *')
      await globalGroup.getByLabel('Allow').fill('echo *')
      await globalGroup.getByRole('button', { name: 'Save', exact: true }).click()
      await expect(globalGroup.getByText('Saved', { exact: true })).toBeVisible()

      const listRes = await mcpRpc(request, mintedToken, { jsonrpc: '2.0', id: 3, method: 'tools/list' })
      const tools = ((await listRes.json()).result.tools as Array<{ name: string }>).map((t) => t.name)
      expect(tools.length).toBe(24)
      expect(tools).not.toContain('fs_write')
      expect(tools).not.toContain('power')

      const deniedFs = await mcpRpc(request, mintedToken, {
        jsonrpc: '2.0',
        id: 31,
        method: 'tools/call',
        params: { name: 'fs_mkdir', arguments: { path: '/tmp/nope' } },
      })
      expect((await deniedFs.json()).error.code).toBe(-32602)

      const deniedCmd = await callTool(request, mintedToken, 'run_command', { command: 'uname -a' })
      expect(deniedCmd.isError).toBe(true)

      const allowedCmd = await callTool(request, mintedToken, 'run_command', { command: 'echo global-allow-ok' })
      expect(allowedCmd.isError).toBeFalsy()
      expect(JSON.parse(allowedCmd.content[0].text).stdout.trim()).toBe('global-allow-ok')

      // Restore global permissions through the UI.
      await setCheck(page, globalGroup, 'Write files', true)
      await setCheck(page, globalGroup, 'Power', true)
      await globalGroup.getByRole('tab', { name: 'Allow all' }).click()
      await globalGroup.getByLabel('Deny').fill('')
      await globalGroup.getByRole('button', { name: 'Save', exact: true }).click()
      await expect(globalGroup.getByText('Saved', { exact: true })).toBeVisible()
    })

    await test.step('per-token permissions narrow live, show Last used, and Revoke invalidates immediately', async () => {
      // Switch sections to refresh the token row's last_used_at timestamp.
      await settingsWin.locator('.lk-window__sidebar').getByRole('button', { name: 'Account' }).click()
      await mcpSidebarBtn.click()
      const tokenRow = rowIn(page, tokensGroup, tokenName)
      await expect(tokenRow).toContainText('Last used:')

      await tokenRow.getByRole('button', { name: 'Permissions' }).click()
      // Editor sits directly under the token row inside Tokens group.
      const editor = tokensGroup.locator('div.border-t').first()
      for (const label of [
        'Read files',
        'Write files',
        'Run commands',
        'Processes',
        'Services',
        'Containers',
        'Cron',
        'Virtualization',
        'Web apps',
        'Power',
      ]) {
        await setCheck(page, editor, label, false)
      }
      await editor.getByRole('button', { name: 'Save', exact: true }).click()
      await expect(tokenRow).toContainText('Readings · Last used:')

      const narrowedList = await mcpRpc(request, mintedToken, { jsonrpc: '2.0', id: 4, method: 'tools/list' })
      const narrowedTools = ((await narrowedList.json()).result.tools as Array<{ name: string }>).map((t) => t.name)
      expect(narrowedTools.length).toBe(13)
      expect(narrowedTools).not.toContain('run_command')

      const deniedExec = await mcpRpc(request, mintedToken, {
        jsonrpc: '2.0',
        id: 41,
        method: 'tools/call',
        params: { name: 'run_command', arguments: { command: 'echo no' } },
      })
      expect((await deniedExec.json()).error.code).toBe(-32602)
      expect((await callTool(request, mintedToken, 'machine_status')).isError).toBeFalsy()

      await tokenRow.getByRole('button', { name: 'Revoke' }).click()
      await tokenRow.getByRole('button', { name: 'Confirm' }).click()
      await expect(rowIn(page, tokensGroup, tokenName)).toHaveCount(0)

      const afterRevoke = await mcpRpc(request, mintedToken, { jsonrpc: '2.0', id: 5, method: 'ping' })
      expect(afterRevoke.status()).toBe(401)
      mintedToken = ''
    })

    await test.step('audit log records MCP command executions', async () => {
      const auditRes = await request.get('/api/v1/audit?kind=mcp&limit=10', { headers: adminHeaders })
      expect(auditRes.ok()).toBeTruthy()
      const auditBody = (await auditRes.json()) as { entries: Array<{ kind: string; detail?: string }> }
      expect(auditBody.entries.length).toBeGreaterThan(0)
      expect(auditBody.entries.some((e) => (e.detail ?? '').includes('global-allow-ok'))).toBe(true)
    })

    await settingsWin.getByRole('button', { name: 'Close' }).click()
    await expect(settingsWin).toHaveCount(0)
  } finally {
    try {
      if (scratchDir && mintedToken) {
        const rm = await callTool(request, mintedToken, 'fs_remove', { path: scratchDir, recursive: true })
        expect(rm.isError, rm.content[0]?.text).toBeFalsy()
      }
    } finally {
      await request.put('/api/v1/api-tokens/policy', {
        headers: adminHeaders,
        data: { scopes: origPolicy.scopes, commands: origPolicy.commands },
      })
      const tokensRes = await request.get('/api/v1/api-tokens', { headers: adminHeaders })
      if (tokensRes.ok()) {
        const list = (await tokensRes.json()) as Array<{ id: number; name: string }>
        for (const item of list) {
          if (item.name === tokenName) {
            await request.delete(`/api/v1/api-tokens/${item.id}`, { headers: adminHeaders })
          }
        }
      }
      const liveRes = await request.get('/api/v1/live', { headers: adminHeaders })
      if (liveRes.ok()) {
        const live = (await liveRes.json()) as { devices: Array<{ id: string; label: string }> }
        for (const d of live.devices) {
          if (d.label === `mcp-e2e-${runId}` || d.label.includes('HeadlessChrome')) {
            await request.delete(`/api/v1/live/${d.id}`, { headers: adminHeaders })
          }
        }
      }
    }
  }
})
