<script lang="ts">
  import { Badge, Button, Card, Checkbox, Icon, IconButton, Input, SegmentedControl, Select, Spinner } from '@lollipopkit/desk-ui'
  import { api } from '../../../lib/api'
  import { fmtBytes } from '../../../lib/format'
  import {
    bootDraft,
    bootOrder,
    cpuChange,
    cpuDraft,
    diskUpdate,
    displayChange,
    displayDraft,
    gibBytes,
    memoryChange,
    memoryDraft,
    moveItem,
    nicDraft,
    nicHardware,
    nicUpdate,
    num,
    offerKey,
    offerRef,
    outcomeText,
    sameChange,
    virtErrorText,
    virtRequestText,
    type CpuDraft,
    type DisplayDraft,
    type MemoryDraft,
    type NicDraft,
  } from '../../../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type {
    VirtCreateForm,
    VirtDeviceKind,
    VirtGuest,
    VirtHardware,
    VirtHostDevice,
    VirtHostDevices,
    VirtHostView,
    VirtHwChange,
    VirtHwDisk,
    VirtHwNic,
    VirtUsbNaming,
    VirtVolume,
  } from '../../../types'

  /// A guest's hardware, grouped as the design's hardware view: each group
  /// edits its part and saves it as one change, made from the read whose
  /// revision it carries, then reads the guest again. Whether the host takes
  /// a change is the agent's answer (`sbm_virt::hardware::issue`), said after
  /// it is sent; the pickers come from what a new guest of its kind could be
  /// made of (`/virt/create/form`).
  interface Props {
    view: VirtHostView
    guest: VirtGuest
    sudoPassword: string | null
    /// Told after a change, so the page reads the host again.
    onchanged: () => void
  }

  const { view, guest, sudoPassword, onchanged }: Props = $props()

  const pve = $derived(view.host.kind === 'pve')

  let hw = $state<VirtHardware | null>(null)
  let readError = $state('')
  let form = $state<VirtCreateForm | null>(null)
  let error = $state('')
  let notice = $state('')
  let busy = $state(false)
  /// What waits for its second click: `disk:<key>`, `nic:<key>`,
  /// `dev:<key>`, `firmware`, `revert`.
  let confirm = $state<string | null>(null)
  let deleteVolume = $state(false)
  /// Rows shown open, by key.
  let open = $state<Record<string, boolean>>({})
  let adding = $state<'disk' | 'nic' | 'device' | null>(null)
  let generation = 0

  let cpu = $state<CpuDraft>({ sockets: '', cores: '', online: '', type: '' })
  let mem = $state<MemoryDraft>({ gib: '', minGib: '', swapMib: '' })
  let disks = $state<Record<string, { grow: string; bus: string; cache: string; media: string }>>({})
  let nics = $state<Record<string, NicDraft>>({})
  let display = $state<DisplayDraft>({ protocol: '', listen: '', gpu: '' })
  let boot = $state<{ key: string; on: boolean }[]>([])
  let firmware = $state({ uefi: false, secureBoot: false, storage: '' })
  let newDisk = $state({ existing: false, pool: '', gib: '32', mountPoint: '', volPool: '', volume: '' })
  let volumes = $state<VirtVolume[] | null>(null)
  let newNic = $state({ network: '', model: '' })
  let newDev = $state<{ kind: 'cdrom' | VirtDeviceKind; media: string; device: string; naming: VirtUsbNaming; storage: string }>({
    kind: 'cdrom',
    media: '',
    device: '',
    naming: 'vendor_product',
    storage: '',
  })
  let hostDevices = $state<VirtHostDevices | null>(null)
  let hostDevicesError = $state('')

  /// The page hands a new guest object on every read of the host; only
  /// another guest starts the pane over.
  const guestId = $derived(guest.id)

  $effect(() => {
    void guestId
    untrack(() => {
      hw = null
      form = null
      readError = ''
      error = ''
      notice = ''
      confirm = null
      open = {}
      adding = null
      hostDevices = null
      void read(guest.id)
      void readForm(guest)
    })
  })

  async function read(id: string) {
    const mine = ++generation
    try {
      const answer = await api.virtHardware(id, sudoPassword ?? undefined)
      if (mine !== generation || guest.id !== id) return
      if (answer.error) {
        readError = virtErrorText(answer.error)
        return
      }
      readError = ''
      if (answer.hardware) reset(answer.hardware)
      hw = answer.hardware
    } catch (e) {
      if (mine === generation) readError = virtRequestText(e)
    }
  }

  async function readForm(g: VirtGuest) {
    try {
      const answer = await api.createForm(g.kind, pve ? (g.node ?? undefined) : undefined, sudoPassword ?? undefined)
      if (guest.id !== g.id) return
      form = answer.form
      if (form) {
        newDisk.pool = form.storages[0]?.id ?? ''
        newDisk.volPool = form.storages[0]?.id ?? ''
        newNic.network = form.networks[0]?.id ?? ''
        newNic.model = form.options.nic_models[0] ?? ''
        newDev.storage = form.storages[0]?.id ?? ''
      }
    } catch {
      // The pickers stay empty; what the guest has still shows.
    }
  }

  /// Every draft from what was read.
  function reset(h: VirtHardware) {
    cpu = cpuDraft(h)
    mem = memoryDraft(h)
    disks = Object.fromEntries(
      h.disks.map((d) => [d.key, { grow: d.size !== null ? String(Math.ceil(d.size / 1024 ** 3)) : '', bus: d.bus ?? '', cache: d.cache ?? 'default', media: '' }]),
    )
    nics = Object.fromEntries(h.nics.map((n) => [n.key, nicDraft(n)]))
    display = displayDraft(h)
    boot = bootDraft(h)
    firmware = { uefi: h.firmware?.uefi ?? false, secureBoot: h.firmware?.secure_boot ?? false, storage: '' }
  }

  /// Sends `change` made from the read shown, then reads the guest again. A
  /// read the guest has moved on from is read again, with a notice.
  async function apply(change: VirtHwChange): Promise<boolean> {
    const h = hw
    const id = guest.id
    if (!h) return false
    busy = true
    error = ''
    notice = ''
    try {
      const { outcome, error: err } = await api.virtHardwareChange(id, h.revision, change, sudoPassword ?? undefined)
      if (guest.id !== id) return false
      if (err) {
        if (err.kind === 'conflict') {
          notice = $LL.virtHwConflict()
          await read(id)
        } else error = virtErrorText(err)
        return false
      }
      notice = outcomeText(outcome)
      adding = null
      await read(id)
      onchanged()
      return true
    } catch (e) {
      error = virtRequestText(e)
      return false
    } finally {
      busy = false
    }
  }

  async function revertAll() {
    if (confirm !== 'revert') {
      confirm = 'revert'
      return
    }
    const h = hw
    const id = guest.id
    confirm = null
    if (!h) return
    busy = true
    error = ''
    notice = ''
    try {
      const { error: err } = await api.virtHardwareRevert(id, h.revision, sudoPassword ?? undefined)
      if (err) {
        if (err.kind === 'conflict') notice = $LL.virtHwConflict()
        else error = virtErrorText(err)
      }
      await read(id)
      if (!err) onchanged()
    } catch (e) {
      error = virtRequestText(e)
    } finally {
      busy = false
    }
  }

  /// A destructive change: sent on the second click. What is sent is made
  /// before the confirmation goes, so it is what was asked.
  function twice(key: string, change: () => VirtHwChange) {
    if (confirm !== key) {
      confirm = key
      deleteVolume = false
      return
    }
    const made = change()
    confirm = null
    deleteVolume = false
    void apply(made)
  }

  function toggle(key: string) {
    open[key] = !open[key]
    confirm = null
  }

  async function pickVolPool(id: string) {
    newDisk.volPool = id
    newDisk.volume = ''
    volumes = null
    if (!id) return
    try {
      const answer = await api.virtVolumes(id, sudoPassword ?? undefined)
      if (newDisk.volPool === id) volumes = answer.volumes ?? []
    } catch (e) {
      error = virtRequestText(e)
    }
  }

  async function readHostDevices() {
    if (hostDevices !== null) return
    const id = guest.id
    hostDevicesError = ''
    try {
      const answer = await api.virtHostDevices(id, sudoPassword ?? undefined)
      if (guest.id !== id) return
      if (answer.error) hostDevicesError = virtErrorText(answer.error)
      else hostDevices = answer.devices
    } catch (e) {
      hostDevicesError = virtRequestText(e)
    }
  }

  function pickDevKind(kind: typeof newDev.kind) {
    newDev.kind = kind
    newDev.device = ''
    newDev.naming = 'vendor_product'
    if (kind === 'usb' || kind === 'pci') void readHostDevices()
  }

  function openAdd(what: 'disk' | 'nic' | 'device') {
    adding = what
    if (what === 'disk' && newDisk.existing && volumes === null) void pickVolPool(newDisk.volPool)
    if (what === 'device') pickDevKind(newDev.kind)
  }

  const lxc = $derived(hw?.kind === 'lxc')
  const media = $derived(lxc ? [] : (form?.media ?? []))
  const storages = $derived(form?.storages ?? [])
  const networks = $derived(form?.networks ?? [])
  const blockDisks = $derived((hw?.disks ?? []).filter((d) => d.kind !== 'cdrom'))
  const cdroms = $derived((hw?.disks ?? []).filter((d) => d.kind === 'cdrom'))
  const pickedDevice = $derived.by<VirtHostDevice | null>(() => {
    const list = newDev.kind === 'usb' ? hostDevices?.usb : newDev.kind === 'pci' ? hostDevices?.pci : undefined
    return list?.find((d) => d.id === newDev.device) ?? null
  })
  const hasAddress = $derived(pickedDevice !== null && !pickedDevice.mapping && pickedDevice.usb_bus !== null && (pickedDevice.usb_port !== null || pickedDevice.usb_device !== null))

  function addDisk() {
    const mount = lxc ? newDisk.mountPoint.trim() || null : null
    if (newDisk.existing) {
      if (!newDisk.volume) return
      void apply({ op: 'attach_volume', volume: { pool: newDisk.volPool, volume: newDisk.volume }, mount_point: mount })
    } else void apply({ op: 'add_disk', pool: newDisk.pool, gib: Math.floor(num(newDisk.gib) ?? 0), mount_point: mount })
  }

  function addDevice() {
    const d = newDev
    if (d.kind === 'cdrom') {
      void apply({ op: 'add_cdrom', media: offerRef(d.media) ?? null })
      return
    }
    void apply({
      op: 'add_device',
      kind: d.kind,
      host: d.kind === 'tpm' ? null : pickedDevice,
      storage: d.kind === 'tpm' && pve ? d.storage || null : null,
      usb_naming: d.kind === 'usb' && hasAddress ? d.naming : 'vendor_product',
    })
  }

  function diskSummary(d: VirtHwDisk): string {
    return [d.size !== null ? fmtBytes(d.size) : null, d.format, lxc ? d.mount_point : d.bus, d.readonly ? $LL.virtReadonly() : null].filter(Boolean).join(' · ')
  }

  function nicLabel(n: VirtHwNic, i: number): string {
    return n.name ?? (pve ? n.key : `nic${i}`)
  }

  /// The network a NIC is on, among those the form offers.
  function nicNetwork(n: VirtHwNic) {
    return networks.find((x) => x.name === n.source || (x.bridge !== null && x.bridge === n.source)) ?? null
  }

  function bootLabel(key: string): string {
    const d = hw?.disks.find((x) => x.key === key)
    if (d) return d.kind === 'cdrom' ? `${key} · ${$LL.virtHwCdrom()}` : `${key} · ${$LL.virtDisk()}`
    const n = hw?.nics.find((x) => x.key === key)
    if (n) return `${key} · ${$LL.virtHwPxe()}${n.source ? ` · ${n.source}` : ''}`
    return key
  }

  function options(current: string, offered: string[]): string[] {
    return current === '' || offered.includes(current) ? offered : [current, ...offered]
  }

  function mediaName(source: string | null): string {
    if (!source) return $LL.virtHwNoMedia()
    return source.split(/[/:]/).pop() || source
  }

  function groupSize(d: VirtHostDevice): string {
    return d.iommu_group !== null ? $LL.virtHwIommuGroup({ group: d.iommu_group, n: d.group_size }) : ''
  }
</script>

{#snippet head(title: string, right: string = '', warn: boolean = false)}
  <div class="flex items-center gap-[9px]">
    <h3 class="text-[15px] font-semibold">{title}</h3>
    {#if right}
      <span class="ml-auto truncate text-[12px] {warn ? 'text-(--color-warning)' : 'text-(--text-tertiary)'}">{right}</span>
    {/if}
  </div>
{/snippet}

{#snippet row(key: string, title: string, summary: string)}
  <button type="button" class="flex w-full items-center gap-[9px] rounded-[9px] px-[9px] py-[7px] text-left transition-colors hover:bg-(--fill-hover)" aria-expanded={!!open[key]} onclick={() => toggle(key)}>
    <span class="lk-mono text-[13px] font-semibold text-(--text-primary)">{title}</span>
    <span class="min-w-0 flex-1 truncate text-[12px] text-(--text-secondary)">{summary}</span>
    <Icon name={open[key] ? 'expand_less' : 'expand_more'} size={18} />
  </button>
{/snippet}

{#snippet seg(label: string, items: string[], value: string, pick: (v: string) => void)}
  <div class="flex flex-wrap items-center gap-[9px]">
    <span class="text-[12px] text-(--text-secondary)">{label}</span>
    <SegmentedControl size="sm" {value} options={items.map((item) => ({ value: item, label: item }))} label={label} onchange={pick} />
  </div>
{/snippet}

{#snippet saveBar(disabled: boolean, onsave: () => void)}
  <div class="flex justify-end">
    <Button size="sm" disabled={busy || disabled} onclick={onsave}>{$LL.save()}</Button>
  </div>
{/snippet}

{#snippet removeBar(key: string, name: string, change: () => VirtHwChange, withVolume: boolean = false)}
  {#if confirm === key}
    {#if withVolume}
      <Checkbox bind:checked={deleteVolume} label={$LL.virtHwDeleteVolume()} />
    {/if}
    <p class="text-[12px] text-(--color-danger)">{$LL.virtHwConfirmAgain()}</p>
  {/if}
  <div class="flex justify-end gap-[9px]">
    {#if confirm === key}
      <Button variant="secondary" size="sm" onclick={() => (confirm = null)} icon="close">{$LL.cancel()}</Button>
    {/if}
    <Button variant="destructive" size="sm" disabled={busy} onclick={() => twice(key, change)} icon="delete">
      {confirm === key ? $LL.virtHwConfirmRemove({ name }) : $LL.virtHwRemove()}
    </Button>
  </div>
{/snippet}

{#if error}
  <Card><p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p></Card>
{/if}
{#if notice}
  <Card><p class="whitespace-pre-wrap text-[13px] text-(--text-secondary)">{notice}</p></Card>
{/if}

{#if readError}
  <Card><p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{readError}</p></Card>
{:else if !hw}
  <Card><Spinner class="h-5 w-5" /></Card>
{/if}

{#if hw}
  {@const h = hw}
  {@const s = h.support}

  {#if h.pending.length > 0}
    <!-- What the running guest has differently from its next start. -->
    <Card class="space-y-[13px]">
      {@render head($LL.virtHwPending(), $LL.virtHwNextStart(), true)}
      <ul>
        {#each h.pending as p (p.key)}
          <li class="flex flex-wrap items-center gap-[9px] border-t border-(--border-hairline) py-[7px] text-[12px]">
            <span class="lk-mono text-(--text-primary)">{p.key}</span>
            <span class="min-w-0 flex-1 break-all text-(--text-secondary)">
              {p.current ?? '—'} → {p.delete ? $LL.virtHwPendingRemoved() : (p.pending ?? '—')}
            </span>
            {#if pve}
              <Button variant="ghost" size="sm" disabled={busy} onclick={() => void apply({ op: 'revert', keys: [p.key] })} icon="restart_alt">{$LL.virtHwRevert()}</Button>
            {/if}
          </li>
        {/each}
      </ul>
      {#if confirm === 'revert'}
        <p class="text-[12px] text-(--color-warning)">{$LL.virtHwRevertAllNote()}</p>
      {/if}
      <div class="flex justify-end gap-[9px]">
        {#if confirm === 'revert'}
          <Button variant="secondary" size="sm" onclick={() => (confirm = null)}>{$LL.cancel()}</Button>
        {/if}
        <Button variant="secondary" size="sm" disabled={busy} onclick={() => void revertAll()} icon="restart_alt">
          {confirm === 'revert' ? $LL.virtHwConfirmRevertAll() : $LL.virtHwRevertAll()}
        </Button>
      </div>
    </Card>
  {/if}

  <!-- CPU. -->
  <Card class="space-y-[13px]">
    {@render head(lxc ? 'CPU' : $LL.virtHwProcessor(), h.limits.host_cpus !== null ? $LL.virtHwHostCpus({ n: h.limits.host_cpus }) : '')}
    <div class="flex flex-wrap gap-[13px]">
      {#if !lxc}
        <Input class="w-28" label={$LL.virtHwSockets()} type="number" min="1" bind:value={cpu.sockets} />
      {/if}
      <Input class="w-28" label={$LL.virtCores()} type="number" min="1" bind:value={cpu.cores} />
      {#if !lxc}
        <Input class="w-36" label={$LL.virtHwOnline()} type="number" min="1" bind:value={cpu.online} placeholder={$LL.virtHwAll()} />
      {/if}
    </div>
    {#if pve && !lxc && h.cpu_types.length > 0}
      <Select label={$LL.virtHwCpuType()} class="w-full" bind:value={cpu.type} options={[{ value: '', label: $LL.virtHwDefault() }, ...options(cpu.type, h.cpu_types).map((t) => ({ value: t, label: t }))]} />
    {/if}
    {#if !lxc}
      <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwTopology()}: {num(cpu.sockets) ?? '?'} × {num(cpu.cores) ?? '?'} × {h.cpu.threads}</p>
    {/if}
    {@render saveBar(sameChange(cpuChange(cpu), cpuChange(cpuDraft(h))), () => void apply(cpuChange(cpu)))}
  </Card>

  <!-- Memory. -->
  <Card class="space-y-[13px]">
    {@render head($LL.virtMemory(), h.limits.host_memory_bytes !== null ? $LL.virtHwHostMemory({ mem: fmtBytes(h.limits.host_memory_bytes) }) : '')}
    <div class="flex flex-wrap gap-[13px]">
      <Input class="w-36" label={$LL.virtMemoryGib()} type="number" min="0.5" step="0.5" bind:value={mem.gib} />
      {#if h.memory.balloon}
        <Input class="w-48" label={$LL.virtHwMemoryMin()} type="number" min="0" step="0.5" bind:value={mem.minGib} placeholder={$LL.virtHwNone()} />
      {/if}
      {#if lxc}
        <Input class="w-36" label={$LL.virtHwSwap()} type="number" min="0" step="128" bind:value={mem.swapMib} />
      {/if}
    </div>
    {#if h.memory.balloon}
      <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwMemoryMinNote()}</p>
    {/if}
    {@render saveBar(sameChange(memoryChange(mem, h), memoryChange(memoryDraft(h), h)), () => void apply(memoryChange(mem, h)))}
  </Card>

  <!-- Disks: grow, bus, cache, remove; a new or an existing volume. -->
  <Card class="space-y-[9px]">
    {@render head(lxc ? $LL.virtHwDisksLxc() : $LL.virtDisks(), $LL.virtHwTotal({ size: fmtBytes(blockDisks.reduce((n, d) => n + (d.size ?? 0), 0)) }))}
    {#each blockDisks as d (d.key)}
      {@const draft = disks[d.key]}
      <Card variant="raised" padding="0">
        {@render row(`d-${d.key}`, d.key, diskSummary(d))}
        {#if open[`d-${d.key}`] && draft}
          <div class="space-y-[13px] border-t border-(--border-hairline) p-[13px]">
            <dl class="grid grid-cols-[auto_1fr] gap-x-[9px] gap-y-[5px] text-[12px]">
              <dt class="text-(--text-tertiary)">{$LL.virtHwSource()}</dt>
              <dd class="break-all lk-mono text-(--text-secondary)">{d.source ?? '—'}</dd>
              {#if d.storage}
                <dt class="text-(--text-tertiary)">{$LL.virtHwStorage()}</dt>
                <dd class="text-(--text-secondary)">{d.storage}</dd>
              {/if}
            </dl>
            {#if d.resizable}
              <div class="flex flex-wrap items-end gap-[9px]">
                <Input class="w-40" label={$LL.virtHwGrowTo()} type="number" min="1" bind:value={draft.grow} />
                <Button size="sm" disabled={busy || gibBytes(draft.grow) === null || (d.size !== null && (gibBytes(draft.grow) ?? 0) <= d.size)} onclick={() => void apply({ op: 'grow_disk', key: d.key, bytes: gibBytes(draft.grow) ?? 0 })}>{$LL.virtHwGrow()}</Button>
              </div>
              <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwGrowNote()}</p>
            {/if}
            {#if d.kind === 'disk' && (s.buses.length > 0 || s.caches.length > 0)}
              <div class="flex flex-wrap items-end gap-[13px]">
                {#if s.buses.length > 0}
                  <Select class="w-36" label={$LL.virtBus()} bind:value={draft.bus} options={options(d.bus ?? '', s.buses).map((b) => ({ value: b, label: b }))} />
                {/if}
                {#if s.caches.length > 0}
                  <Select class="w-40" label={$LL.virtHwCache()} bind:value={draft.cache} options={options(d.cache ?? 'default', s.caches).map((c) => ({ value: c, label: c }))} />
                {/if}
                <Button size="sm" disabled={busy || diskUpdate(d, draft.bus, draft.cache) === null} onclick={() => void apply(diskUpdate(d, draft.bus, draft.cache)!)}>{$LL.save()}</Button>
              </div>
            {/if}
            {#if d.kind !== 'rootfs'}
              {@render removeBar(`disk:${d.key}`, d.key, () => ({ op: 'remove_disk', key: d.key, delete_volume: deleteVolume }), true)}
            {/if}
          </div>
        {/if}
      </Card>
    {/each}

    {#if adding === 'disk'}
      <Card variant="raised" class="space-y-[13px]">
        {@render head(lxc ? $LL.virtHwAddMount() : $LL.virtHwAddDisk())}
        {@render seg($LL.virtSource(), [$LL.virtHwNewVolume(), $LL.virtHwExistingVolume()], newDisk.existing ? $LL.virtHwExistingVolume() : $LL.virtHwNewVolume(), (v) => {
          newDisk.existing = v === $LL.virtHwExistingVolume()
          if (newDisk.existing && volumes === null) void pickVolPool(newDisk.volPool)
        })}
        {#if storages.length === 0}
          <p class="text-[13px] text-(--text-secondary)">{$LL.virtStorageNone()}</p>
        {:else if !newDisk.existing}
          <Select label={$LL.virtHwStorage()} class="w-full" bind:value={newDisk.pool} options={storages.map((p) => ({ value: p.id, label: `${p.name}${p.available !== null ? ` · ${$LL.virtStorageFree({ type: p.type, free: fmtBytes(p.available) })}` : ` · ${p.type}`}` }))} />
          <Input class="w-36" label={$LL.virtDiskGib()} type="number" min="1" bind:value={newDisk.gib} />
        {:else}
          <Select label={$LL.virtHwStorage()} class="w-full" value={newDisk.volPool} options={storages.map((p) => ({ value: p.id, label: p.name }))} onchange={(e) => void pickVolPool(e.currentTarget.value)} />
          {#if volumes === null}
            <Spinner size="sm" />
          {:else if volumes.length === 0}
            <p class="text-[13px] text-(--text-secondary)">{$LL.virtHwVolumeNone()}</p>
          {:else}
            <Select
              label={$LL.virtHwVolume()}
              class="w-full"
              bind:value={newDisk.volume}
              options={[
                { value: '', label: '—' },
                ...volumes.map((v) => ({ value: v.id, label: [v.name, v.format, v.capacity !== null ? fmtBytes(v.capacity) : null, v.users.some((u) => u.guest_id !== guestId) ? $LL.virtHwInUse() : null].filter(Boolean).join(' · ') })),
              ]}
            />
          {/if}
        {/if}
        {#if lxc}
          <Input class="lk-mono" label={$LL.virtHwMountPoint()} bind:value={newDisk.mountPoint} placeholder="/data" />
        {/if}
        <div class="flex justify-end gap-[9px]">
          <Button variant="secondary" size="sm" onclick={() => (adding = null)}>{$LL.cancel()}</Button>
          <Button
            size="sm"
            disabled={busy || (newDisk.existing ? newDisk.volume === '' : newDisk.pool === '') || (lxc && newDisk.mountPoint.trim() === '')}
            onclick={addDisk}
          >
            {$LL.virtHwAdd()}
          </Button>
        </div>
      </Card>
    {:else}
      <Button variant="ghost" size="sm" icon="add" onclick={() => openAdd('disk')}>
        {lxc ? $LL.virtHwAddMount() : $LL.virtHwAddDisk()}
      </Button>
    {/if}
  </Card>

  <!-- Network interfaces: network, link, firewall; model and MAC; remove. -->
  <Card class="space-y-[9px]">
    {@render head($LL.virtNics(), String(h.nics.length))}
    {#each h.nics as n, i (n.key)}
      {@const draft = nics[n.key]}
      {@const current = nicNetwork(n)}
      <Card variant="raised" padding="0">
        {@render row(`n-${n.key}`, nicLabel(n, i), [n.model, n.source, n.mac, n.link_up ? null : $LL.virtHwLinkDown()].filter(Boolean).join(' · '))}
        {#if open[`n-${n.key}`] && draft}
          <div class="space-y-[13px] border-t border-(--border-hairline) p-[13px]">
            <Select
              label={$LL.virtNetwork()}
              class="w-full"
              bind:value={draft.network}
              options={[
                { value: '', label: $LL.virtHwCurrent({ name: n.source ?? '—' }) },
                ...networks.filter((x) => x.id !== current?.id).map((x) => ({ value: x.id, label: [x.name, x.mode, x.bridge].filter(Boolean).join(' · ') })),
              ]}
            />
            <div class="flex flex-wrap items-start justify-between gap-[13px]">
              <div>
                <p class="text-[13px]">{$LL.virtHwLinkUp()}</p>
                <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwLinkNote()}</p>
              </div>
              <Checkbox label={$LL.virtHwLinkUp()} bind:checked={draft.linkUp} />
            </div>
            {#if n.firewall !== null}
              <Checkbox label={$LL.virtHwFirewall()} bind:checked={draft.firewall} />
            {/if}
            {@render saveBar(nicUpdate(n, draft) === null, () => void apply(nicUpdate(n, draft)!))}
            {#if !lxc && (s.nic_models.length > 0 || s.mac)}
              <div class="flex flex-wrap items-end gap-[13px] border-t border-(--border-hairline) pt-[13px]">
                {#if s.nic_models.length > 0}
                  <Select class="w-40" label={$LL.virtNicModel()} bind:value={draft.model} options={options(n.model ?? '', s.nic_models).map((m) => ({ value: m, label: m }))} />
                {/if}
                {#if s.mac}
                  <Input class="min-w-48 flex-1 lk-mono" label={$LL.virtHwMac()} bind:value={draft.mac} />
                {/if}
                <Button size="sm" disabled={busy || nicHardware(n, draft) === null} onclick={() => void apply(nicHardware(n, draft)!)}>{$LL.save()}</Button>
              </div>
            {/if}
            {@render removeBar(`nic:${n.key}`, nicLabel(n, i), () => ({ op: 'remove_nic', key: n.key }))}
          </div>
        {/if}
      </Card>
    {/each}

    {#if adding === 'nic'}
      <Card variant="raised" class="space-y-[13px]">
        {@render head($LL.virtHwAddNic())}
        {#if networks.length === 0}
          <p class="text-[13px] text-(--text-secondary)">{$LL.virtHwNetworkNone()}</p>
        {:else}
          <label class="block space-y-[5px] text-[13px]">
            <span class="text-(--text-secondary)">{$LL.virtNetwork()}</span>
            <Select class="w-full" label={$LL.virtNetwork()} bind:value={newNic.network} options={networks.map((x) => ({ value: x.id, label: [x.name, x.mode, x.bridge].filter(Boolean).join(' · ') }))} />
          </label>
          {#if !lxc && s.nic_models.length > 0}
            {@render seg($LL.virtNicModel(), s.nic_models, newNic.model, (v) => (newNic.model = v))}
          {/if}
        {/if}
        <div class="flex justify-end gap-[9px]">
          <Button variant="secondary" size="sm" onclick={() => (adding = null)}>{$LL.cancel()}</Button>
          <Button
            size="sm"
            disabled={busy || newNic.network === ''}
            onclick={() => void apply({ op: 'add_nic', network: newNic.network, model: !lxc && newNic.model ? newNic.model : null })}
          >
            {$LL.virtHwAdd()}
          </Button>
        </div>
      </Card>
    {:else}
      <Button variant="ghost" size="sm" icon="add" onclick={() => openAdd('nic')}>{$LL.virtHwAddNic()}</Button>
    {/if}
  </Card>

  {#if !lxc}
    <!-- CD-ROM drives and devices given to the guest. -->
    <Card class="space-y-[9px]">
      {@render head($LL.virtHwDevices(), String(cdroms.length + h.devices.length))}
      {#each cdroms as d (d.key)}
        {@const draft = disks[d.key]}
        <Card variant="raised" padding="0">
          {@render row(`c-${d.key}`, d.key, d.cloud_init ? $LL.virtHwCiDrive() : `${$LL.virtHwCdrom()} · ${mediaName(d.source)}`)}
          {#if open[`c-${d.key}`] && draft}
            <div class="space-y-[13px] border-t border-(--border-hairline) p-[13px]">
              {#if !d.cloud_init}
                <div class="flex flex-wrap items-end gap-[9px]">
                  <Select class="min-w-48 flex-1" label={$LL.virtHwMedia()} bind:value={draft.media} options={[{ value: '', label: '—' }, ...media.map((o) => ({ value: offerKey(o), label: `${o.volume.name} · ${o.pool}` }))]} />
                  <Button size="sm" disabled={busy || draft.media === ''} onclick={() => void apply({ op: 'set_media', key: d.key, media: offerRef(draft.media) ?? null })} icon="upload">{$LL.virtHwInsert()}</Button>
                  {#if d.source}
                    <Button variant="secondary" size="sm" disabled={busy} onclick={() => void apply({ op: 'set_media', key: d.key, media: null })} icon="eject">{$LL.virtHwEject()}</Button>
                  {/if}
                </div>
              {:else}
                <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwCiDriveNote()}</p>
              {/if}
              {@render removeBar(`dev:${d.key}`, d.key, () => ({ op: 'remove_disk', key: d.key, delete_volume: false }))}
            </div>
          {/if}
        </Card>
      {/each}
      {#each h.devices as d (d.key)}
        <Card variant="raised" padding="0">
          {@render row(`v-${d.key}`, d.kind === 'pci' ? 'PCI' : d.kind === 'usb' ? 'USB' : 'TPM', [d.key, d.detail, d.mapping ? $LL.virtHwMapping() : null].filter(Boolean).join(' · '))}
          {#if open[`v-${d.key}`]}
            <div class="space-y-[13px] border-t border-(--border-hairline) p-[13px]">
              {@render removeBar(`dev:${d.key}`, d.key, () => ({ op: 'remove_device', key: d.key }))}
            </div>
          {/if}
        </Card>
      {/each}

      {#if adding === 'device'}
        <Card variant="raised" class="space-y-[13px]">
          {@render head($LL.virtHwAddDevice())}
          <SegmentedControl
            size="sm"
            label={$LL.virtHwAddDevice()}
            value={newDev.kind}
            options={[
              { value: 'cdrom', label: $LL.virtHwCdrom() },
              ...(s.usb ? [{ value: 'usb', label: 'USB' }] : []),
              ...(s.pci ? [{ value: 'pci', label: 'PCI' }] : []),
              ...(s.tpm && !h.devices.some((x) => x.kind === 'tpm') ? [{ value: 'tpm', label: 'TPM' }] : []),
            ]}
            onchange={(kind) => pickDevKind(kind as typeof newDev.kind)}
          />
          {#if newDev.kind === 'cdrom'}
            <Select label={$LL.virtHwMedia()} class="w-full" bind:value={newDev.media} options={[{ value: '', label: $LL.virtHwNoMedia() }, ...media.map((o) => ({ value: offerKey(o), label: `${o.volume.name} · ${o.pool}` }))]} />
          {:else if newDev.kind === 'tpm'}
            {#if pve}
              <Select label={$LL.virtHwTpmStorage()} class="w-full" bind:value={newDev.storage} options={storages.map((p) => ({ value: p.id, label: p.name }))} />
            {/if}
          {:else if hostDevicesError}
            <p class="text-[13px] text-(--color-danger) whitespace-pre-wrap break-all">{hostDevicesError}</p>
          {:else if !hostDevices}
            <Spinner size="sm" />
          {:else}
            {@const list = newDev.kind === 'usb' ? hostDevices.usb : hostDevices.pci}
            {#if newDev.kind === 'pci' && !hostDevices.iommu}
              <p class="text-[12px] text-(--color-warning)">{$LL.virtHwNoIommu()}</p>
            {/if}
            {#if hostDevices.mappings_only}
              <p class="text-[12px] text-(--text-secondary)">{$LL.virtHwMappingsOnly()}</p>
            {/if}
            {#if list.length === 0}
              <p class="text-[13px] text-(--text-secondary)">{$LL.virtHwNoHostDevices()}</p>
            {:else}
              <ul class="flex max-h-64 flex-col gap-[7px] overflow-y-auto">
                {#each list as d (d.id)}
                  <li>
                    <Card
                      onclick={() => {
                        newDev.device = d.id
                        newDev.naming = 'vendor_product'
                      }}
                      selected={d.id === newDev.device}
                      padding="11px 13px"
                      class="flex flex-col gap-[5px]"
                    >
                      <span class="truncate text-[13px] font-semibold">{d.label}</span>
                      <span class="truncate text-[12px] text-(--text-tertiary)">{[d.id, d.detail, d.mapping ? $LL.virtHwMapping() : null, newDev.kind === 'pci' ? groupSize(d) : null].filter(Boolean).join(' · ')}</span>
                    </Card>
                  </li>
                {/each}
              </ul>
            {/if}
            {#if newDev.kind === 'pci'}
              {#if pickedDevice && pickedDevice.group_size > 1}
                <p class="text-[12px] text-(--color-warning)">{$LL.virtHwIommuGroupNote()}</p>
              {/if}
              <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwPciNote()}</p>
            {/if}
            {#if newDev.kind === 'usb' && hasAddress}
              {@render seg($LL.virtHwUsbNaming(), [$LL.virtHwUsbById(), $LL.virtHwUsbByPort()], newDev.naming === 'address' ? $LL.virtHwUsbByPort() : $LL.virtHwUsbById(), (v) => (newDev.naming = v === $LL.virtHwUsbByPort() ? 'address' : 'vendor_product'))}
              {#if newDev.naming === 'address'}
                <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwUsbByPortNote()}</p>
              {/if}
            {/if}
          {/if}
          <div class="flex justify-end gap-[9px]">
            <Button variant="secondary" size="sm" onclick={() => (adding = null)}>{$LL.cancel()}</Button>
            <Button
              size="sm"
              disabled={busy || ((newDev.kind === 'usb' || newDev.kind === 'pci') && pickedDevice === null) || (newDev.kind === 'tpm' && pve && newDev.storage === '')}
              onclick={addDevice}
            >
              {$LL.virtHwAdd()}
            </Button>
          </div>
        </Card>
      {:else}
        <Button variant="ghost" size="sm" icon="add" onclick={() => openAdd('device')}>
          {$LL.virtHwAddDevice()}
        </Button>
      {/if}
    </Card>
  {/if}

  {#if h.display}
    {@const dp = h.display}
    <!-- Display. -->
    <Card class="space-y-[13px]">
      {@render head($LL.virtHwDisplay(), [dp.protocol, dp.gpu].filter(Boolean).join(' · '))}
      {#if s.protocols.length > 0}
        {@render seg($LL.virtHwProtocol(), options(display.protocol, s.protocols), display.protocol, (v) => (display.protocol = v))}
      {/if}
      {#if s.listen}
        {@render seg($LL.virtHwListen(), options(display.listen, ['127.0.0.1', '0.0.0.0']), display.listen, (v) => (display.listen = v))}
      {/if}
      {#if s.gpus.length > 0}
        <Select class="w-48" label={$LL.virtHwGpu()} bind:value={display.gpu} options={[...(display.gpu === '' ? [{ value: '', label: $LL.virtHwDefault() }] : []), ...options(display.gpu, s.gpus).map((g) => ({ value: g, label: g }))]} />
      {/if}
      {#if dp.port !== null && dp.port > 0}
        <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwPort()}: <span class="lk-mono">{dp.port}</span></p>
      {/if}
      {#if display.listen === '0.0.0.0'}
        <p class="text-[12px] text-(--color-warning)">{$LL.virtHwListenWarn()}</p>
      {/if}
      {@render saveBar(displayChange(h, display) === null, () => void apply(displayChange(h, display)!))}
    </Card>
  {/if}

  {#if h.firmware || h.boot}
    <!-- Boot: firmware and the order. -->
    <Card class="space-y-[13px]">
      {@render head($LL.virtHwBoot(), h.firmware ? (h.firmware.uefi ? 'UEFI' : 'BIOS') : '')}
      {#if h.firmware && (s.uefi || h.firmware.uefi)}
        {@const fw = h.firmware}
        {@render seg($LL.virtFirmware(), ['UEFI', 'BIOS'], firmware.uefi ? 'UEFI' : 'BIOS', (v) => {
          firmware.uefi = v === 'UEFI'
          if (!firmware.uefi) firmware.secureBoot = false
        })}
        <p class="text-[12px] text-(--text-tertiary)">{firmware.uefi ? $LL.virtHwUefiNote() : $LL.virtHwBiosNote()}</p>
        {#if firmware.uefi && s.secure_boot}
          <div class="flex flex-wrap items-start justify-between gap-[13px]">
            <div>
              <p class="text-[13px]">{$LL.virtSecureBoot()}</p>
              <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwSecureBootNote()}</p>
            </div>
            <Checkbox bind:checked={firmware.secureBoot} label={$LL.virtSecureBoot()} />
          </div>
        {/if}
        {#if pve && firmware.uefi && !fw.uefi}
          <Select
            label={$LL.virtHwEfiStorage()}
            class="w-full"
            bind:value={firmware.storage}
            options={[
              { value: '', label: fw.vars_storage ? $LL.virtHwCurrent({ name: fw.vars_storage }) : '—' },
              ...storages.map((p) => ({ value: p.id, label: p.name })),
            ]}
          />
        {/if}
        {#if firmware.uefi !== fw.uefi || firmware.secureBoot !== fw.secure_boot}
          <p class="text-[12px] text-(--color-warning)">{$LL.virtHwFirmwareWarn()}</p>
          <div class="flex justify-end gap-[9px]">
            {#if confirm === 'firmware'}
              <Button variant="secondary" size="sm" onclick={() => (confirm = null)}>{$LL.cancel()}</Button>
            {/if}
            <Button
              size="sm"
              variant={confirm === 'firmware' ? 'destructive' : 'primary'}
              disabled={busy || (pve && firmware.uefi && !fw.uefi && !fw.vars_storage && firmware.storage === '')}
              onclick={() => twice('firmware', () => ({ op: 'set_firmware', uefi: firmware.uefi, secure_boot: firmware.uefi && firmware.secureBoot, storage: firmware.storage || null }))}
            >
              {confirm === 'firmware' ? $LL.virtHwConfirmFirmware() : $LL.save()}
            </Button>
          </div>
        {/if}
      {/if}
      {#if h.boot}
        <p class="text-[12px] text-(--text-tertiary)">{$LL.virtHwBootOrder()}</p>
        <ul class="flex flex-col gap-[7px]">
          {#each boot as b, i (b.key)}
            <li class="flex items-center gap-[9px] rounded-[9px] bg-(--surface-card) px-[9px] py-[7px]">
              <Checkbox aria-label={$LL.virtHwBootOn({ name: b.key })} bind:checked={b.on} />
              <Badge tone={i === 0 && b.on ? 'accent' : 'neutral'}>{i + 1}</Badge>
              <span class="min-w-0 flex-1 truncate lk-mono text-[13px] {b.on ? 'text-(--text-primary)' : 'text-(--text-tertiary)'}">{bootLabel(b.key)}</span>
              <IconButton icon="arrow_upward" label={$LL.virtHwUp()} disabled={i === 0} onclick={() => (boot = moveItem(boot, i, -1))} />
              <IconButton icon="arrow_downward" label={$LL.virtHwDown()} disabled={i === boot.length - 1} onclick={() => (boot = moveItem(boot, i, 1))} />
            </li>
          {/each}
        </ul>
        {@render saveBar(sameChange({ op: 'set_boot', order: bootOrder(boot) }, { op: 'set_boot', order: h.boot }), () => void apply({ op: 'set_boot', order: bootOrder(boot) }))}
      {/if}
    </Card>
  {/if}

  {#if h.config_text}
    <!-- The configuration as the host writes it. -->
    <Card class="space-y-[9px]">
      <button type="button" class="flex w-full items-center gap-[9px] text-left" aria-expanded={!!open.__config} onclick={() => toggle('__config')}>
        <h3 class="text-[13px] font-medium text-(--text-primary)">{$LL.virtHwConfig()}</h3>
        <span class="ml-auto lk-mono text-[12px] text-(--text-tertiary)">{pve ? (lxc ? 'pct config' : 'qm config') : 'virsh dumpxml'}</span>
        <Icon name={open.__config ? 'expand_less' : 'expand_more'} size={18} />
      </button>
      {#if open.__config}
        <div class="overflow-x-auto">
          <pre class="rounded-lg bg-(--surface-control) p-3 lk-mono text-[12px] text-(--text-primary)">{h.config_text}</pre>
        </div>
      {/if}
    </Card>
  {/if}
{/if}
