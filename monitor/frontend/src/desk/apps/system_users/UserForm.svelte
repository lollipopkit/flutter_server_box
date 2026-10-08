<script module lang="ts">
  import type { SystemUser, UserDraft } from '../../../types'

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
  import { Button, Card, Checkbox, Input } from '../../lk'
  import { api } from '../../../lib/api'
  import { LL } from '../../../i18n/i18n-svelte'
  import { userRefusalText } from '../../../lib/userRefusal'
  import type { UserRow } from '../../../types'

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
      const result = await api.actSystemUser({
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

  <div class="grid gap-[13px]">
    {#if editing}
      <!-- A rename is refused by the agent, so the field is not offered. -->
      <div><span class="lk-field__label">{$LL.username()}</span><p class="lk-mono mt-[5px] text-[13px]">{fields.name}</p></div>
    {:else}
      <Input id="user-name" bind:value={fields.name} label={$LL.username()} placeholder="deploy" />
    {/if}
    <Input id="user-comment" bind:value={fields.comment} label={$LL.userComment()} />
    <div class="grid gap-[13px] @2xl:grid-cols-2">
      <Input id="user-home" bind:value={fields.home} label={$LL.userHome()} placeholder="/home/deploy" />
      <Input id="user-shell" bind:value={fields.shell} label={$LL.userLoginShell()} placeholder="/bin/bash" />
      <Input id="user-primary" bind:value={fields.primaryGroup} label={$LL.userPrimaryGroup()} />
      <Input id="user-groups" bind:value={fields.groups} label={$LL.userSupplementaryGroups()} hint={$LL.userGroupsHint()} />
    </div>
    {#if editing}
      <Checkbox bind:checked={fields.moveHome} label={$LL.userMoveHome()} />
    {:else}
      <div class="grid gap-[9px]">
        <Checkbox bind:checked={fields.createHome} label={$LL.userCreateHome()} />
        <Checkbox bind:checked={fields.system} label={$LL.userSystemAccount()} />
      </div>
    {/if}
    <Input id="user-password" type="password" bind:value={fields.password} label={$LL.password()} hint={editing ? $LL.userPasswordEditTip() : $LL.userPasswordCreateTip()} />
  </div>

  {#if needsSudo}
    <!-- The second attempt. The password travels as its own field, so it never
         lands in the machine's process list nor in the agent's audit row. -->
    <Card class="mt-[13px]">
      <Input id="user-sudo" type="password" bind:value={sudoPassword} label={$LL.powerPassword()} hint={$LL.powerPasswordHint()} />
    </Card>
  {/if}

  <div class="mt-[17px] flex justify-end gap-[7px]">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    {#if needsSudo}
      <Button variant="primary" disabled={busy} onclick={() => void submit(true)}>{$LL.serviceRetryAsRoot()}</Button>
    {:else}
      <Button variant="primary" disabled={busy} onclick={() => void submit()}>{$LL.save()}</Button>
    {/if}
  </div>
</div>
