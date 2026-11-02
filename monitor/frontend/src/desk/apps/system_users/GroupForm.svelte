<script module lang="ts">
  import type { GroupDraft, SystemGroup } from '../../../types'
  import { errorText } from '../../../lib/errorText'

  /// The form's own fields: the member list is a text field here and a list on
  /// the wire. Seeded by the page when the dialog opens, as `UserForm`'s are.
  export interface GroupFormState {
    name: string
    members: string
    system: boolean
  }

  export function groupFormState(group?: SystemGroup): GroupFormState {
    return {
      name: group?.name ?? '',
      members: (group?.members ?? []).join(' '),
      system: false,
    }
  }

  /// The whole member list: an empty one removes every supplementary member.
  export function groupDraftOf(fields: GroupFormState): GroupDraft {
    return {
      name: fields.name.trim(),
      members: fields.members.split(/[\s,]+/).filter(Boolean),
      system: fields.system,
    }
  }
</script>

<script lang="ts">
  import { Button, Card, Checkbox, Input } from '../../lk'
  import { api } from '../../../lib/api'
  import { LL } from '../../../i18n/i18n-svelte'
  import { userRefusalText } from '../../../lib/userRefusal'
  import type { GroupRow } from '../../../types'

  interface Props {
    /// The group being changed, or `undefined` for a new one.
    group?: GroupRow
    fields: GroupFormState
    onsaved: (name: string, created: boolean) => void
    oncancel: () => void
  }

  const { group, fields, onsaved, oncancel }: Props = $props()

  const editing = $derived(group !== undefined)

  /// The `sudo` password belongs to the second attempt, once the first came
  /// back refused.
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
        kind: 'group',
        group: groupDraftOf(fields),
        ...(editing ? { name: group!.name } : {}),
        ...(asRoot && sudoPassword ? { password: sudoPassword } : {}),
      })
      if (result.sudo_rejected) {
        if (asRoot) {
          error = $LL.powerRejected()
          sudoPassword = ''
        } else needsSudo = true
        return
      }
      if (!result.succeeded) {
        error = result.stderr.trim() || result.stdout.trim() || $LL.userCommandFailed()
        return
      }
      onsaved(fields.name.trim(), !editing)
    } catch (e) {
      error = userRefusalText(errorText(e))
    } finally {
      busy = false
    }
  }
</script>

<div class="space-y-4">
  {#if error}
    <pre class="text-sm text-(--color-danger) whitespace-pre-wrap break-all">{error}</pre>
  {/if}

  <div class="grid gap-[13px]">
    {#if editing}
      <!-- A rename is not offered: the agent changes members only. -->
      <div><span class="lk-field__label">{$LL.systemGroups()}</span><p class="lk-mono mt-[5px] text-[13px]">{fields.name}</p></div>
    {:else}
      <Input id="group-name" bind:value={fields.name} label={$LL.systemGroups()} placeholder="deploy" />
    {/if}
    <Input id="group-members" bind:value={fields.members} label={$LL.groupMembers()} hint={$LL.groupMembersHint()} />
    {#if !editing}
      <Checkbox bind:checked={fields.system} label={$LL.groupSystem()} />
    {/if}
  </div>

  {#if needsSudo}
    <!-- The password travels as its own field, never in the machine's process
         list nor in the agent's audit row. -->
    <Card class="mt-[13px]">
      <Input id="group-sudo" type="password" bind:value={sudoPassword} label={$LL.powerPassword()} hint={$LL.powerPasswordHint()} />
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
