<script lang="ts">
  import { Button, Card, Input, Select, Spinner } from '@serverbox/webui'
  import { Copy, LayoutTemplate, Trash2, X } from '@lucide/svelte'
  import { api } from '../lib/api'
  import { virtErrorText, virtRequestText } from '../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { VirtCloneRequest, VirtGuest, VirtHostView, VirtPool } from '../types'

  /// A guest's settings pane: a copy of it, a template of it (PVE), its
  /// deletion. Whether the host takes each is the agent's answer, said after
  /// it is sent; this only keeps the buttons of what cannot be sent at all
  /// from being pressed.
  interface Props {
    view: VirtHostView
    guest: VirtGuest
    sudoPassword: string | null
    /// The copy's id and name, once the host has made it.
    oncloned: (id: string, name: string) => void
    ontemplated: (name: string) => void
    ondeleted: (name: string) => void
  }

  const { view, guest, sudoPassword, oncloned, ontemplated, ondeleted }: Props = $props()

  const caps = $derived(view.capabilities)
  const pve = $derived(view.host.kind === 'pve')
  const stopped = $derived(guest.state === 'stopped')
  const nodes = $derived(view.host.nodes.filter((n) => n.online))
  /// PVE links a copy only of a template; libvirt either copies the
  /// contents or makes empty disks.
  const fullChoice = $derived(pve ? guest.template && caps.linked_clone === true : true)

  let storages = $state<VirtPool[] | null>(null)
  let error = $state('')
  let busy = $state(false)
  let cloneName = $state('')
  let full = $state(true)
  let vmid = $state('')
  let storage = $state('')
  let node = $state('')
  let removeDisks = $state(true)
  let confirmDelete = $state(false)
  let confirmTemplate = $state(false)

  /// The page hands a new guest object on every read of the host; only
  /// another guest starts the pane over.
  const guestId = $derived(guest.id)

  $effect(() => {
    void guestId
    untrack(() => {
      const g = guest
      cloneName = `${g.name}-clone`
      full = true
      vmid = ''
      storage = ''
      node = ''
      removeDisks = true
      confirmDelete = false
      confirmTemplate = false
      error = ''
      storages = null
      if (caps.clone) void loadStorages(g.id)
    })
  })

  async function loadStorages(id: string) {
    try {
      const answer = await api.cloneForm(id, sudoPassword ?? undefined)
      if (guest.id !== id) return
      if (answer.error) error = virtErrorText(answer.error)
      storages = answer.storages ?? []
    } catch (e) {
      if (guest.id === id) error = virtRequestText(e)
    }
  }

  async function clone(e: SubmitEvent) {
    e.preventDefault()
    const g = guest
    const copyFull = fullChoice ? full : true
    const request: VirtCloneRequest = { name: cloneName.trim(), full: copyFull }
    if (pve) {
      if (String(vmid).trim() !== '') request.vmid = Math.floor(Number(vmid))
      if (copyFull && storage) request.storage = storage
      if (copyFull && node) request.target_node = node
    } else if (storage) request.target_pool = storage
    busy = true
    error = ''
    try {
      const { id, error: err } = await api.cloneGuest(g.id, request, sudoPassword ?? undefined)
      if (err) error = virtErrorText(err)
      else if (id) oncloned(id, request.name)
    } catch (err) {
      error = virtRequestText(err)
    } finally {
      busy = false
    }
  }

  async function template() {
    if (!confirmTemplate) {
      confirmTemplate = true
      return
    }
    const g = guest
    confirmTemplate = false
    busy = true
    error = ''
    try {
      const { error: err } = await api.makeTemplate(g.id)
      if (err) error = virtErrorText(err)
      else ontemplated(g.name)
    } catch (err) {
      error = virtRequestText(err)
    } finally {
      busy = false
    }
  }

  async function remove() {
    if (!confirmDelete) {
      confirmDelete = true
      return
    }
    // What is asked, before the confirmation that asked it goes.
    const g = guest
    const disks = removeDisks
    confirmDelete = false
    busy = true
    error = ''
    try {
      const { error: err } = await api.deleteGuest(g.id, disks, sudoPassword ?? undefined)
      if (err) error = virtErrorText(err)
      else ondeleted(g.name)
    } catch (err) {
      error = virtRequestText(err)
    } finally {
      busy = false
    }
  }
</script>

{#if error}
  <Card class="border-danger/40 bg-danger/5">
    <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
  </Card>
{/if}

{#if caps.clone}
  <!-- Clone. -->
  <Card class="space-y-3">
    <div class="flex items-center gap-2">
      <h3 class="text-sm font-medium text-fg-strong">{$LL.virtClone()}</h3>
      <span class="ml-auto text-xs text-faint-fg">{fullChoice && !full ? (pve ? $LL.virtCloneLinked() : $LL.virtCloneEmpty()) : $LL.virtCloneFullShort()}</span>
    </div>
    <form class="space-y-3" onsubmit={clone}>
      <div class="flex flex-wrap gap-3">
        <label class="block min-w-0 flex-1 space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtCloneName()}</span>
          <Input class="font-mono" bind:value={cloneName} />
        </label>
        {#if pve}
          <label class="block w-36 space-y-1 text-sm">
            <span class="text-muted-fg">VMID</span>
            <Input type="number" min="100" bind:value={vmid} placeholder={$LL.virtVmidNext()} />
          </label>
        {/if}
      </div>
      {#if fullChoice}
        <label class="flex items-start gap-2 text-sm">
          <input class="mt-1" type="checkbox" bind:checked={full} />
          <span>
            <span class="text-fg">{pve ? $LL.virtCloneFull() : $LL.virtCloneCopy()}</span>
            <span class="block text-xs text-faint-fg">{pve ? $LL.virtCloneFullNote() : $LL.virtCloneCopyNote()}</span>
          </span>
        </label>
      {/if}
      {#if storages === null}
        <Spinner size="sm" />
      {:else if storages.length > 0 && (!pve || full || !fullChoice)}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtCloneStorage()}</span>
          <Select class="w-full" bind:value={storage}>
            <option value="">{$LL.virtSameAsSource()}</option>
            {#each storages as p (p.id)}
              <option value={p.name}>{p.name} · {p.type}</option>
            {/each}
          </Select>
        </label>
      {/if}
      {#if pve && caps.clone_target && nodes.length > 1 && (full || !fullChoice)}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtCloneNode()}</span>
          <Select class="w-full" bind:value={node}>
            <option value="">{$LL.virtSameAsSource()}</option>
            {#each nodes.filter((n) => n.name !== guest.node) as n (n.name)}
              <option value={n.name}>{n.name}</option>
            {/each}
          </Select>
        </label>
      {/if}
      {#if !pve && !stopped}
        <p class="text-xs text-muted-fg">{$LL.virtStopFirst()}</p>
      {/if}
      <div class="flex justify-end">
        <Button type="submit" size="sm" disabled={busy || cloneName.trim() === '' || (!pve && !stopped)}>
          <Copy class="h-4 w-4" />
          {$LL.virtClone()}
        </Button>
      </div>
    </form>
  </Card>
{/if}

{#if pve && caps.template && !guest.template}
  <!-- Template. -->
  <Card class="space-y-3">
    <h3 class="text-sm font-medium text-fg-strong">{$LL.virtTemplate()}</h3>
    <p class="text-xs text-muted-fg">{$LL.virtMakeTemplateNote()}</p>
    {#if !stopped}
      <p class="text-xs text-muted-fg">{$LL.virtStopFirst()}</p>
    {/if}
    {#if confirmTemplate}
      <p class="text-xs text-warning">{$LL.virtConfirmAgain()}</p>
    {/if}
    <div class="flex justify-end gap-2">
      {#if confirmTemplate}
        <Button variant="secondary" size="sm" onclick={() => (confirmTemplate = false)}>
          <X class="h-4 w-4" />
          {$LL.cancel()}
        </Button>
      {/if}
      <Button variant="secondary" size="sm" disabled={busy || !stopped} onclick={() => void template()}>
        <LayoutTemplate class="h-4 w-4" />
        {confirmTemplate ? $LL.virtConfirmTemplate({ name: guest.name }) : $LL.virtMakeTemplate()}
      </Button>
    </div>
  </Card>
{/if}

<!-- Delete. -->
<Card class="space-y-3 border-danger/30">
  <div class="flex items-center gap-2">
    <span class="h-2 w-2 shrink-0 rounded-full bg-danger"></span>
    <h3 class="text-sm font-medium text-fg-strong">{$LL.virtDelete()}</h3>
  </div>
  {#if caps.delete_keeps_disks}
    <label class="flex items-start gap-2 text-sm">
      <input class="mt-1" type="checkbox" bind:checked={removeDisks} />
      <span>
        <span class="text-fg">{$LL.virtDeleteDisks()}</span>
        <span class="block text-xs text-faint-fg">{$LL.virtDeleteDisksNote()}</span>
      </span>
    </label>
  {:else}
    <p class="text-xs text-muted-fg">{$LL.virtDeleteDisksAlways()}</p>
  {/if}
  {#if !stopped}
    <p class="text-xs text-muted-fg">{$LL.virtStopFirst()}</p>
  {/if}
  {#if confirmDelete}
    <p class="text-xs text-danger">{$LL.virtConfirmAgain()}</p>
  {/if}
  <div class="flex justify-end gap-2">
    {#if confirmDelete}
      <Button variant="secondary" size="sm" onclick={() => (confirmDelete = false)}>
        <X class="h-4 w-4" />
        {$LL.cancel()}
      </Button>
    {/if}
    <Button variant="danger" size="sm" disabled={busy || !stopped} onclick={() => void remove()}>
      <Trash2 class="h-4 w-4" />
      {confirmDelete ? $LL.virtConfirmDelete({ name: guest.name }) : $LL.virtDeleteGuest()}
    </Button>
  </div>
</Card>
