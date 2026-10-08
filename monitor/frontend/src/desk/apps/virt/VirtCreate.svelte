<script lang="ts">
  import { Badge, Button, Card, Checkbox, Icon, IconButton, Input, SegmentedControl, Select, Spinner, Textarea } from '@lollipopkit/desk-ui'
  import { api } from '../../../lib/api'
  import { fmtBytes } from '../../../lib/format'
  import { allocation, createSpec, offerKey, usesImage, virtErrorText, virtRequestText, type CreateDraft } from '../../../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { VirtCreated, VirtCreateForm, VirtHostView, VirtOffer } from '../../../types'

  /// A new guest: what it is made of, grouped as the design's create view.
  /// What the host offers is the agent's answer (`/virt/create/form`, asked
  /// again when the kind or the PVE node changes); whether the request is
  /// one the host takes is also the agent's, said after it is sent.
  interface Props {
    view: VirtHostView
    sudoPassword: string | null
    /// Told once the host has made it, with the name it was given.
    oncreated: (created: VirtCreated, name: string) => void
    oncancel: () => void
  }

  const { view, sudoPassword, oncreated, oncancel }: Props = $props()

  const pve = $derived(view.host.kind === 'pve')
  const online = $derived(view.host.nodes.filter((n) => n.online))

  let draft = $state<CreateDraft>(blank())
  let form = $state<VirtCreateForm | null>(null)
  let loading = $state(false)
  let formError = $state('')
  let error = $state('')
  let busy = $state(false)
  /// Typed by the operator: no longer follows the next free VMID.
  let nameTyped = $state(false)
  let vmidTyped = $state(false)
  let generation = 0

  function blank(): CreateDraft {
    return {
      kind: 'qemu',
      name: '',
      node: view.host.kind === 'pve' ? (view.host.nodes.find((n) => n.online)?.name ?? '') : '',
      vmid: '',
      cores: '2',
      memoryGib: '4',
      storage: '',
      diskGib: '32',
      source: 'media',
      media: '',
      image: '',
      network: '',
      password: '',
      sshKeys: '',
      unprivileged: true,
      bus: '',
      nicModel: '',
      uefi: true,
      secureBoot: false,
      tpm: false,
      ci: { user: '', password: '', sshKeys: '', hostname: '', static: false, address: '', gateway: '', dns: '', search: '' },
      start: true,
    }
  }

  $effect(() => {
    const kind = draft.kind
    const node = draft.node
    void sudoPassword
    untrack(() => void loadForm(kind, node))
  })

  async function loadForm(kind: CreateDraft['kind'], node: string) {
    const mine = ++generation
    loading = true
    formError = ''
    try {
      const answer = await api.createForm(kind, pve ? node || undefined : undefined, sudoPassword ?? undefined)
      if (mine !== generation) return
      if (answer.error || !answer.form) {
        formError = answer.error ? virtErrorText(answer.error) : ''
        form = null
        return
      }
      adopt(answer.form)
    } catch (e) {
      if (mine === generation) formError = virtRequestText(e)
    } finally {
      if (mine === generation) loading = false
    }
  }

  /// Keeps what was picked where the host still offers it, else its first.
  function adopt(f: VirtCreateForm) {
    const first = form === null
    const keep = (current: string, ids: string[]) => (ids.includes(current) ? current : (ids[0] ?? ''))
    const o = f.options
    draft.storage = keep(draft.storage, f.storages.map((p) => p.id))
    const nets = f.networks.map((n) => n.id)
    if (first || draft.network !== '') draft.network = keep(draft.network, nets)
    draft.media = keep(draft.media, f.media.map(offerKey))
    draft.image = keep(draft.image, f.images.map(offerKey))
    draft.bus = keep(draft.bus, o.buses)
    draft.nicModel = keep(draft.nicModel, o.nic_models)
    if (!o.uefi) draft.uefi = false
    if (!o.secure_boot) draft.secureBoot = false
    if (!o.tpm) draft.tpm = false
    if (!o.cloud_images) draft.source = 'media'
    if (pve && !vmidTyped) draft.vmid = f.next_vmid !== null ? String(f.next_vmid) : ''
    if (pve && !nameTyped && f.next_vmid !== null) draft.name = `${draft.kind === 'lxc' ? 'ct' : 'vm'}-${draft.vmid || f.next_vmid}`
    form = f
  }

  const lxc = $derived(draft.kind === 'lxc')
  const options = $derived(form?.options ?? null)
  const image = $derived(options !== null && usesImage(draft, options))
  const okGeneral = $derived(draft.name.trim() !== '')
  const okSystem = $derived(lxc ? draft.media !== '' : !image || draft.image !== '')
  const okStorage = $derived(draft.storage !== '')
  const ok = $derived(form !== null && okGeneral && okSystem && okStorage)

  const free = $derived.by(() => {
    const alloc = allocation(view.guests)
    const cpu = view.host.nodes.reduce((n, node) => n + (node.max_cpu ?? 0), 0)
    const mem = view.host.nodes.reduce((n, node) => n + (node.mem_total ?? 0), 0)
    return cpu && mem ? $LL.virtFree({ cpu: Math.max(0, cpu - alloc.vcpu), mem: fmtBytes(Math.max(0, mem - alloc.mem)) }) : ''
  })

  function offers(list: VirtOffer[]) {
    return list.map((o) => ({ value: offerKey(o), label: o.volume.name, detail: [o.pool, o.volume.capacity !== null ? fmtBytes(o.volume.capacity) : null].filter(Boolean).join(' · ') }))
  }

  async function create(e: SubmitEvent) {
    e.preventDefault()
    if (!form || !ok) return
    const spec = createSpec(draft, view.host.kind, form.options)
    busy = true
    error = ''
    try {
      const { created, error: err } = await api.createGuest(spec, sudoPassword ?? undefined)
      if (err) error = virtErrorText(err)
      else if (created) oncreated(created, spec.name)
    } catch (err) {
      error = virtRequestText(err)
    } finally {
      busy = false
    }
  }
</script>

{#snippet head(title: string, done: boolean | null, right: string = '')}
  <div class="flex items-center gap-[9px]">
    {#if done !== null}
      <Badge tone={done ? 'success' : 'warning'} dot>{done ? $LL.yes() : $LL.no()}</Badge>
    {/if}
    <h3 class="text-[15px] font-semibold">{title}</h3>
    {#if right}
      <span class="ml-auto truncate text-[12px] text-(--text-tertiary)">{right}</span>
    {/if}
  </div>
{/snippet}

{#snippet choice(items: { value: string; label: string; detail?: string }[], value: string, pick: (value: string) => void)}
  <ul class="flex max-h-64 flex-col gap-[7px] overflow-y-auto">
    {#each items as item (item.value)}
      <li>
        <Card
          onclick={() => pick(item.value)}
          selected={item.value === value}
          padding="11px 13px"
          class="flex flex-col gap-[5px]"
        >
          <span class="truncate text-[13px] font-semibold">{item.label}</span>
          {#if item.detail}
            <span class="truncate text-[12px] text-(--text-tertiary)">{item.detail}</span>
          {/if}
        </Card>
      </li>
    {/each}
  </ul>
{/snippet}

{#snippet seg(label: string, items: { value: string; label: string }[], value: string, pick: (value: string) => void)}
  <div class="flex flex-wrap items-center gap-[9px]">
    <span class="text-[12px] text-(--text-secondary)">{label}</span>
    <SegmentedControl size="sm" {value} options={items} label={label} onchange={pick} />
  </div>
{/snippet}

<form class="space-y-[13px]" onsubmit={create}>
  <Card class="flex items-center gap-[9px]">
    <Icon name="add" size={18} color="var(--text-secondary)" />
    <p class="truncate text-[15px] font-semibold">{lxc ? $LL.virtNewLxc() : $LL.virtNewVm()}</p>
    {#if loading}
      <Spinner size="sm" />
    {/if}
    <IconButton class="ml-auto" icon="close" label={$LL.cancel()} onclick={oncancel} />
  </Card>

  <!-- General: the kind (PVE), its name, its VMID, the node. -->
  <Card class="space-y-[13px]">
    {@render head($LL.virtGroupGeneral(), okGeneral, pve && draft.node ? `${$LL.virtNode()} ${draft.node}` : '')}
    {#if pve && view.capabilities.lxc}
      {@render choice(
        [
          { value: 'qemu', label: $LL.virtVm(), detail: $LL.virtVmSub() },
          { value: 'lxc', label: $LL.virtLxc(), detail: $LL.virtLxcSub() },
        ],
        draft.kind,
        (v) => (draft.kind = v as CreateDraft['kind']),
      )}
    {/if}
    <div class="flex flex-wrap gap-[13px]">
      <label class="block min-w-0 flex-1 space-y-[5px] text-[13px]">
        <span class="text-(--text-secondary)">{lxc ? $LL.virtHostname() : $LL.virtName()}</span>
        <Input class="lk-mono" bind:value={draft.name} oninput={() => (nameTyped = true)} />
      </label>
      {#if pve}
        <label class="block w-36 space-y-[5px] text-[13px]">
          <span class="text-(--text-secondary)">VMID</span>
          <Input type="number" min="100" bind:value={draft.vmid} placeholder={$LL.virtVmidNext()} oninput={() => (vmidTyped = true)} />
        </label>
      {/if}
    </div>
    {#if pve && online.length > 1}
      <Select class="w-full" label={$LL.virtNode()} bind:value={draft.node} options={online.map((n) => ({ value: n.name, label: n.name }))} />
    {/if}
  </Card>

  {#if formError}
    <Card>
      <p class="text-[13px] text-(--color-danger) whitespace-pre-wrap break-all">{formError}</p>
    </Card>
  {:else if !form}
    <Card><Spinner class="h-5 w-5" /></Card>
  {:else}
    {@const f = form}
    {@const o = f.options}
    <!-- System: what it boots from, its firmware; a container's template and login. -->
    <Card class="space-y-[13px]">
      {@render head(lxc ? $LL.virtTemplate() : $LL.virtGroupSystem(), okSystem)}
      {#if lxc}
        {#if f.media.length === 0}
          <p class="text-[13px] text-(--text-secondary)">{$LL.virtTemplateNone()}</p>
        {:else}
          {@render choice(offers(f.media), draft.media, (v) => (draft.media = v))}
        {/if}
        <Checkbox bind:checked={draft.unprivileged}>
          <span>{$LL.virtUnprivileged()}</span>
          <span class="block text-[12px] text-(--text-tertiary)">{$LL.virtUnprivilegedNote()}</span>
        </Checkbox>
        <label class="block space-y-[5px] text-[13px]">
          <span class="text-(--text-secondary)">{$LL.virtRootPassword()}</span>
          <Input type="password" autocomplete="new-password" bind:value={draft.password} />
        </label>
        <Textarea label={$LL.virtSshKeys()} mono rows={3} bind:value={draft.sshKeys} placeholder="ssh-ed25519 AAAA…" />
        <p class="text-[12px] text-(--text-tertiary)">{$LL.virtRootLoginNote()}</p>
      {:else}
        {#if o.cloud_images}
          {@render seg(
            $LL.virtSource(),
            [
              { value: 'media', label: $LL.virtSourceMedia() },
              { value: 'image', label: $LL.virtSourceImage() },
            ],
            draft.source,
            (v) => (draft.source = v as CreateDraft['source']),
          )}
        {/if}
        {#if image}
          {#if f.images.length === 0}
            <p class="text-[13px] text-(--text-secondary)">{$LL.virtImageNone()}</p>
          {:else}
            {@render choice(offers(f.images), draft.image, (v) => (draft.image = v))}
          {/if}
        {:else if f.media.length === 0}
          <p class="text-[13px] text-(--text-secondary)">{$LL.virtMediaNone()}</p>
        {:else}
          {@render choice(offers(f.media), draft.media, (v) => (draft.media = v))}
        {/if}
        {#if o.uefi}
          {@render seg(
            $LL.virtFirmware(),
            [
              { value: 'uefi', label: 'UEFI' },
              { value: 'bios', label: 'BIOS' },
            ],
            draft.uefi ? 'uefi' : 'bios',
            (v) => (draft.uefi = v === 'uefi'),
          )}
        {/if}
        {#if (o.secure_boot && draft.uefi) || o.tpm}
          <div class="flex flex-wrap gap-[13px] text-[13px]">
            {#if o.secure_boot && draft.uefi}
              <Checkbox bind:checked={draft.secureBoot} label={$LL.virtSecureBoot()} />
            {/if}
            {#if o.tpm}
              <Checkbox bind:checked={draft.tpm} label={$LL.virtTpm()} />
            {/if}
          </div>
        {/if}
      {/if}
    </Card>

    {#if image}
      <!-- cloud-init: the account and address the image boots with. -->
      <Card class="space-y-[13px]">
        {@render head($LL.virtCloudInit(), null)}
        {#if !o.cloud_init}
          <p class="text-[13px] text-(--text-secondary)">{$LL.virtCiMissing({ why: o.cloud_init_missing ?? '' })}</p>
        {:else}
          <p class="text-[12px] text-(--text-tertiary)">{$LL.virtCiNote()}</p>
          <div class="flex flex-wrap gap-[13px]">
            <label class="block min-w-40 flex-1 space-y-[5px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.virtCiUser()}</span>
              <Input class="lk-mono" autocomplete="off" bind:value={draft.ci.user} />
            </label>
            <label class="block min-w-40 flex-1 space-y-[5px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.virtCiPassword()}</span>
              <Input type="password" autocomplete="new-password" bind:value={draft.ci.password} />
            </label>
          </div>
          <Textarea label={$LL.virtSshKeys()} mono rows={3} bind:value={draft.ci.sshKeys} placeholder="ssh-ed25519 AAAA…" />
          {#if !pve}
            <label class="block space-y-[5px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.virtHostname()}</span>
              <Input class="lk-mono" bind:value={draft.ci.hostname} placeholder={draft.name.trim()} />
            </label>
          {/if}
          {@render seg(
            $LL.virtCiNetwork(),
            [
              { value: 'dhcp', label: 'DHCP' },
              { value: 'static', label: $LL.virtCiStatic() },
            ],
            draft.ci.static ? 'static' : 'dhcp',
            (v) => (draft.ci.static = v === 'static'),
          )}
          {#if draft.ci.static}
            <div class="flex flex-wrap gap-[13px]">
              <label class="block min-w-40 flex-1 space-y-[5px] text-[13px]">
                <span class="text-(--text-secondary)">{$LL.virtCiAddress()}</span>
                <Input class="lk-mono" bind:value={draft.ci.address} placeholder="192.168.1.50/24" />
              </label>
              <label class="block min-w-40 flex-1 space-y-[5px] text-[13px]">
                <span class="text-(--text-secondary)">{$LL.virtCiGateway()}</span>
                <Input class="lk-mono" bind:value={draft.ci.gateway} placeholder="192.168.1.1" />
              </label>
            </div>
          {/if}
          <div class="flex flex-wrap gap-[13px]">
            <label class="block min-w-40 flex-1 space-y-[5px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.virtCiDns()}</span>
              <Input class="lk-mono" bind:value={draft.ci.dns} placeholder="1.1.1.1 9.9.9.9" />
            </label>
            <label class="block min-w-40 flex-1 space-y-[5px] text-[13px]">
              <span class="text-(--text-secondary)">{$LL.virtCiSearch()}</span>
              <Input class="lk-mono" bind:value={draft.ci.search} placeholder="lan" />
            </label>
          </div>
        {/if}
      </Card>
    {/if}

    <!-- Resources. -->
    <Card class="space-y-[13px]">
      {@render head($LL.virtGroupResources(), null, free)}
      <div class="flex flex-wrap gap-[13px]">
        <label class="block w-36 space-y-[5px] text-[13px]">
          <span class="text-(--text-secondary)">{lxc ? $LL.virtCores() : 'vCPU'}</span>
          <Input type="number" min="1" bind:value={draft.cores} />
        </label>
        <label class="block w-36 space-y-[5px] text-[13px]">
          <span class="text-(--text-secondary)">{$LL.virtMemoryGib()}</span>
          <Input type="number" min="0.5" step="0.5" bind:value={draft.memoryGib} />
        </label>
      </div>
    </Card>

    <!-- Storage: where the disk goes, its size, its bus. -->
    <Card class="space-y-[13px]">
      {@render head($LL.virtGroupStorage(), okStorage)}
      {#if f.storages.length === 0}
        <p class="text-[13px] text-(--text-secondary)">{$LL.virtStorageNone()}</p>
      {:else}
        {@render choice(
          f.storages.map((p) => ({
            value: p.id,
            label: p.name,
            detail: p.available !== null ? $LL.virtStorageFree({ type: p.type, free: fmtBytes(p.available) }) : p.type,
          })),
          draft.storage,
          (v) => (draft.storage = v),
        )}
      {/if}
      <label class="block w-36 space-y-[5px] text-[13px]">
        <span class="text-(--text-secondary)">{$LL.virtDiskGib()}</span>
        <Input type="number" min="1" bind:value={draft.diskGib} />
      </label>
      {#if !lxc && o.buses.length > 0}
        {@render seg($LL.virtBus(), o.buses.map((b) => ({ value: b, label: b })), draft.bus, (v) => (draft.bus = v))}
      {/if}
    </Card>

    <!-- Network. -->
    <Card class="space-y-[13px]">
      {@render head($LL.virtNetwork(), null)}
      {@render choice(
        [
          ...f.networks.map((n) => ({
            value: n.id,
            label: n.name,
            detail: [n.mode, n.bridge, n.cidrs[0]].filter(Boolean).join(' · '),
          })),
          { value: '', label: $LL.virtNoNetwork() },
        ],
        draft.network,
        (v) => (draft.network = v),
      )}
      {#if !lxc && o.nic_models.length > 0 && draft.network !== ''}
        {@render seg($LL.virtNicModel(), o.nic_models.map((m) => ({ value: m, label: m })), draft.nicModel, (v) => (draft.nicModel = v))}
      {/if}
    </Card>
  {/if}

  <!-- Confirm. -->
  <Card class="space-y-[13px]">
    {@render head($LL.virtGroupConfirm(), ok)}
    <Checkbox bind:checked={draft.start} label={$LL.virtStartAfter()} />
    {#if form && !ok}
      <p class="text-[12px] text-(--text-secondary)">{$LL.virtIncomplete()}</p>
    {/if}
    {#if error}
      <p class="text-[13px] text-(--color-danger) whitespace-pre-wrap break-all">{error}</p>
    {/if}
    <div class="flex justify-end gap-[9px]">
      <Button type="button" variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
      <Button type="submit" disabled={busy || !ok}>
        {#if busy}<Spinner size="sm" />{/if}
        {lxc ? $LL.virtCreateLxcAction() : $LL.virtCreateVmAction()}
      </Button>
    </div>
  </Card>
</form>
