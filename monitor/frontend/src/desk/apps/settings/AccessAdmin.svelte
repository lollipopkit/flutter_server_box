<script lang="ts">
  import { DATE_TIME, fmtDate } from '../../../lib/format'
  /// Accounts and roles on this agent, for an administrator.
  ///
  /// Every change goes through one `ReauthDialog`: what is asked for here is
  /// who can do what on the machine, so each request carries the
  /// administrator's own password rather than riding on the session.

  import { Badge, Button, Dialog, Group, IconButton, Input, Row, Select, Spinner } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { accessMessage, draftFromRole, emptyDraft, type RoleDraft } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import type { AgentUser, Role, RoleGrants } from '../../../types'
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
    if (g.virt) parts.push($LL.grantVirt())
    return parts.length ? parts.join(' · ') : $LL.roleViewOnly()
  }

  function when(t: string | null): string {
    return t ? fmtDate(new Date(t), DATE_TIME) : $LL.neverSignedIn()
  }
</script>

{#if loading}
  <div class="flex justify-center py-6"><Spinner size={32} /></div>
{:else if loadError}
  <p class="text-[13px] text-(--color-danger)">{loadError}</p>
{:else}
  <Group title={$LL.accounts()}>
    {#each users as user (user.username)}
      <Row label={user.username} sub={`${$LL.lastLogin()}: ${when(user.last_login)}`}>
        <div class="flex items-center gap-[5px]">
          <Select
            class="w-[170px]"
            value={user.role}
            options={roles.map((role) => ({ value: role.name, label: role.name }))}
            onchange={(event: Event) => changeRole(user, (event.currentTarget as HTMLSelectElement).value)}
            aria-label={$LL.accountRole()}
          />
          <IconButton icon="key" label={$LL.resetPassword()} onclick={() => ((resetFor = user.username), (resetPassword = ''))} />
          <IconButton icon="delete" label={$LL.deleteAccount()} onclick={() => removeUser(user)} />
        </div>
      </Row>
    {/each}
    <form class="grid gap-[9px] py-[7px] @2xl:grid-cols-[1fr_1fr_auto_auto]" onsubmit={addUser}>
      <Input label={$LL.username()} bind:value={newUser} autocomplete="off" />
      <Input label={$LL.password()} type="password" autocomplete="new-password" bind:value={newPassword} />
      <Select class="w-[170px]" bind:value={newRole} aria-label={$LL.accountRole()} options={roles.map((role) => ({ value: role.name, label: role.name }))} />
      <Button size="sm" variant="tinted" type="submit" icon="add" disabled={!newUser.trim() || newPassword.length < 8}>{$LL.addAccount()}</Button>
    </form>
  </Group>

  <Group title={$LL.roles()}>
    <div class="flex justify-end py-[7px]">
      <Button size="sm" variant="tinted" icon="add" onclick={() => openEditor(null)}>{$LL.addRole()}</Button>
    </div>
    {#each roles as role (role.name)}
      <Row label={role.name} sub={summary(role.grants)}>
        <div class="flex items-center gap-[5px]">
          {#if role.admin}<Badge tone="success">{$LL.roleAdmin()}</Badge>{/if}
          {#if role.builtin}<Badge>{$LL.roleBuiltin()}</Badge>{/if}
          <IconButton icon="edit" label={$LL.editRole()} onclick={() => openEditor(role)} />
          {#if !role.builtin}<IconButton icon="delete" label={$LL.deleteRole()} onclick={() => removeRole(role)} />{/if}
        </div>
      </Row>
    {/each}
  </Group>
{/if}

<Dialog open={resetFor !== null} wide title={$LL.resetPassword()} onclose={() => (resetFor = null)}>
  <form id="reset-password-form" class="space-y-[13px]" onsubmit={submitReset}>
    <p class="lk-mono text-[13px]">{resetFor}</p>
    <Input label={$LL.newPassword()} type="password" autocomplete="new-password" bind:value={resetPassword} />
    {#if resetPassword && resetPassword.length < 8}<p class="text-[12px] text-(--text-tertiary)">{$LL.passwordTooShort()}</p>{/if}
  </form>
  {#snippet actions()}
    <Button variant="secondary" type="button" onclick={() => (resetFor = null)}>{$LL.cancel()}</Button>
    <Button type="submit" form="reset-password-form" disabled={resetPassword.length < 8}>{$LL.confirm()}</Button>
  {/snippet}
</Dialog>

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
