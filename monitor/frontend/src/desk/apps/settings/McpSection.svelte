<script lang="ts">
  /// MCP access (`/api-tokens*`, `/mcp`, #1681): endpoint URL, global
  /// permission ceiling, and API tokens with per-token scopes and command
  /// rules.

  import { onDestroy } from 'svelte'
  import { get } from 'svelte/store'
  import { Badge, Button, Checkbox, Group, Input, Row, SegmentedControl, Spinner, Textarea } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { accessMessage } from '../../../lib/access'
  import {
    ALL_API_TOKEN_SCOPES,
    api,
    type ApiToken,
    type ApiTokenScope,
    type CreatedApiToken,
    type McpCommandMode,
    type McpCommandPolicy,
    type McpPolicy,
  } from '../../../lib/api'
  import { DATE_TIME, fmtDate } from '../../../lib/format'
  import { useScope } from '../../../lib/scope.svelte'
  import { servers, type ServerEntry } from '../../../lib/servers.svelte'
  import ReauthDialog from '../../../components/ReauthDialog.svelte'
  import SettingsPage from './SettingsPage.svelte'

  const scope = useScope()

  let policySavedTimer: ReturnType<typeof setTimeout> | null = null
  let endpointCopiedTimer: ReturnType<typeof setTimeout> | null = null

  onDestroy(() => {
    if (policySavedTimer) clearTimeout(policySavedTimer)
    if (endpointCopiedTimer) clearTimeout(endpointCopiedTimer)
  })

  const endpointUrl = $derived(
    `${(servers.current?.url || window.location.origin).replace(/\/+$/, '')}/api/v1/mcp`,
  )

  function parseUtc(ts: string): Date {
    return new Date(ts.includes('T') ? ts : `${ts.replace(' ', 'T')}Z`)
  }

  function scopeLabel(s: ApiTokenScope): string {
    const ll = get(LL)
    switch (s) {
      case 'read':
        return ll.mcpScopeRead()
      case 'fs_read':
        return ll.mcpScopeFsRead()
      case 'fs_write':
        return ll.mcpScopeFsWrite()
      case 'exec':
        return ll.mcpScopeExec()
      case 'process':
        return ll.mcpScopeProcess()
      case 'service':
        return ll.mcpScopeService()
      case 'container':
        return ll.mcpScopeContainer()
      case 'cron':
        return ll.mcpScopeCron()
      case 'virt':
        return ll.mcpScopeVirt()
      case 'stacks':
        return ll.mcpScopeStacks()
      case 'power':
        return ll.mcpScopePower()
    }
  }

  function effectivePolicyScopes(p: McpPolicy): ApiTokenScope[] {
    return p.scopes.filter((s) => p.config_scopes.includes(s))
  }

  function scopesSummary(list: ApiTokenScope[], cmds: McpCommandPolicy): string {
    const ll = get(LL)
    const scopePart =
      ALL_API_TOKEN_SCOPES.every((s) => list.includes(s))
        ? ll.mcpAllScopes()
        : list.length === 0
          ? '—'
          : list.map(scopeLabel).join(' · ')
    const cmdPart =
      cmds.mode === 'allowlist'
        ? ll.mcpModeAllowlist()
        : cmds.deny.length > 0
          ? `${ll.mcpModeAllowAll()} (-${cmds.deny.length})`
          : null
    return cmdPart ? `${scopePart} · ${cmdPart}` : scopePart
  }

  function tokenSub(token: ApiToken): string {
    const ll = get(LL)
    const used = token.last_used_at
      ? `${ll.mcpLastUsed()}: ${fmtDate(parseUtc(token.last_used_at), DATE_TIME)}`
      : ll.mcpNeverUsed()
    const exp = `${ll.mcpExpires()}: ${fmtDate(parseUtc(token.expires_at), DATE_TIME)}`
    return `${scopesSummary(token.scopes, token.commands)} · ${used} · ${exp}`
  }

  const lines = (t: string) =>
    t
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean)

  function toggleScope(list: ApiTokenScope[], item: ApiTokenScope, on: boolean): ApiTokenScope[] {
    if (on) return ALL_API_TOKEN_SCOPES.filter((s) => list.includes(s) || s === item)
    return list.filter((s) => s !== item)
  }

  let tokens = $state<ApiToken[]>([])
  let policy = $state<McpPolicy | null>(null)
  let loading = $state(true)
  let error = $state<string | null>(null)

  let endpointCopied = $state(false)

  // Global policy editor
  let globalScopes = $state<ApiTokenScope[]>([...ALL_API_TOKEN_SCOPES])
  let globalMode = $state<McpCommandMode>('allow_all')
  let globalAllow = $state('')
  let globalDeny = $state('')
  let savingPolicy = $state(false)
  let savedPolicy = $state(false)

  // New token form (defaults to full permissions)
  let name = $state('')
  let days = $state(90)
  let newPermsOpen = $state(false)
  let newScopes = $state<ApiTokenScope[]>([...ALL_API_TOKEN_SCOPES])
  let newMode = $state<McpCommandMode>('allow_all')
  let newAllow = $state('')
  let newDeny = $state('')
  let asking = $state(false)
  let mintTarget = $state<ServerEntry | undefined>(undefined)
  let created = $state<CreatedApiToken | null>(null)
  let tokenCopied = $state(false)

  // Existing token editor & revoke confirmation
  let editingId = $state<number | null>(null)
  let editName = $state('')
  let editScopes = $state<ApiTokenScope[]>([])
  let editMode = $state<McpCommandMode>('allow_all')
  let editAllow = $state('')
  let editDeny = $state('')
  let savingToken = $state(false)
  let confirmingRevokeId = $state<number | null>(null)

  const daysValid = $derived(Number.isInteger(days) && days >= 1 && days <= 3650)

  function fillPolicy(p: McpPolicy) {
    policy = p
    globalScopes = effectivePolicyScopes(p)
    globalMode = p.commands.mode
    globalAllow = p.commands.allow.join('\n')
    globalDeny = p.commands.deny.join('\n')
  }

  async function load() {
    if (!servers.authenticated) {
      loading = false
      return
    }
    const entry = servers.current
    const serverId = servers.currentId
    loading = true
    error = null
    try {
      const [loadedTokens, loadedPolicy] = await Promise.all([api.listApiTokens(entry), api.getMcpPolicy(entry)])
      if (scope.stale(serverId)) return
      tokens = loadedTokens
      fillPolicy(loadedPolicy)
    } catch (e) {
      if (scope.stale(serverId)) return
      error = accessMessage(e, get(LL))
    } finally {
      if (!scope.stale(serverId)) loading = false
    }
  }

  $effect(() => {
    void servers.currentId
    void servers.authenticated
    tokens = []
    policy = null
    asking = false
    mintTarget = undefined
    savingPolicy = false
    savingToken = false
    created = null
    editingId = null
    confirmingRevokeId = null
    void load()
  })

  async function savePolicy() {
    if (savingPolicy) return
    const entry = servers.current
    const serverId = servers.currentId
    savingPolicy = true
    savedPolicy = false
    error = null
    try {
      const updated = await api.saveMcpPolicy(
        {
          scopes: globalScopes,
          commands: { mode: globalMode, allow: lines(globalAllow), deny: lines(globalDeny) },
        },
        entry,
      )
      if (scope.stale(serverId)) return
      fillPolicy(updated)
      savedPolicy = true
      if (policySavedTimer) clearTimeout(policySavedTimer)
      policySavedTimer = setTimeout(() => (savedPolicy = false), 1500)
    } catch (e) {
      if (scope.stale(serverId)) return
      error = accessMessage(e, get(LL))
    } finally {
      if (!scope.stale(serverId)) savingPolicy = false
    }
  }

  function openMint() {
    mintTarget = servers.current ? { ...servers.current } : undefined
    asking = true
  }

  async function mint(password: string) {
    const entry = mintTarget
    const serverId = entry?.id ?? servers.currentId
    if (!entry || scope.stale(serverId)) return
    const res = await api.createApiToken(
      {
        name: name.trim(),
        password,
        scopes: newScopes,
        commands: { mode: newMode, allow: lines(newAllow), deny: lines(newDeny) },
        days,
      },
      entry,
    )
    if (scope.stale(serverId)) return
    created = res
    tokenCopied = false
    name = ''
    newScopes = [...ALL_API_TOKEN_SCOPES]
    newMode = 'allow_all'
    newAllow = ''
    newDeny = ''
    newPermsOpen = false
    asking = false
    mintTarget = undefined
    await load()
  }

  function startEdit(token: ApiToken) {
    if (editingId === token.id) {
      editingId = null
      return
    }
    editingId = token.id
    editName = token.name
    editScopes = [...token.scopes]
    editMode = token.commands.mode
    editAllow = token.commands.allow.join('\n')
    editDeny = token.commands.deny.join('\n')
  }

  async function saveToken(id: number) {
    if (savingToken || !editName.trim() || editScopes.length === 0) return
    const entry = servers.current
    const serverId = servers.currentId
    savingToken = true
    error = null
    try {
      await api.updateApiToken(
        id,
        {
          name: editName.trim(),
          scopes: editScopes,
          commands: { mode: editMode, allow: lines(editAllow), deny: lines(editDeny) },
        },
        entry,
      )
      if (scope.stale(serverId)) return
      editingId = null
      await load()
    } catch (e) {
      if (scope.stale(serverId)) return
      error = accessMessage(e, get(LL))
    } finally {
      if (!scope.stale(serverId)) savingToken = false
    }
  }

  async function revoke(token: ApiToken) {
    const entry = servers.current
    const serverId = servers.currentId
    error = null
    confirmingRevokeId = null
    try {
      await api.revokeApiToken(token.id, entry)
      if (scope.stale(serverId)) return
      if (editingId === token.id) editingId = null
      await load()
    } catch (e) {
      if (scope.stale(serverId)) return
      error = accessMessage(e, get(LL))
    }
  }

  async function copyEndpoint() {
    if (!navigator.clipboard?.writeText) return
    try {
      await navigator.clipboard.writeText(endpointUrl)
      endpointCopied = true
      if (endpointCopiedTimer) clearTimeout(endpointCopiedTimer)
      endpointCopiedTimer = setTimeout(() => (endpointCopied = false), 1500)
    } catch {
      // Clipboard unavailable over insecure origin.
    }
  }

  async function copyCreated() {
    if (!created || !navigator.clipboard?.writeText) return
    try {
      await navigator.clipboard.writeText(created.token_value)
      tokenCopied = true
    } catch {
      // Clipboard unavailable over insecure origin.
    }
  }
</script>

<SettingsPage title={$LL.mcpAccess()}>
  {#if !servers.authenticated}
    <p class="text-[13px] text-(--text-secondary)">{$LL.settingsNeedsAuth()}</p>
  {:else}
    {#if error}
      <p class="px-[2px] text-[13px] text-(--color-danger)">{error}</p>
    {/if}

    <Group>
      <Row label={$LL.mcpEndpoint()} sub={endpointUrl}>
        <Button size="sm" variant="secondary" onclick={copyEndpoint}>
          {endpointCopied ? $LL.mcpCopied() : $LL.mcpCopy()}
        </Button>
      </Row>
    </Group>

    {#if policy}
      <Group title={$LL.mcpGlobalPolicy()}>
        <div class="flex flex-col gap-[11px] px-[13px] py-[13px]">
          <div class="flex flex-wrap gap-x-[15px] gap-y-[9px]">
            {#each ALL_API_TOKEN_SCOPES as s (s)}
              {@const allowedByConfig = policy.config_scopes.includes(s)}
              <Checkbox
                checked={globalScopes.includes(s) && allowedByConfig}
                disabled={!allowedByConfig}
                label={scopeLabel(s)}
                onchange={(e) => (globalScopes = toggleScope(globalScopes, s, e.currentTarget.checked))}
              />
            {/each}
          </div>
          {#if globalScopes.includes('exec')}
            <div class="flex items-center justify-between gap-[9px]">
              <span class="text-[13px]">{$LL.mcpCommandMode()}</span>
              <SegmentedControl
                size="sm"
                value={globalMode}
                onchange={(v) => (globalMode = v as McpCommandMode)}
                options={[
                  { value: 'allow_all', label: $LL.mcpModeAllowAll() },
                  { value: 'allowlist', label: $LL.mcpModeAllowlist() },
                ]}
              />
            </div>
            <Textarea label={$LL.settingsAgentRulesDeny()} mono rows={2} placeholder="rm -rf *" bind:value={globalDeny} />
            {#if globalMode === 'allowlist'}
              <Textarea label={$LL.settingsAgentRulesAllow()} mono rows={2} placeholder="df *" bind:value={globalAllow} />
            {/if}
          {/if}
          <div class="flex items-center justify-end gap-[9px]">
            {#if savedPolicy}<span class="text-[12px] text-(--text-tertiary)">{$LL.settingsAgentSaved()}</span>{/if}
            <Button size="sm" variant="primary" disabled={savingPolicy} onclick={savePolicy}>
              {#if savingPolicy}<Spinner size={14} />{/if}
              {$LL.save()}
            </Button>
          </div>
        </div>
      </Group>
    {/if}

    <Group title={$LL.mcpTokens()}>
      {#if created}
        <Row label={$LL.mcpTokenCreated()} sub={created.name}>
          <div class="flex items-center gap-[9px]">
            <Input class="w-[240px] lk-mono" readonly value={created.token_value} />
            <Button size="sm" variant="secondary" onclick={copyCreated}>{tokenCopied ? $LL.mcpCopied() : $LL.mcpCopy()}</Button>
            <Button size="sm" variant="secondary" onclick={() => { created = null; tokenCopied = false }}>{$LL.mcpOk()}</Button>
          </div>
        </Row>
      {/if}

      {#each tokens as token (token.id)}
        <Row label={token.name} sub={tokenSub(token)}>
          <div class="flex items-center gap-[7px]">
            {#if token.expired}
              <Badge tone="danger">{$LL.mcpExpired()}</Badge>
            {/if}
            <Button size="sm" variant="secondary" onclick={() => startEdit(token)}>{$LL.mcpEdit()}</Button>
            {#if confirmingRevokeId === token.id}
              <Button size="sm" variant="destructive" onclick={() => revoke(token)}>{$LL.mcpConfirmRevoke()}</Button>
              <Button size="sm" variant="ghost" onclick={() => (confirmingRevokeId = null)}>{$LL.cancel()}</Button>
            {:else}
              <Button size="sm" variant="destructive" onclick={() => (confirmingRevokeId = token.id)}>{$LL.mcpRevoke()}</Button>
            {/if}
          </div>
        </Row>
        {#if editingId === token.id}
          <div class="flex flex-col gap-[11px] border-t border-(--border-subtle) px-[13px] py-[13px]">
            <Input bind:value={editName} placeholder={$LL.mcpTokenName()} />
            <div class="flex flex-wrap gap-x-[15px] gap-y-[9px]">
              {#each ALL_API_TOKEN_SCOPES as s (s)}
                <Checkbox
                  checked={editScopes.includes(s)}
                  label={scopeLabel(s)}
                  onchange={(e) => (editScopes = toggleScope(editScopes, s, e.currentTarget.checked))}
                />
              {/each}
            </div>
            {#if editScopes.includes('exec')}
              <div class="flex items-center justify-between gap-[9px]">
                <span class="text-[13px]">{$LL.mcpCommandMode()}</span>
                <SegmentedControl
                  size="sm"
                  value={editMode}
                  onchange={(v) => (editMode = v as McpCommandMode)}
                  options={[
                    { value: 'allow_all', label: $LL.mcpModeAllowAll() },
                    { value: 'allowlist', label: $LL.mcpModeAllowlist() },
                  ]}
                />
              </div>
              <Textarea label={$LL.settingsAgentRulesDeny()} mono rows={2} placeholder="rm -rf *" bind:value={editDeny} />
              {#if editMode === 'allowlist'}
                <Textarea label={$LL.settingsAgentRulesAllow()} mono rows={2} placeholder="git status *" bind:value={editAllow} />
              {/if}
            {/if}
            <div class="flex items-center justify-end gap-[9px]">
              <Button size="sm" variant="ghost" onclick={() => (editingId = null)}>{$LL.cancel()}</Button>
              <Button
                size="sm"
                variant="primary"
                disabled={savingToken || !editName.trim() || editScopes.length === 0}
                onclick={() => saveToken(token.id)}
              >
                {#if savingToken}<Spinner size={14} />{/if}
                {$LL.save()}
              </Button>
            </div>
          </div>
        {/if}
      {/each}

      {#if loading}
        <Row label={$LL.mcpLoading()}><Spinner size={16} /></Row>
      {:else if tokens.length === 0 && !created}
        <Row label={$LL.mcpNoTokens()}><span></span></Row>
      {/if}

      <Row label={$LL.mcpNewToken()} sub={scopesSummary(newScopes, { mode: newMode, allow: lines(newAllow), deny: lines(newDeny) })}>
        <div class="flex flex-wrap items-center justify-end gap-[9px]">
          <Input class="w-[150px]" bind:value={name} placeholder={$LL.mcpTokenName()} />
          <label class="flex items-center gap-[5px] text-[12px] text-(--text-secondary)">
            {$LL.mcpDays()}
            <Input class="w-[70px] lk-num" type="number" min={1} max={3650} bind:value={days} />
          </label>
          <Button size="sm" variant="secondary" onclick={() => (newPermsOpen = !newPermsOpen)}>{$LL.mcpEdit()}</Button>
          <Button
            size="sm"
            variant="primary"
            disabled={!name.trim() || newScopes.length === 0 || !daysValid}
            onclick={openMint}>{$LL.mcpCreate()}</Button>
        </div>
      </Row>
      {#if newPermsOpen}
        <div class="flex flex-col gap-[11px] border-t border-(--border-subtle) px-[13px] py-[13px]">
          <div class="flex flex-wrap gap-x-[15px] gap-y-[9px]">
            {#each ALL_API_TOKEN_SCOPES as s (s)}
              <Checkbox
                checked={newScopes.includes(s)}
                label={scopeLabel(s)}
                onchange={(e) => (newScopes = toggleScope(newScopes, s, e.currentTarget.checked))}
              />
            {/each}
          </div>
          {#if newScopes.includes('exec')}
            <div class="flex items-center justify-between gap-[9px]">
              <span class="text-[13px]">{$LL.mcpCommandMode()}</span>
              <SegmentedControl
                size="sm"
                value={newMode}
                onchange={(v) => (newMode = v as McpCommandMode)}
                options={[
                  { value: 'allow_all', label: $LL.mcpModeAllowAll() },
                  { value: 'allowlist', label: $LL.mcpModeAllowlist() },
                ]}
              />
            </div>
            <Textarea label={$LL.settingsAgentRulesDeny()} mono rows={2} placeholder="rm -rf *" bind:value={newDeny} />
            {#if newMode === 'allowlist'}
              <Textarea label={$LL.settingsAgentRulesAllow()} mono rows={2} placeholder="git status *" bind:value={newAllow} />
            {/if}
          {/if}
        </div>
      {/if}
    </Group>

    <ReauthDialog
      open={asking}
      message={$LL.mcpCreate()}
      onconfirm={mint}
      onclose={() => {
        asking = false
        mintTarget = undefined
      }}
    />
  {/if}
</SettingsPage>
