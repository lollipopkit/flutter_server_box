<script module lang="ts">
  import type { SystemUser, UserDraft } from '../types'

  /// The form's own fields, in the shapes the form edits: a group list is a
  /// text field here and a list on the wire, and the three flags are asked per
  /// action — `create_home` and `system` mean nothing to a change.
  ///
  /// The page owns this object and seeds it when the dialog opens, the way the
  /// schedule page seeds its editor: a form that seeded itself from an account
  /// prop would be holding a copy of a row that a refresh may have replaced.
  export interface UserFormState {
    name: string
    comment: string
    home: string
    shell: string
    primaryGroup: string
    groups: string
    createHome: boolean
    moveHome: boolean
    system: boolean
    /// The account's password, when this write is setting one.
    password: string
  }

  /// What a form opens with, for a new account or for one being changed.
  export function userFormState(user?: SystemUser): UserFormState {
    return {
      name: user?.name ?? '',
      comment: user?.comment ?? '',
      home: user?.home ?? '',
      shell: user?.shell ?? '',
      primaryGroup: user?.primary_group ?? '',
      groups: (user?.supplementary_groups ?? []).join(' '),
      // A new account gets a home unless the operator says otherwise; an
      // existing one is only moved when that is asked for, because `usermod -m`
      // moves files.
      createHome: user === undefined,
      moveHome: false,
      system: false,
      password: '',
    }
  }

  /// The whole account, not only what changed: `comment` and the group list
  /// *replace* on an empty value, so an empty field sent here clears what was
  /// there while an omitted one would not. `home`, `shell` and the primary group
  /// are the other way round — empty means "leave it" — which is the agent's
  /// rule, not this form's.
  export function userDraftOf(fields: UserFormState): UserDraft {
    return {
      name: fields.name.trim(),
      comment: fields.comment,
      home: fields.home.trim(),
      shell: fields.shell.trim(),
      primary_group: fields.primaryGroup.trim(),
      supplementary_groups: fields.groups.split(/[\s,]+/).filter(Boolean),
      create_home: fields.createHome,
      move_home: fields.moveHome,
      system: fields.system,
      // Omitted rather than empty: an empty string is a password that is empty,
      // and what is wanted is leaving the stored one alone.
      ...(fields.password ? { password: fields.password } : {}),
    }
  }
</script>

<script lang="ts">
  import { Button, Card, Input } from '@serverbox/webui'
  import { api } from '../lib/api'
  import { LL } from '../i18n/i18n-svelte'
  import { userRefusalText } from '../lib/userRefusal'
  import type { UserRow } from '../types'

  interface Props {
    /// The account being changed, or `undefined` for a new one.
    user?: UserRow
    /// The fields, seeded by the page and edited here in place.
    fields: UserFormState
    /// Called with the account's name once the machine accepted the write. The
    /// page owns the refresh and the notice; this owns the request.
    onsaved: (name: string, created: boolean) => void
    oncancel: () => void
  }

  const { user, fields, onsaved, oncancel }: Props = $props()

  /// Derived rather than read once: the dialog is remounted per open, but a
  /// plain `const` still reads as a snapshot to the compiler.
  const editing = $derived(user !== undefined)

  /// The `sudo` password belongs to the second attempt, and only exists once the
  /// first came back refused.
  let needsSudo = $state(false)
  let sudoPassword = $state('')
  let busy = $state(false)
  let error = $state('')

  async function submit(asRoot = false) {
    busy = true
    error = ''
    try {
      const result = await api.actUser({
        action: editing ? 'edit' : 'create',
        draft: userDraftOf(fields),
        ...(asRoot && sudoPassword ? { password: sudoPassword } : {}),
      })
      if (result.sudo_rejected) {
        // The command needs an account the agent does not have. There is one way
        // forward and it is that account, so the form asks for what that needs
        // rather than reporting a refusal — unless this *was* the second
        // attempt, which has nowhere left to go.
        if (asRoot) error = $LL.powerRejected()
        else needsSudo = true
        return
      }
      if (!result.succeeded) {
        // What the command said, where it said anything.
        error = result.stderr.trim() || result.stdout.trim() || $LL.userCommandFailed()
        return
      }
      onsaved(fields.name.trim(), !editing)
    } catch (e) {
      // A refusal made before anything ran, as its own code.
      error = userRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      busy = false
    }
  }
</script>

<div class="space-y-4">
  {#if error}
    <pre class="text-sm text-danger whitespace-pre-wrap break-all">{error}</pre>
  {/if}

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="user-name">{$LL.username()}</label>
    {#if editing}
      <!-- A rename is refused by the agent, so the field is not offered: the
           name is what every file and process on the machine knows the account
           by, and changing it would leave those behind. -->
      <p class="text-sm font-mono text-fg-strong">{fields.name}</p>
    {:else}
      <Input id="user-name" bind:value={fields.name} placeholder="deploy" />
    {/if}
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="user-comment">{$LL.userComment()}</label>
    <Input id="user-comment" bind:value={fields.comment} />
  </div>

  <div class="grid gap-4 sm:grid-cols-2">
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="user-home">{$LL.userHome()}</label>
      <Input id="user-home" bind:value={fields.home} placeholder="/home/deploy" />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="user-shell">{$LL.userLoginShell()}</label>
      <Input id="user-shell" bind:value={fields.shell} placeholder="/bin/bash" />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="user-primary">{$LL.userPrimaryGroup()}</label>
      <Input id="user-primary" bind:value={fields.primaryGroup} />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="user-groups">{$LL.userSupplementaryGroups()}</label>
      <Input id="user-groups" bind:value={fields.groups} />
    </div>
  </div>
  <p class="text-xs text-muted-fg">{$LL.userGroupsHint()}</p>

  <div class="space-y-2">
    {#if editing}
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={fields.moveHome} />
        {$LL.userMoveHome()}
      </label>
    {:else}
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={fields.createHome} />
        {$LL.userCreateHome()}
      </label>
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={fields.system} />
        {$LL.userSystemAccount()}
      </label>
    {/if}
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="user-password">{$LL.password()}</label>
    <Input id="user-password" type="password" bind:value={fields.password} />
    <p class="text-xs text-muted-fg">
      {editing ? $LL.userPasswordEditTip() : $LL.userPasswordCreateTip()}
    </p>
  </div>

  {#if needsSudo}
    <!-- The second attempt. The password travels as its own field, so it never
         lands in the machine's process list nor in the agent's audit row. -->
    <Card class="space-y-1">
      <label class="text-sm text-muted-fg" for="user-sudo">{$LL.powerPassword()}</label>
      <Input id="user-sudo" type="password" bind:value={sudoPassword} />
      <p class="text-xs text-muted-fg">{$LL.powerPasswordHint()}</p>
    </Card>
  {/if}

  <div class="flex justify-end gap-2">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    {#if needsSudo}
      <Button disabled={busy} onclick={() => void submit(true)}>{$LL.serviceRetryAsRoot()}</Button>
    {:else}
      <Button disabled={busy} onclick={() => void submit()}>{$LL.save()}</Button>
    {/if}
  </div>
</div>
