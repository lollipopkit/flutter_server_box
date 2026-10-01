<script lang="ts">
  /// One role's grants and their options.
  ///
  /// Holds a `RoleDraft`, where a grant's options stay put while the grant is
  /// switched off — switching it back on keeps what was typed — and turns it
  /// into the stored shape only on save, where an off grant is `null` whatever
  /// its fields say (`roleFromDraft`).

  import { Button, Input, Modal, Select } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import { emptyDraft, roleFromDraft, type RoleDraft } from '../lib/access'
  import type { Role } from '../types'

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
  <span class="flex-1 min-w-0">
    <span class="block text-sm text-fg">{label}</span>
    <span class="block text-xs text-faint-fg">{note}</span>
  </span>
{/snippet}

<Modal {open} title={existing ? $LL.editRole() : $LL.addRole()} {onclose} class="max-w-lg">
  <form class="space-y-4 max-h-[70vh] overflow-y-auto" onsubmit={save}>
    <div class="space-y-1">
      <span class="text-sm text-muted-fg">{$LL.roleName()}</span>
      <Input bind:value={d.name} disabled={existing} placeholder="desktop" />
    </div>

    {#if d.admin}
      <p class="text-xs text-faint-fg">{$LL.roleAdminNote()}</p>
    {/if}

    <label class="flex items-start gap-3">
      <input type="checkbox" class="w-4 h-4 mt-0.5" bind:checked={d.shell} />
      {@render grant($LL.grantShell(), $LL.grantShellNote())}
    </label>

    <label class="flex items-start gap-3">
      <input type="checkbox" class="w-4 h-4 mt-0.5" bind:checked={d.ssh_terminal} />
      {@render grant($LL.grantSshTerminal(), $LL.grantSshTerminalNote())}
    </label>

    {#if d.virt !== undefined}
      <label class="flex items-start gap-3">
        <input type="checkbox" class="w-4 h-4 mt-0.5" bind:checked={d.virt} />
        {@render grant($LL.grantVirt(), $LL.grantVirtNote())}
      </label>
    {/if}

    <div class="space-y-1">
      <span class="text-sm text-fg">{$LL.grantFiles()}</span>
      <Select bind:value={d.files} class="w-full">
        <option value="none">{$LL.filesNone()}</option>
        <option value="read">{$LL.filesRead()}</option>
        <option value="write">{$LL.filesWrite()}</option>
      </Select>
    </div>

    <div class="space-y-2">
      <label class="flex items-start gap-3">
        <input type="checkbox" class="w-4 h-4 mt-0.5" bind:checked={d.connect} />
        {@render grant($LL.grantConnect(), $LL.grantConnectNote())}
      </label>
      {#if d.connect}
        <div class="space-y-1 pl-7">
          <span class="text-xs text-muted-fg">{$LL.connectAllow()}</span>
          <textarea
            class="w-full rounded-lg bg-soft/50 border border-line px-3 py-2 text-sm font-mono
                   focus:outline-none focus:ring-2 focus:ring-accent/40"
            rows="3"
            spellcheck="false"
            placeholder="127.0.0.1:3389"
            bind:value={d.connectAllow}
          ></textarea>
          <p class="text-xs text-faint-fg">{$LL.connectAllowHint()}</p>
        </div>
      {/if}
    </div>

    <div class="space-y-2">
      <label class="flex items-start gap-3">
        <input type="checkbox" class="w-4 h-4 mt-0.5" bind:checked={d.listen} />
        {@render grant($LL.grantListen(), $LL.grantListenNote())}
      </label>
      {#if d.listen}
        <div class="space-y-2 pl-7">
          <label class="flex items-center gap-2 text-sm">
            <input type="checkbox" class="w-4 h-4" bind:checked={d.listenPublic} />
            {$LL.listenPublic()}
          </label>
          <div class="space-y-1">
            <span class="text-xs text-muted-fg">{$LL.listenPorts()}</span>
            <Input bind:value={d.listenPorts} placeholder="1024-65535" />
            <p class="text-xs text-faint-fg">{$LL.listenPortsHint()}</p>
          </div>
        </div>
      {/if}
    </div>

    {#if error}
      <p class="text-sm text-danger">{error}</p>
    {/if}
    <div class="flex justify-end gap-2">
      <Button variant="ghost" type="button" onclick={onclose}>{$LL.cancel()}</Button>
      <Button type="submit">{$LL.save()}</Button>
    </div>
  </form>
</Modal>
