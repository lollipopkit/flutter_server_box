<script module lang="ts">
  import type { GroupDraft, SystemGroup } from '../types'

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

  export function groupDraftOf(fields: GroupFormState): GroupDraft {
    return {
      name: fields.name.trim(),
      members: fields.members.split(/[\s,]+/).filter(Boolean),
      system: fields.system,
    }
  }
</script>

<script lang="ts">
  import { Button, Card, Input } from '@serverbox/webui'
  import { api } from '../lib/api'
  import { LL } from '../i18n/i18n-svelte'
  import { userRefusalText } from '../lib/userRefusal'
  import type { GroupRow } from '../types'

  interface Props {
    group?: GroupRow
    fields: GroupFormState
    onsaved: (name: string, created: boolean) => void
    oncancel: () => void
  }

  const { group, fields, onsaved, oncancel }: Props = $props()

  const editing = $derived(group !== undefined)

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
        if (asRoot) error = $LL.powerRejected()
        else needsSudo = true
        return
      }
      if (!result.succeeded) {
        error = result.stderr.trim() || result.stdout.trim() || $LL.userCommandFailed()
        return
      }
      onsaved(fields.name.trim(), !editing)
    } catch (e) {
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
    <label class="text-sm text-muted-fg" for="group-name">{$LL.systemGroups()}</label>
    {#if editing}
      <p class="text-sm font-mono text-fg-strong">{fields.name}</p>
    {:else}
      <Input id="group-name" bind:value={fields.name} placeholder="deploy" />
    {/if}
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="group-members">{$LL.groupMembers()}</label>
    <Input id="group-members" bind:value={fields.members} />
    <p class="text-xs text-muted-fg">{$LL.groupMembersHint()}</p>
  </div>

  {#if !editing}
    <label class="flex items-center gap-2 text-sm text-fg">
      <input type="checkbox" bind:checked={fields.system} />
      {$LL.groupSystem()}
    </label>
  {/if}

  {#if needsSudo}
    <Card class="space-y-1">
      <label class="text-sm text-muted-fg" for="group-sudo">{$LL.powerPassword()}</label>
      <Input id="group-sudo" type="password" bind:value={sudoPassword} />
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
