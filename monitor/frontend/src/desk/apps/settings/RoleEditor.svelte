<script lang="ts">
  /// One role's grants and their options.
  ///
  /// Holds a `RoleDraft`, where a grant's options stay put while the grant is
  /// switched off — switching it back on keeps what was typed — and turns it
  /// into the stored shape only on save, where an off grant is `null` whatever
  /// its fields say (`roleFromDraft`).

  import { Button, Checkbox, Dialog, Input, Select, Textarea } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { emptyDraft, roleFromDraft, type RoleDraft } from '../../../lib/access'
  import type { Role } from '../../../types'

  interface Props {
    open: boolean
    /// The role being edited, or a new one.
    draft: RoleDraft
    /// Whether it exists yet: a built-in role's name, and any existing role's
    /// name, cannot change.
    existing: boolean
    onsave: (role: Role) => void
    onclose: () => void
  }

  const { open, draft, existing, onsave, onclose }: Props = $props()

  // Filled from [draft] each time the editor opens, below.
  let d = $state<RoleDraft>(emptyDraft())
  let error = $state<string | null>(null)

  $effect(() => {
    if (open) {
      d = { ...draft }
      error = null
    }
  })

  function save(event: SubmitEvent) {
    event.preventDefault()
    const result = roleFromDraft(d)
    if ('error' in result) {
      error = result.error === 'name' ? $LL.roleNameInvalid() : $LL.portsInvalid()
      return
    }
    error = null
    onsave(result)
  }
</script>

{#snippet grant(label: string, note: string)}
  <span class="min-w-0 flex-1">
    <span class="block text-[13px] text-(--text-primary)">{label}</span>
    <span class="block text-[12px] text-(--text-tertiary)">{note}</span>
  </span>
{/snippet}

<Dialog open={open} wide title={existing ? $LL.editRole() : $LL.addRole()} onclose={onclose}>
  <form id="role-form" class="max-h-[min(65vh,560px)] space-y-[13px] overflow-y-auto" onsubmit={save}>
    <Input label={$LL.roleName()} bind:value={d.name} disabled={existing} placeholder="desktop" />
    {#if d.admin}<p class="text-[12px] text-(--text-tertiary)">{$LL.roleAdminNote()}</p>{/if}

    <Checkbox bind:checked={d.shell}>
      {@render grant($LL.grantShell(), $LL.grantShellNote())}
    </Checkbox>
    <Checkbox bind:checked={d.ssh_terminal}>
      {@render grant($LL.grantSshTerminal(), $LL.grantSshTerminalNote())}
    </Checkbox>

    {#if d.virt !== undefined}
      <Checkbox bind:checked={d.virt}>
        {@render grant($LL.grantVirt(), $LL.grantVirtNote())}
      </Checkbox>
    {/if}

    <Select
      label={$LL.grantFiles()}
      bind:value={d.files}
      options={[
        { value: 'none', label: $LL.filesNone() },
        { value: 'read', label: $LL.filesRead() },
        { value: 'write', label: $LL.filesWrite() },
      ]}
    />

    <Checkbox bind:checked={d.connect}>
      {@render grant($LL.grantConnect(), $LL.grantConnectNote())}
    </Checkbox>
    {#if d.connect}
      <Textarea label={$LL.connectAllow()} rows={3} spellcheck="false" placeholder="127.0.0.1:3389" bind:value={d.connectAllow} mono hint={$LL.connectAllowHint()} />
    {/if}

    <Checkbox bind:checked={d.listen}>
      {@render grant($LL.grantListen(), $LL.grantListenNote())}
    </Checkbox>
    {#if d.listen}
      <div class="space-y-[9px] pl-[21px]">
        <Checkbox bind:checked={d.listenPublic} label={$LL.listenPublic()} />
        <Input label={$LL.listenPorts()} bind:value={d.listenPorts} placeholder="1024-65535" hint={$LL.listenPortsHint()} />
      </div>
    {/if}
    {#if error}<p class="text-[13px] text-(--color-danger)" role="alert">{error}</p>{/if}
  </form>
  {#snippet actions()}
    <Button variant="secondary" type="button" onclick={onclose}>{$LL.cancel()}</Button>
    <Button type="submit" form="role-form">{$LL.save()}</Button>
  {/snippet}
</Dialog>
