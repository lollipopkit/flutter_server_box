<script lang="ts">
  import { Badge, Button, Card, Checkbox, Icon, Input, SegmentedControl, Select, Spinner, Switch, Textarea } from '@lollipopkit/desk-ui'
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
  <Card><p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p></Card>
{/if}
{#if notice}
  <Card><p class="whitespace-pre-wrap text-[13px] text-(--text-secondary)">{notice}</p></Card>
{/if}

<!-- General: name, description, autostart, protection. -->
<Card class="space-y-[13px]">
  <div class="flex items-center gap-[9px]">
    <h3 class="text-[15px] font-semibold">{$LL.virtGroupGeneral()}</h3>
    {#if hw}
      <Badge class="ml-auto">{hw.autostart ? $LL.virtHwAutostartOn() : $LL.virtHwAutostartOff()}</Badge>
    {/if}
  </div>
  {#if hwError}
    <p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{hwError}</p>
  {:else if !hw}
    <Spinner size="sm" />
  {:else}
    {@const h = hw}
    <div class="flex flex-wrap items-end gap-[9px]">
      <Input class="min-w-0 flex-1 lk-mono" label={guest.kind === 'lxc' && pve ? $LL.virtHostname() : $LL.virtName()} bind:value={name} />
      <Button size="sm" disabled={busy || name.trim() === '' || name.trim() === (h.name ?? '')} onclick={() => void change({ op: 'set_name', name: name.trim() })}>{$LL.save()}</Button>
    </div>
    {#if h.running && !h.rename_running}
      <p class="text-[12px] text-(--text-secondary)">{$LL.virtHwRenameStopped()}</p>
    {/if}
    <Textarea label={$LL.virtHwDescription()} rows={3} bind:value={description} />
    <div class="flex justify-end">
      <Button size="sm" disabled={busy || description === (h.description ?? '')} onclick={() => void change({ op: 'set_description', text: description })}>{$LL.save()}</Button>
    </div>
    <div class="flex flex-wrap items-start justify-between gap-[13px]">
      <div>
        <p class="text-[13px]">{$LL.virtAutostart()}</p>
        <p class="lk-mono text-[12px] text-(--text-tertiary)">{pve ? 'onboot' : 'virsh autostart'}</p>
      </div>
      <Switch label={$LL.virtAutostart()} checked={h.autostart} disabled={busy} onchange={(on) => void change({ op: 'set_autostart', on })} />
    </div>
    {#if h.protection !== null}
      <div class="flex flex-wrap items-start justify-between gap-[13px]">
        <div>
          <p class="text-[13px]">{$LL.virtHwProtection()}</p>
          <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwProtectionNote()}</p>
        </div>
        <Switch label={$LL.virtHwProtection()} checked={h.protection} disabled={busy} onchange={(on) => void change({ op: 'set_protection', on })} />
      </div>
    {/if}
  {/if}
</Card>

{#if guest.kind === 'qemu'}
  <!-- cloud-init: the account and address the system boots with. -->
  <Card class="space-y-[13px]">
    <h3 class="text-[15px] font-semibold">{$LL.virtCloudInit()}</h3>
    {#if ciError}
      <p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{ciError}</p>
    {:else if ci === null}
      {#if !hwError}
        <Spinner size="sm" />
      {/if}
    {:else if ci === 'none'}
      <p class="text-[13px] text-(--text-secondary)">{pve ? $LL.virtCiNoDrive() : $LL.virtCiNoSeed()}</p>
    {:else if ciForm}
      {@const state = ci}
      {@const f = ciForm}
      {#if state.foreign}
        <p class="text-[12px] text-(--color-warning)">{$LL.virtCiForeign()}</p>
      {/if}
      {#if state.nics > 1}
        <p class="text-[12px] text-(--text-secondary)">{$LL.virtCiNics({ n: state.nics })}</p>
      {/if}
      <form class="space-y-[13px]" onsubmit={saveCloudInit}>
        <div class="flex flex-wrap gap-[13px]">
          <Input class="min-w-40 flex-1 lk-mono" label={$LL.virtCiUser()} autocomplete="off" bind:value={f.user} />
          <Input class="min-w-40 flex-1" label={$LL.virtCiNewPassword()} type="password" autocomplete="new-password" bind:value={f.password} disabled={f.removePassword} placeholder={state.password_set ? $LL.virtCiKeepPassword() : ''} />
        </div>
        {#if state.password_set}
          <Checkbox bind:checked={f.removePassword} label={$LL.virtCiRemovePassword()} />
        {/if}
        {#if !pve}
          <Checkbox bind:checked={f.passwordExpires} label={$LL.virtCiPasswordExpires()} />
        {/if}
        <Textarea label={$LL.virtSshKeys()} mono rows={3} bind:value={f.sshKeys} placeholder="ssh-ed25519 AAAA…" />
        {#if !pve}
          <Input class="lk-mono" label={$LL.virtHostname()} bind:value={f.hostname} placeholder={guest.name} />
        {/if}
        {#if state.network}
          <SegmentedControl
            size="sm"
            label={$LL.virtCiNetwork()}
            value={f.static ? 'static' : 'dhcp'}
            options={[{ value: 'dhcp', label: 'DHCP' }, { value: 'static', label: $LL.virtCiStatic() }]}
            onchange={(value) => (f.static = value === 'static')}
          />
          {#if f.static}
            <div class="flex flex-wrap gap-[13px]">
              <Input class="min-w-40 flex-1 lk-mono" label={$LL.virtCiAddress()} bind:value={f.address} placeholder="192.168.1.50/24" />
              <Input class="min-w-40 flex-1 lk-mono" label={$LL.virtCiGateway()} bind:value={f.gateway} placeholder="192.168.1.1" />
            </div>
          {/if}
        {:else}
          <p class="text-[12px] text-(--text-secondary)">{$LL.virtCiNoNetwork()}</p>
        {/if}
        <div class="flex flex-wrap gap-[13px]">
          <Input class="min-w-40 flex-1 lk-mono" label={$LL.virtCiDns()} bind:value={f.dns} placeholder="1.1.1.1 9.9.9.9" />
          <Input class="min-w-40 flex-1 lk-mono" label={$LL.virtCiSearch()} bind:value={f.search} placeholder="lan" />
        </div>
        <p class="text-[12px] text-(--text-tertiary)">{$LL.virtCiApplies()}</p>
        <div class="flex justify-end">
          <Button type="submit" size="sm" disabled={busy || f.user.trim() === ''}>{$LL.save()}</Button>
        </div>
      </form>
    {/if}
  </Card>
{/if}

{#if caps.clone}
  <!-- Clone. -->
  <Card class="space-y-[13px]">
    <div class="flex items-center gap-[9px]">
      <h3 class="text-[15px] font-semibold">{$LL.virtClone()}</h3>
      <span class="ml-auto text-[12px] text-(--text-tertiary)">{fullChoice && !full ? (pve ? $LL.virtCloneLinked() : $LL.virtCloneEmpty()) : $LL.virtCloneFullShort()}</span>
    </div>
    <form class="space-y-[13px]" onsubmit={clone}>
      <div class="flex flex-wrap gap-[13px]">
        <Input class="min-w-0 flex-1 lk-mono" label={$LL.virtCloneName()} bind:value={cloneName} />
        {#if pve}
          <Input class="w-36" label="VMID" type="number" min="100" bind:value={vmid} placeholder={$LL.virtVmidNext()} />
        {/if}
      </div>
      {#if fullChoice}
        <Checkbox bind:checked={full} label={pve ? $LL.virtCloneFull() : $LL.virtCloneCopy()}>
          <span class="text-[12px] text-(--text-tertiary)">{pve ? $LL.virtCloneFullNote() : $LL.virtCloneCopyNote()}</span>
        </Checkbox>
      {/if}
      {#if storages === null}
        <Spinner size="sm" />
      {:else if storages.length > 0 && (!pve || full || !fullChoice)}
        <Select label={$LL.virtCloneStorage()} class="w-full" bind:value={storage} options={[{ value: '', label: $LL.virtSameAsSource() }, ...storages.map((p) => ({ value: p.name, label: `${p.name} · ${p.type}` }))]} />
      {/if}
      {#if pve && caps.clone_target && nodes.length > 1 && (full || !fullChoice)}
        <Select label={$LL.virtCloneNode()} class="w-full" bind:value={node} options={[{ value: '', label: $LL.virtSameAsSource() }, ...nodes.filter((n) => n.name !== guest.node).map((n) => ({ value: n.name, label: n.name }))]} />
      {/if}
      {#if !pve && !stopped}
        <p class="text-[12px] text-(--text-secondary)">{$LL.virtStopFirst()}</p>
      {/if}
      <div class="flex justify-end">
        <Button type="submit" size="sm" icon="content_copy" disabled={busy || cloneName.trim() === '' || (!pve && !stopped)}>{$LL.virtClone()}</Button>
      </div>
    </form>
  </Card>
{/if}

{#if pve && caps.template && !guest.template}
  <!-- Template. -->
  <Card class="space-y-[13px]">
    <h3 class="text-[15px] font-semibold">{$LL.virtTemplate()}</h3>
    <p class="text-[12px] text-(--text-secondary)">{$LL.virtMakeTemplateNote()}</p>
    {#if !stopped}
      <p class="text-[12px] text-(--text-secondary)">{$LL.virtStopFirst()}</p>
    {/if}
    {#if confirmTemplate}
      <p class="text-[12px] text-(--color-warning)">{$LL.virtConfirmAgain()}</p>
    {/if}
    <div class="flex justify-end gap-[9px]">
      {#if confirmTemplate}
        <Button variant="secondary" size="sm" onclick={() => (confirmTemplate = false)} icon="close">{$LL.cancel()}</Button>
      {/if}
      <Button variant="secondary" size="sm" disabled={busy || !stopped} onclick={() => void template()} icon="inventory_2">
        {confirmTemplate ? $LL.virtConfirmTemplate({ name: guest.name }) : $LL.virtMakeTemplate()}
      </Button>
    </div>
  </Card>
{/if}

<!-- Delete. -->
<Card class="space-y-[13px]">
  <div class="flex items-center gap-[9px]">
    <Icon name="warning" size={18} color="var(--color-danger)" />
    <h3 class="text-[15px] font-semibold">{$LL.virtDelete()}</h3>
  </div>
  {#if caps.delete_keeps_disks}
    <div class="flex flex-wrap items-start justify-between gap-[13px]">
      <div>
        <p class="text-[13px]">{$LL.virtDeleteDisks()}</p>
        <p class="text-[12px] text-(--text-tertiary)">{$LL.virtDeleteDisksNote()}</p>
      </div>
      <Checkbox bind:checked={removeDisks} label={$LL.virtDeleteDisks()} />
    </div>
  {:else}
    <p class="text-[12px] text-(--text-secondary)">{$LL.virtDeleteDisksAlways()}</p>
  {/if}
  {#if !stopped}
    <p class="text-[12px] text-(--text-secondary)">{$LL.virtStopFirst()}</p>
  {/if}
  {#if confirmDelete}
    <p class="text-[12px] text-(--color-danger)">{$LL.virtConfirmAgain()}</p>
  {/if}
  <div class="flex justify-end gap-[9px]">
    {#if confirmDelete}
      <Button variant="secondary" size="sm" onclick={() => (confirmDelete = false)} icon="close">{$LL.cancel()}</Button>
    {/if}
    <Button variant="destructive" size="sm" disabled={busy || !stopped} onclick={() => void remove()} icon="delete">
      {confirmDelete ? $LL.virtConfirmDelete({ name: guest.name }) : $LL.virtDeleteGuest()}
    </Button>
  </div>
</Card>
