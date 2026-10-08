<script lang="ts">
  import Spinner from '@lollipopkit/desk-ui/Spinner.svelte'
  import { AppToolbar } from '../../sys'
  import { Badge, Button, Card, Checkbox, Dialog, Icon, IconButton, Input } from '@lollipopkit/desk-ui'
  import UserForm, { userFormState, type UserFormState } from './UserForm.svelte'
  import UserSecurity from './UserSecurity.svelte'
  import { api } from '../../../lib/api'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { untrack } from 'svelte'
  import { userRefusalText } from '../../../lib/userRefusal'
  import type { UserRow, UserView } from '../../../types'

  let view = $state<UserView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  /// Set after a write lands and cleared by the next one. Worth saying because
  /// the row it names has changed under the list that is still on screen.
  let notice = $state('')
  /// What went wrong with a write, the machine's own words where it said
  /// anything — they are the only thing that distinguishes one failure from
  /// another.
  let actionError = $state('')
  /// The filter is the page's own: it is not a question for the machine, and
  /// leaving the page undoes it.
  let query = $state('')
  /// The account whose detail is open, the account the form is about
  /// (`undefined` for a new one, `null` while the detail's own row is on
  /// screen), and the account waiting for a `sudo` password.
  let opened = $state<UserRow | undefined>(undefined)
  let editing = $state<UserRow | null | undefined>(undefined)
  /// The form's fields, seeded when the dialog opens and edited in place by the
  /// form itself — so a refresh that replaces the row cannot change what is on
  /// screen mid-edit, and neither can a prop.
  let formState = $state<UserFormState>(userFormState())
  let removing = $state(false)
  let removeHome = $state(false)
  let needsSudo = $state(false)
  let sudoPassword = $state('')

  /// A reply that arrives after the desk has switched servers belongs to
  /// neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getSystemUsers()
      if (stale(serverId)) return
      view = next
      // The open account is replaced by the fresh row of the same name, so the
      // dialog shows what the write just produced — and closes by itself where
      // the account is gone.
      if (opened) {
        opened = next.users.find((user) => user.name === opened?.name)
        if (!opened) removing = false
      }
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    // Only the machine on screen re-runs this.
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  async function remove(asRoot = false) {
    const user = opened
    if (!user) return
    busy = true
    notice = ''
    actionError = ''
    try {
      const result = await api.actSystemUser({
        action: 'delete',
        name: user.name,
        remove_home: removeHome,
        ...(asRoot && sudoPassword ? { password: sudoPassword } : {}),
      })
      if (result.sudo_rejected) {
        // The removal needs an account the agent does not have. There is one way
        // forward and it is that account, so the dialog asks for what that needs
        // rather than reporting a refusal — unless this *was* the second
        // attempt, which has nowhere left to go.
        if (asRoot) actionError = $LL.powerRejected()
        else needsSudo = true
        return
      }
      if (!result.succeeded) {
        actionError = result.stderr.trim() || result.stdout.trim() || $LL.userCommandFailed()
        return
      }
      notice = $LL.userDoneDeleted({ name: user.name })
      opened = undefined
      removing = false
      needsSudo = false
      sudoPassword = ''
      await load()
    } catch (e) {
      actionError = userRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      busy = false
    }
  }

  function open(user: UserRow) {
    opened = user
    removing = false
    needsSudo = false
    sudoPassword = ''
    actionError = ''
  }

  function openForm(user: UserRow | null) {
    formState = userFormState(user ?? undefined)
    editing = user
    actionError = ''
  }

  function onSaved(name: string, created: boolean) {
    notice = created ? $LL.userDoneCreated({ name }) : $LL.userDoneEdited({ name })
    editing = undefined
    void load()
  }

  const users = $derived(view?.users ?? [])

  const visible = $derived.by(() => {
    const needle = query.trim().toLowerCase()
    if (!needle) return users
    return users.filter(
      (user) =>
        user.name.toLowerCase().includes(needle) ||
        user.home.toLowerCase().includes(needle) ||
        String(user.uid).includes(needle),
    )
  })

  function reasonText(reason: UserView): string {
    switch (reason.reason_kind) {
      case 'unsupported_platform':
        return $LL.userUnsupportedPlatform()
      case 'unreadable':
        return $LL.userUnreadable()
      case 'no_such_user':
        return $LL.userNoSuchUser()
      default:
        // What the machine said, verbatim: it is the only thing that
        // distinguishes one failure from another.
        return reason.reason ?? $LL.userUnreadable()
    }
  }

  function subtitle(): string | undefined {
    if (!view?.available) return undefined
    return $LL.userSubtitle({ count: users.length })
  }

  /// The accounts in the two groups the machine's own flag draws: the ones
  /// somebody logs in as, and the ones the system keeps for itself. The order
  /// inside each is the machine's, and a group nobody is in is not drawn.
  const grouped = $derived.by(() => {
    const groups = [
      { id: 'regular', label: () => $LL.systemUsersGroupRegular(), users: visible.filter((user) => !user.system) },
      { id: 'system', label: () => $LL.systemUsersGroupSystem(), users: visible.filter((user) => user.system) },
    ]
    return groups.filter((group) => group.users.length > 0)
  })
</script>

<AppToolbar subtitle={subtitle()}>
  {#snippet actions()}
    {#if view?.available}<Button size="sm" variant="tinted" icon="add" onclick={() => openForm(null)}>{$LL.userAdd()}</Button>{/if}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} disabled={loading} />
  {/snippet}
</AppToolbar>

<main class="space-y-[13px] px-(--content-pad) pb-[21px] pt-[5px]">
  {#if error}<Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card>{/if}
  {#if notice}<Card><p class="text-[13px] text-(--text-secondary)">{notice}</p></Card>{/if}

  {#if loading && !view}
    <Card class="grid place-items-center" padding="21px"><Spinner class="h-5 w-5" /></Card>
  {:else if view && !view.available}
    <Card>
      <p class="text-[13px] text-(--text-secondary)">{reasonText(view)}</p>
      {#if view.reason && view.reason_kind !== 'unsupported_platform'}<pre class="lk-mono mt-[9px] whitespace-pre-wrap break-all text-[12px] text-(--text-tertiary)">{view.reason}</pre>{/if}
    </Card>
  {:else if view}
    <Input bind:value={query} icon="search" placeholder={$LL.userSearchHint()} />

    {#if visible.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
        <Icon name="group" size={48} weight={300} />
        <span class="text-[13px]">{query ? $LL.systemUsersNoMatch() : $LL.systemUsersEmptyState()}</span>
        {#if !query}<p class="max-w-md text-center text-[12px]">{$LL.userEmpty()}</p>{/if}
      </div>
    {:else}
      <!-- One account per card, under the group the machine's own flag puts it
           in. The card opens details and account actions. -->
      {#each grouped as group (group.id)}
        <section class="space-y-[7px]">
          <h2 class="lk-caps px-[3px]">{group.label()}</h2>
          <ul class="space-y-[7px]">
            {#each group.users as user (user.name)}
              <li>
                <Card padding="11px 13px" onclick={() => open(user)}>
                  <div class="flex min-w-0 items-center gap-[13px]">
                    <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised) text-(--color-accent-text)">
                      <Icon name={user.is_root ? 'key' : 'person'} size={18} />
                    </span>
                    <div class="min-w-0 flex-1">
                      <div class="flex flex-wrap items-center gap-[7px]">
                        <span class="truncate text-[13px] font-semibold">{user.name}</span>
                        <!-- Flags come from the agent; the panel does not infer them. -->
                        {#if user.is_root}<Badge tone="danger">{$LL.userSuperuser()}</Badge>{/if}
                        {#if user.agent_account}<Badge tone="neutral">{$LL.userCurrent()}</Badge>{/if}
                        {#if user.login_disabled}<Badge tone="warning">{$LL.userLoginDisabled()}</Badge>{/if}
                      </div>
                      <p class="lk-num truncate text-[12px] text-(--text-tertiary)">
                        {$LL.userUid()} {user.uid} · <span class="lk-mono">{user.home}</span>
                        {#if user.shell} · <span class="lk-mono">{user.shell}</span>{/if}
                      </p>
                    </div>
                  </div>
                </Card>
              </li>
            {/each}
          </ul>
        </section>
      {/each}
    {/if}

    {#if busy}<div class="flex items-center gap-[7px] px-[3px] text-[12px] text-(--text-tertiary)"><Spinner size="sm" /></div>{/if}
  {/if}
</main>

<!-- One account: the machine's state, security records and available actions.
     The form replaces this dialog; `opened` stays set so closing it returns to
     the account after the write. -->
{#if opened && editing === undefined}
  {@const user = opened}
  <Dialog open wide title={user.name} onclose={() => (opened = undefined)}>
    {#snippet actions()}
      {#if !removing}
        <Button variant="secondary" icon="edit" onclick={() => openForm(user)}>{$LL.userEdit()}</Button>
        <!-- Whether it may be removed comes from the agent. -->
        <Button variant="destructive" icon="delete" disabled={!user.deletable} onclick={() => (removing = true)}>{$LL.userDelete()}</Button>
        <Button variant="secondary" onclick={() => (opened = undefined)}>{$LL.close()}</Button>
      {:else}
        <Button variant="destructive" disabled={busy} onclick={() => void remove(needsSudo)}>{$LL.userDelete()}</Button>
        <Button variant="secondary" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
      {/if}
    {/snippet}
    {#if removing}<p class="mb-[13px] text-[13px] text-(--text-secondary)">{$LL.userDeleteConfirm({ name: user.name })}</p>{/if}
    <div class="flex flex-wrap gap-[7px]">
      {#if user.is_root}<Badge tone="danger">{$LL.userSuperuser()}</Badge>{/if}
      {#if user.agent_account}<Badge tone="neutral">{$LL.userCurrent()}</Badge>{/if}
      {#if user.system}<Badge tone="neutral">{$LL.userSystemAccount()}</Badge>{/if}
      {#if user.login_disabled}<Badge tone="warning">{$LL.userLoginDisabled()}</Badge>{/if}
    </div>
    <dl class="mt-[13px] grid grid-cols-2 gap-x-[13px] @2xl:grid-cols-3">
      <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.userUid()}</dt><dd class="lk-num text-right">{user.uid} · {user.gid}</dd></div>
      <div class="col-span-1 border-t border-(--border-hairline) py-[7px] @2xl:col-span-2"><dt class="text-[12px] text-(--text-secondary)">{$LL.userHome()}</dt><dd class="lk-mono break-all text-right text-[12px]">{user.home}{#if user.shell} · {user.shell}{/if}</dd></div>
      <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.userPrimaryGroup()}</dt><dd class="text-right">{user.primary_group ?? '—'}</dd></div>
      <div class="col-span-1 border-t border-(--border-hairline) py-[7px] @2xl:col-span-2"><dt class="text-[12px] text-(--text-secondary)">{$LL.userSupplementaryGroups()}</dt><dd class="break-all text-right text-[12px]">{user.supplementary_groups.join(', ') || $LL.userPasswordNone()}</dd></div>
    </dl>
    {#if removing}
      <div class="mt-[13px] grid gap-[9px]">
        <Checkbox bind:checked={removeHome} label={$LL.userRemoveHome()} />
        {#if needsSudo}
          <!-- The second attempt. The password travels separately, never in the
               machine's process list or the agent's audit row. -->
          <Input id="user-delete-sudo" label={$LL.powerPassword()} type="password" bind:value={sudoPassword} hint={$LL.powerPasswordHint()} />
        {/if}
      </div>
    {/if}
    {#if actionError}<pre class="mt-[9px] whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{actionError}</pre>{/if}
    {#if !user.deletable && !removing}<p class="mt-[9px] text-[12px] text-(--text-tertiary)">{user.is_root ? $LL.userRootNotDeletable() : $LL.userAgentAccount()}</p>{/if}
    <!-- These machine records are fetched when an account is opened. -->
    <div class="mt-[13px]"><UserSecurity userName={user.name} /></div>
  </Dialog>
{/if}

{#if editing !== undefined}
  <Dialog open wide title={editing ? $LL.userEdit() : $LL.userAdd()} onclose={() => (editing = undefined)}>
    <UserForm
      user={editing ?? undefined}
      fields={formState}
      onsaved={onSaved}
      oncancel={() => (editing = undefined)}
    />
  </Dialog>
{/if}
