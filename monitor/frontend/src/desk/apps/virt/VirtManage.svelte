<script lang="ts">
  import { Button, Card, Input, Select, Spinner } from '@serverbox/webui'
  import { Copy, LayoutTemplate, Trash2, X } from '@lucide/svelte'
  import { api } from '../../../lib/api'
  import { ciDraft, cloudInitEdit, outcomeText, virtErrorText, virtRequestText, type CiDraft } from '../../../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { VirtCloneRequest, VirtCloudInitState, VirtGuest, VirtHardware, VirtHostView, VirtHwChange, VirtPool } from '../../../types'

  /// A guest's settings pane: its name, description, autostart and
  /// protection (PVE), its cloud-init, a copy of it, a template of it (PVE),
  /// its deletion. Whether the host takes each is the agent's answer, said
  /// after it is sent; this only keeps the buttons of what cannot be sent at
  /// all from being pressed.
  interface Props {
    view: VirtHostView
    guest: VirtGuest
    sudoPassword: string | null
    /// The copy's id and name, once the host has made it.
    oncloned: (id: string, name: string) => void
    ontemplated: (name: string) => void
    ondeleted: (name: string) => void
    /// Told after a setting changed, so the page reads the host again.
    onchanged?: () => void
  }

  const { view, guest, sudoPassword, oncloned, ontemplated, ondeleted, onchanged }: Props = $props()

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
  /// The read the general settings are changed from.
  let hw = $state<VirtHardware | null>(null)
  let hwError = $state('')
  let name = $state('')
  let description = $state('')
  let notice = $state('')
  /// null while it is read; `none` where the guest has no cloud-init.
  let ci = $state<VirtCloudInitState | 'none' | null>(null)
  let ciError = $state('')
  let ciForm = $state<CiDraft | null>(null)

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
      notice = ''
      storages = null
      hw = null
      hwError = ''
      ci = null
      ciError = ''
      ciForm = null
      if (caps.clone) void loadStorages(g.id)
      void readHardware(g.id, true)
    })
  })

  async function readHardware(id: string, withCloudInit = false) {
    try {
      const answer = await api.virtHardware(id, sudoPassword ?? undefined)
      if (guest.id !== id) return
      if (answer.error) {
        hwError = virtErrorText(answer.error)
        return
      }
      hwError = ''
      hw = answer.hardware
      name = answer.hardware?.name ?? ''
      description = answer.hardware?.description ?? ''
      if (withCloudInit && answer.hardware) void readCloudInit(id, answer.hardware)
    } catch (e) {
      if (guest.id === id) hwError = virtRequestText(e)
    }
  }

  /// PVE: a VM with a cloud-init drive. libvirt: a VM whose seed this app
  /// made, which the read answers or refuses.
  async function readCloudInit(id: string, h: VirtHardware) {
    if (h.kind !== 'qemu' || (pve && !h.disks.some((d) => d.cloud_init))) {
      ci = 'none'
      return
    }
    try {
      const answer = await api.virtCloudInit(id, sudoPassword ?? undefined)
      if (guest.id !== id) return
      if (answer.error) {
        if (!pve && answer.error.kind === 'unsupported') ci = 'none'
        else {
          ci = 'none'
          ciError = virtErrorText(answer.error)
        }
        return
      }
      ciError = ''
      ci = answer.cloud_init ?? 'none'
      ciForm = answer.cloud_init ? ciDraft(answer.cloud_init) : null
    } catch (e) {
      if (guest.id === id) {
        ci = 'none'
        ciError = virtRequestText(e)
      }
    }
  }

  /// One general setting, made from the read shown, then read again.
  async function change(c: VirtHwChange) {
    const id = guest.id
    const h = hw
    if (!h) return
    busy = true
    error = ''
    notice = ''
    try {
      const { outcome, error: err } = await api.virtHardwareChange(id, h.revision, c, sudoPassword ?? undefined)
      if (guest.id !== id) return
      if (err) {
        if (err.kind === 'conflict') notice = $LL.virtHwConflict()
        else error = virtErrorText(err)
      } else {
        notice = outcomeText(outcome)
        onchanged?.()
      }
      await readHardware(id)
    } catch (e) {
      error = virtRequestText(e)
    } finally {
      busy = false
    }
  }

  /// What a toggle asks for; the box shows what the host has until the read
  /// after the change says otherwise.
  function flip(e: Event): boolean {
    const box = e.currentTarget as HTMLInputElement
    const on = box.checked
    box.checked = !on
    return on
  }

  async function saveCloudInit(e: SubmitEvent) {
    e.preventDefault()
    const id = guest.id
    const state = ci
    const draft = ciForm
    if (!state || state === 'none' || !draft || !hw) return
    const edit = cloudInitEdit(draft, state, view.host.kind)
    busy = true
    error = ''
    notice = ''
    try {
      const { error: err } = await api.virtSetCloudInit(id, edit, sudoPassword ?? undefined)
      if (guest.id !== id) return
      if (err) {
        if (err.kind === 'conflict') {
          notice = $LL.virtHwConflict()
          await readCloudInit(id, hw)
        } else error = virtErrorText(err)
        return
      }
      notice = $LL.virtCiSaved()
      await readCloudInit(id, hw)
    } catch (err) {
      error = virtRequestText(err)
    } finally {
      busy = false
    }
  }

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
{#if notice}
  <Card>
    <p class="text-sm text-muted-fg whitespace-pre-wrap">{notice}</p>
  </Card>
{/if}

<!-- General: name, description, autostart, protection. -->
<Card class="space-y-3">
  <div class="flex items-center gap-2">
    <h3 class="text-sm font-medium text-fg-strong">{$LL.virtGroupGeneral()}</h3>
    {#if hw}
      <span class="ml-auto text-xs text-faint-fg">{hw.autostart ? $LL.virtHwAutostartOn() : $LL.virtHwAutostartOff()}</span>
    {/if}
  </div>
  {#if hwError}
    <p class="text-sm text-danger whitespace-pre-wrap break-all">{hwError}</p>
  {:else if !hw}
    <Spinner size="sm" />
  {:else}
    {@const h = hw}
    <div class="flex flex-wrap items-end gap-2">
      <label class="block min-w-0 flex-1 space-y-1 text-sm">
        <span class="text-muted-fg">{guest.kind === 'lxc' && pve ? $LL.virtHostname() : $LL.virtName()}</span>
        <Input class="font-mono" bind:value={name} />
      </label>
      <Button size="sm" disabled={busy || name.trim() === '' || name.trim() === (h.name ?? '')} onclick={() => void change({ op: 'set_name', name: name.trim() })}>
        {$LL.save()}
      </Button>
    </div>
    {#if h.running && !h.rename_running}
      <p class="text-xs text-muted-fg">{$LL.virtHwRenameStopped()}</p>
    {/if}
    <label class="block space-y-1 text-sm">
      <span class="text-muted-fg">{$LL.virtHwDescription()}</span>
      <textarea class="w-full rounded-lg border border-line bg-surface px-3 py-2 text-sm text-fg" rows="3" bind:value={description}></textarea>
    </label>
    <div class="flex justify-end">
      <Button size="sm" disabled={busy || description === (h.description ?? '')} onclick={() => void change({ op: 'set_description', text: description })}>
        {$LL.save()}
      </Button>
    </div>
    <label class="flex items-start gap-2 text-sm">
      <input class="mt-1" type="checkbox" checked={h.autostart} disabled={busy} onchange={(e) => void change({ op: 'set_autostart', on: flip(e) })} />
      <span>
        <span class="text-fg">{$LL.virtAutostart()}</span>
        <span class="block font-mono text-xs text-faint-fg">{pve ? 'onboot' : 'virsh autostart'}</span>
      </span>
    </label>
    {#if h.protection !== null}
      <label class="flex items-start gap-2 text-sm">
        <input class="mt-1" type="checkbox" checked={h.protection} disabled={busy} onchange={(e) => void change({ op: 'set_protection', on: flip(e) })} />
        <span>
          <span class="text-fg">{$LL.virtHwProtection()}</span>
          <span class="block text-xs text-faint-fg">{$LL.virtHwProtectionNote()}</span>
        </span>
      </label>
    {/if}
  {/if}
</Card>

{#if guest.kind === 'qemu'}
  <!-- cloud-init: the account and address the system boots with. -->
  <Card class="space-y-3">
    <h3 class="text-sm font-medium text-fg-strong">{$LL.virtCloudInit()}</h3>
    {#if ciError}
      <p class="text-sm text-danger whitespace-pre-wrap break-all">{ciError}</p>
    {:else if ci === null}
      {#if !hwError}
        <Spinner size="sm" />
      {/if}
    {:else if ci === 'none'}
      <p class="text-sm text-muted-fg">{pve ? $LL.virtCiNoDrive() : $LL.virtCiNoSeed()}</p>
    {:else if ciForm}
      {@const state = ci}
      {@const f = ciForm}
      {#if state.foreign}
        <p class="text-xs text-warning">{$LL.virtCiForeign()}</p>
      {/if}
      {#if state.nics > 1}
        <p class="text-xs text-muted-fg">{$LL.virtCiNics({ n: state.nics })}</p>
      {/if}
      <form class="space-y-3" onsubmit={saveCloudInit}>
        <div class="flex flex-wrap gap-3">
          <label class="block min-w-40 flex-1 space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtCiUser()}</span>
            <Input class="font-mono" autocomplete="off" bind:value={f.user} />
          </label>
          <label class="block min-w-40 flex-1 space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtCiNewPassword()}</span>
            <Input type="password" autocomplete="new-password" bind:value={f.password} disabled={f.removePassword} placeholder={state.password_set ? $LL.virtCiKeepPassword() : ''} />
          </label>
        </div>
        {#if state.password_set}
          <label class="flex items-center gap-1.5 text-sm text-fg"><input type="checkbox" bind:checked={f.removePassword} /> {$LL.virtCiRemovePassword()}</label>
        {/if}
        {#if !pve}
          <label class="flex items-center gap-1.5 text-sm text-fg"><input type="checkbox" bind:checked={f.passwordExpires} /> {$LL.virtCiPasswordExpires()}</label>
        {/if}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtSshKeys()}</span>
          <textarea class="w-full rounded-lg border border-line bg-surface px-3 py-2 font-mono text-xs text-fg" rows="3" bind:value={f.sshKeys} placeholder="ssh-ed25519 AAAA…"></textarea>
        </label>
        {#if !pve}
          <label class="block space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtHostname()}</span>
            <Input class="font-mono" bind:value={f.hostname} placeholder={guest.name} />
          </label>
        {/if}
        {#if state.network}
          <div class="flex flex-wrap items-center gap-2">
            <span class="w-24 shrink-0 text-sm text-muted-fg">{$LL.virtCiNetwork()}</span>
            <div class="flex flex-wrap gap-1">
              <Button type="button" size="sm" variant={f.static ? 'secondary' : 'primary'} aria-pressed={!f.static} onclick={() => (f.static = false)}>DHCP</Button>
              <Button type="button" size="sm" variant={f.static ? 'primary' : 'secondary'} aria-pressed={f.static} onclick={() => (f.static = true)}>{$LL.virtCiStatic()}</Button>
            </div>
          </div>
          {#if f.static}
            <div class="flex flex-wrap gap-3">
              <label class="block min-w-40 flex-1 space-y-1 text-sm">
                <span class="text-muted-fg">{$LL.virtCiAddress()}</span>
                <Input class="font-mono" bind:value={f.address} placeholder="192.168.1.50/24" />
              </label>
              <label class="block min-w-40 flex-1 space-y-1 text-sm">
                <span class="text-muted-fg">{$LL.virtCiGateway()}</span>
                <Input class="font-mono" bind:value={f.gateway} placeholder="192.168.1.1" />
              </label>
            </div>
          {/if}
        {:else}
          <p class="text-xs text-muted-fg">{$LL.virtCiNoNetwork()}</p>
        {/if}
        <div class="flex flex-wrap gap-3">
          <label class="block min-w-40 flex-1 space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtCiDns()}</span>
            <Input class="font-mono" bind:value={f.dns} placeholder="1.1.1.1 9.9.9.9" />
          </label>
          <label class="block min-w-40 flex-1 space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtCiSearch()}</span>
            <Input class="font-mono" bind:value={f.search} placeholder="lan" />
          </label>
        </div>
        <p class="text-xs text-faint-fg">{$LL.virtCiApplies()}</p>
        <div class="flex justify-end">
          <Button type="submit" size="sm" disabled={busy || f.user.trim() === ''}>{$LL.save()}</Button>
        </div>
      </form>
    {/if}
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
