<script lang="ts">
  /// Accounts and roles on this agent, for an administrator.
  ///
  /// Every change goes through one `ReauthDialog`: what is asked for here is
  /// who can do what on the machine, so each request carries the
  /// administrator's own password rather than riding on the session.

  import { Pencil, Plus, Trash2, KeyRound } from '@lucide/svelte'
  import { Badge, Button, Card, IconButton, Input, Modal, Select, Spinner } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import { accessMessage, draftFromRole, emptyDraft, type RoleDraft } from '../lib/access'
  import { api } from '../lib/api'
  import type { AgentUser, Role, RoleGrants } from '../types'
  import ReauthDialog from './ReauthDialog.svelte'
  import RoleEditor from './RoleEditor.svelte'

  interface Props {
    /// After a change that may have altered this session's own access.
    onchanged?: () => void
  }

  const { onchanged }: Props = $props()

  let users = $state<AgentUser[]>([])
  let roles = $state<Role[]>([])
  let loading = $state(true)
  let loadError = $state<string | null>(null)

  /// The change waiting for the administrator's password.
  let pending = $state<{ message?: string; run: (password: string) => Promise<void> } | null>(null)

  let newUser = $state('')
  let newPassword = $state('')
  let newRole = $state('viewer')

  /// Whose password is being reset, and to what.
  let resetFor = $state<string | null>(null)
  let resetPassword = $state('')

  let editorOpen = $state(false)
  let editorDraft = $state<RoleDraft>(emptyDraft())
  let editorExisting = $state(false)

  async function load() {
    loading = true
    loadError = null
    try {
      const [u, r] = await Promise.all([api.listUsers(), api.listRoles()])
      users = u
      roles = r
    } catch (e) {
      loadError = accessMessage(e, $LL)
    } finally {
      loading = false
    }
  }

  $effect(() => {
    void load()
  })

  /// Asks for the password, runs [run] with it, and reloads either way — a
  /// role picked in a select and then cancelled is put back by the reload.
  function ask(run: (password: string) => Promise<void>, message?: string) {
    pending = {
      message,
      run: async (password) => {
        await run(password)
        onchanged?.()
      },
    }
  }

  function closeReauth() {
    pending = null
    void load()
  }

  function addUser(event: SubmitEvent) {
    event.preventDefault()
    const name = newUser.trim()
    if (!name || !newPassword) return
    const password = newPassword
    const role = newRole
    ask(async (pw) => {
      await api.createUser(name, password, role, pw)
      newUser = ''
      newPassword = ''
    })
  }

  function changeRole(user: AgentUser, role: string) {
    if (role === user.role) return
    ask((pw) => api.updateUser(user.username, { role }, pw).then(() => {}))
  }

  function submitReset(event: SubmitEvent) {
    event.preventDefault()
    const target = resetFor
    const password = resetPassword
    if (!target || password.length < 8) return
    resetFor = null
    resetPassword = ''
    ask((pw) => api.updateUser(target, { password }, pw).then(() => {}))
  }

  function removeUser(user: AgentUser) {
    ask((pw) => api.deleteUser(user.username, pw), $LL.confirmDeleteAccount({ name: user.username }))
  }

  function openEditor(role: Role | null) {
    editorExisting = role !== null
    // A role read from this agent says whether it knows `virt`.
    editorDraft = role ? draftFromRole(role) : emptyDraft(roles.some((r) => r.grants.virt !== undefined))
    editorOpen = true
  }

  function saveRole(role: Role) {
    const existing = editorExisting
    ask(async (pw) => {
      if (existing) {
        await api.updateRole(role, pw)
      } else {
        const { builtin: _builtin, ...created } = role
        await api.createRole(created, pw)
      }
      editorOpen = false
    })
  }

  function removeRole(role: Role) {
    ask((pw) => api.deleteRole(role.name, pw), $LL.confirmDeleteRole({ name: role.name }))
  }

  /// What a role holds, in a line.
  function summary(g: RoleGrants): string {
    const parts: string[] = []
    if (g.shell) parts.push($LL.grantShell())
    if (g.ssh_terminal) parts.push($LL.grantSshTerminal())
    if (g.files) parts.push(`${$LL.grantFiles()} (${g.files.mode === 'read' ? $LL.filesRead() : $LL.filesWrite()})`)
    if (g.connect) parts.push($LL.grantConnect())
    if (g.listen) parts.push($LL.grantListen())
    return parts.length ? parts.join(' · ') : $LL.roleViewOnly()
  }

  function when(t: string | null): string {
    return t ? new Date(t).toLocaleString() : $LL.neverSignedIn()
  }
</script>

{#if loading}
  <div class="flex justify-center py-6"><Spinner /></div>
{:else if loadError}
  <p class="text-sm text-danger">{loadError}</p>
{:else}
  <Card class="space-y-4">
    <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.accounts()}</h2>
    <div class="divide-y divide-line">
      {#each users as user (user.username)}
        <div class="flex flex-wrap items-center gap-3 py-2 first:pt-0 last:pb-0">
          <span class="flex-1 min-w-0">
            <span class="block text-sm font-mono truncate">{user.username}</span>
            <span class="block text-xs text-faint-fg">{$LL.lastLogin()}: {when(user.last_login)}</span>
          </span>
          <Select
            value={user.role}
            onchange={(e) => changeRole(user, (e.currentTarget as HTMLSelectElement).value)}
            aria-label={$LL.accountRole()}
          >
            {#each roles as role (role.name)}
              <option value={role.name}>{role.name}</option>
            {/each}
          </Select>
          <IconButton label={$LL.resetPassword()} onclick={() => ((resetFor = user.username), (resetPassword = ''))}>
            <KeyRound class="w-4 h-4" />
          </IconButton>
          <IconButton label={$LL.deleteAccount()} class="hover:text-danger" onclick={() => removeUser(user)}>
            <Trash2 class="w-4 h-4" />
          </IconButton>
        </div>
      {/each}
    </div>
    <form class="grid grid-cols-1 sm:grid-cols-[1fr_1fr_auto_auto] gap-2 items-end" onsubmit={addUser}>
      <div class="space-y-1">
        <span class="text-xs text-muted-fg">{$LL.username()}</span>
        <Input bind:value={newUser} autocomplete="off" />
      </div>
      <div class="space-y-1">
        <span class="text-xs text-muted-fg">{$LL.password()}</span>
        <Input type="password" autocomplete="new-password" bind:value={newPassword} />
      </div>
      <Select bind:value={newRole} aria-label={$LL.accountRole()}>
        {#each roles as role (role.name)}
          <option value={role.name}>{role.name}</option>
        {/each}
      </Select>
      <Button size="sm" variant="secondary" type="submit" disabled={!newUser.trim() || newPassword.length < 8}>
        <Plus class="w-4 h-4 mr-1" />{$LL.addAccount()}
      </Button>
    </form>
  </Card>

  <Card class="space-y-4">
    <div class="flex items-center justify-between gap-2">
      <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.roles()}</h2>
      <Button size="sm" variant="secondary" onclick={() => openEditor(null)}>
        <Plus class="w-4 h-4 mr-1" />{$LL.addRole()}
      </Button>
    </div>
    <div class="divide-y divide-line">
      {#each roles as role (role.name)}
        <div class="flex items-center gap-3 py-2 first:pt-0 last:pb-0">
          <span class="flex-1 min-w-0">
            <span class="flex items-center gap-2 text-sm">
              <span class="font-mono">{role.name}</span>
              {#if role.admin}<Badge tone="success">{$LL.roleAdmin()}</Badge>{/if}
              {#if role.builtin}<Badge>{$LL.roleBuiltin()}</Badge>{/if}
            </span>
            <span class="block text-xs text-faint-fg truncate">{summary(role.grants)}</span>
          </span>
          <IconButton label={$LL.editRole()} onclick={() => openEditor(role)}>
            <Pencil class="w-4 h-4" />
          </IconButton>
          {#if !role.builtin}
            <IconButton label={$LL.deleteRole()} class="hover:text-danger" onclick={() => removeRole(role)}>
              <Trash2 class="w-4 h-4" />
            </IconButton>
          {/if}
        </div>
      {/each}
    </div>
  </Card>
{/if}

<Modal open={resetFor !== null} title={$LL.resetPassword()} onclose={() => (resetFor = null)}>
  <form class="space-y-4" onsubmit={submitReset}>
    <p class="text-sm font-mono">{resetFor}</p>
    <div class="space-y-1">
      <span class="text-sm text-muted-fg">{$LL.newPassword()}</span>
      <Input type="password" autocomplete="new-password" bind:value={resetPassword} />
    </div>
    {#if resetPassword && resetPassword.length < 8}
      <p class="text-xs text-faint-fg">{$LL.passwordTooShort()}</p>
    {/if}
    <div class="flex justify-end gap-2">
      <Button variant="ghost" type="button" onclick={() => (resetFor = null)}>{$LL.cancel()}</Button>
      <Button type="submit" disabled={resetPassword.length < 8}>{$LL.confirm()}</Button>
    </div>
  </form>
</Modal>

<RoleEditor
  open={editorOpen}
  draft={editorDraft}
  existing={editorExisting}
  onsave={saveRole}
  onclose={() => (editorOpen = false)}
/>

<ReauthDialog
  open={pending !== null}
  message={pending?.message}
  onconfirm={(password) => pending!.run(password)}
  onclose={closeReauth}
/>
