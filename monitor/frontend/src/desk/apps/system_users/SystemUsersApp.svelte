<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import { Pencil, Plus, RefreshCw, Search, Trash2 } from '@lucide/svelte'
  import UserForm, { userFormState, type UserFormState } from './UserForm.svelte'
  import UserSecurity from './UserSecurity.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
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
    {#if view?.available}
      <IconButton label={$LL.userAdd()} onclick={() => openForm(null)}>
        <Plus class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} onclick={() => void load()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</AppToolbar>

<main class="mx-auto max-w-3xl space-y-3 px-4 py-4 @3xl:px-6">
  {#if error}
    <Card class="border-danger/40 bg-danger/5 p-3">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}

  {#if notice}
    <Card class="p-3">
      <p class="text-sm text-muted-fg">{notice}</p>
    </Card>
  {/if}

  {#if loading && !view}
    <Card class="grid place-items-center p-8"><Spinner class="h-5 w-5" /></Card>
  {:else if view && !view.available}
    <Card class="space-y-2 p-4">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
      {#if view.reason && view.reason_kind !== 'unsupported_platform'}
        <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.reason}</pre>
      {/if}
    </Card>
  {:else if view}
    <div class="relative">
      <Search class="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-faint-fg" />
      <Input class="pl-8" bind:value={query} placeholder={$LL.userSearchHint()} />
    </div>

    {#if visible.length === 0}
      <Card class="p-4">
        <p class="text-sm text-muted-fg">{query ? $LL.userNoMatch() : $LL.userEmpty()}</p>
      </Card>
    {:else}
      <!-- One account per card, under the group the machine's own flag puts it
           in. The two things that may be done to an account are in the dialog
           the card opens, so a write is always taken with the account on
           screen. -->
      {#each grouped as group (group.id)}
        <section class="space-y-2">
          <h2 class="px-1 text-[0.7rem] font-semibold uppercase tracking-wide text-muted-fg">
            {group.label()}
          </h2>
          <ul class="space-y-2">
            {#each group.users as user (user.name)}
              <li>
                <button
                  class="flex w-full items-center gap-3 rounded-xl border border-line bg-surface px-3 py-2.5 text-left transition-colors hover:bg-soft/40"
                  onclick={() => open(user)}
                >
                  <!-- The initial is the name's own letter, so it says nothing
                       a screen reader has not already read out. -->
                  <span
                    class="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-soft text-xs font-semibold text-muted-fg"
                    aria-hidden="true"
                  >
                    {user.name.slice(0, 1).toUpperCase()}
                  </span>
                  <span class="min-w-0 flex-1">
                    <span class="flex flex-wrap items-baseline gap-2">
                      <span class="truncate text-[0.85rem] font-medium text-fg-strong">{user.name}</span>
                      <!-- Every flag here is the agent's answer, not a rule derived
                           from the row: which account it runs as and which ones it
                           would refuse to remove are things only it knows. -->
                      {#if user.is_root}
                        <Badge tone="danger">{$LL.userSuperuser()}</Badge>
                      {/if}
                      {#if user.agent_account}
                        <Badge tone="neutral">{$LL.userCurrent()}</Badge>
                      {/if}
                      {#if user.login_disabled}
                        <Badge tone="warning">{$LL.userLoginDisabled()}</Badge>
                      {/if}
                    </span>
                    <span class="mt-0.5 block truncate text-xs text-muted-fg">
                      {$LL.userUid()} {user.uid} · {user.home}
                      {#if user.shell} · {user.shell}{/if}
                    </span>
                  </span>
                </button>
              </li>
            {/each}
          </ul>
        </section>
      {/each}
    {/if}

    {#if busy}
      <div class="flex items-center gap-2 px-1 text-xs text-muted-fg">
        <Spinner size="sm" />
      </div>
    {/if}
  {/if}
</main>

<!-- One account: what the machine has, what its own records say, and the two
     things that may be done to it. The actions live here rather than on the row
     so the list stays one line per account and a write is always taken with the
     account on screen. The form replaces this dialog rather than stacking on it;
     `opened` stays set, so closing the form returns here with the account as the
     write just left it. -->
{#if opened && editing === undefined}
  <Modal open title={opened.name} onclose={() => (opened = undefined)}>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center gap-2">
        {#if opened.is_root}
          <Badge tone="danger">{$LL.userSuperuser()}</Badge>
        {/if}
        {#if opened.agent_account}
          <Badge tone="neutral">{$LL.userCurrent()}</Badge>
        {/if}
        {#if opened.system}
          <Badge tone="neutral">{$LL.userSystemAccount()}</Badge>
        {/if}
        {#if opened.login_disabled}
          <Badge tone="warning">{$LL.userLoginDisabled()}</Badge>
        {/if}
      </div>

      <dl class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs @2xl:grid-cols-3">
        <div>
          <dt class="text-faint-fg">{$LL.userUid()}</dt>
          <dd class="text-muted-fg">{opened.uid} · {opened.gid}</dd>
        </div>
        <div class="col-span-1 @2xl:col-span-2">
          <dt class="text-faint-fg">{$LL.userHome()}</dt>
          <dd class="text-muted-fg break-all">
            {opened.home}{#if opened.shell} · {opened.shell}{/if}
          </dd>
        </div>
        <div>
          <dt class="text-faint-fg">{$LL.userPrimaryGroup()}</dt>
          <dd class="text-muted-fg">{opened.primary_group ?? '—'}</dd>
        </div>
        <div class="col-span-1 @2xl:col-span-2">
          <dt class="text-faint-fg">{$LL.userSupplementaryGroups()}</dt>
          <dd class="text-muted-fg break-all">
            <!-- `userPasswordNone` is this panel's word for "none", the same one
                 an empty key list is drawn with. -->
            {opened.supplementary_groups.join(', ') || $LL.userPasswordNone()}
          </dd>
        </div>
      </dl>

      {#if actionError}
        <pre class="text-sm text-danger whitespace-pre-wrap break-all">{actionError}</pre>
      {/if}

      {#if removing}
        <Card class="space-y-2">
          <p class="text-sm text-fg">{$LL.userDeleteConfirm({ name: opened.name })}</p>
          <label class="flex items-center gap-2 text-sm text-fg">
            <input type="checkbox" bind:checked={removeHome} />
            {$LL.userRemoveHome()}
          </label>
          {#if needsSudo}
            <!-- The second attempt. The password travels as its own field, so it
                 never lands in the machine's process list nor in the audit row. -->
            <div class="space-y-1">
              <label class="text-sm text-muted-fg" for="user-delete-sudo"
                >{$LL.powerPassword()}</label
              >
              <Input id="user-delete-sudo" type="password" bind:value={sudoPassword} />
              <p class="text-xs text-muted-fg">{$LL.powerPasswordHint()}</p>
            </div>
          {/if}
          <div class="flex justify-end gap-2">
            <Button variant="secondary" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
            <Button disabled={busy} onclick={() => void remove(needsSudo)}>
              {$LL.userDelete()}
            </Button>
          </div>
        </Card>
      {:else}
        <div class="flex flex-wrap items-center gap-2">
          <Button variant="secondary" onclick={() => openForm(opened!)}>
            <Pencil class="w-4 h-4" />
            {$LL.userEdit()}
          </Button>
          <!-- Whether it may be removed is the agent's answer on the row: root
               and its own account are the machine's, and which of the two this
               is is not something the panel can tell apart. -->
          <Button variant="secondary" disabled={!opened.deletable} onclick={() => (removing = true)}>
            <Trash2 class="w-4 h-4" />
            {$LL.userDelete()}
          </Button>
          <!-- Why that button is not available, said where it is: root and the
               account the agent runs as are the machine's own, and the agent
               says which of the two this is rather than the panel guessing. -->
          {#if !opened.deletable}
            <span class="text-xs text-faint-fg">
              {opened.is_root ? $LL.userRootNotDeletable() : $LL.userAgentAccount()}
            </span>
          {/if}
        </div>
      {/if}

      <!-- What only the machine's own records say. Fetched when an account is
           opened rather than with the listing: it is three files read as root,
           and most rows are never opened. -->
      <UserSecurity userName={opened.name} />
    </div>
  </Modal>
{/if}

{#if editing !== undefined}
  <Modal
    open
    title={editing ? $LL.userEdit() : $LL.userAdd()}
    onclose={() => (editing = undefined)}
  >
    <UserForm
      user={editing ?? undefined}
      fields={formState}
      onsaved={onSaved}
      oncancel={() => (editing = undefined)}
    />
  </Modal>
{/if}
