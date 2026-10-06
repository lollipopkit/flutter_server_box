<script lang="ts">
  import { Button, Card, IconButton, Input, Select, Spinner } from '@serverbox/webui'
  import { Plus, X } from '@lucide/svelte'
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
    return list.map((o) => ({ v: offerKey(o), l: o.volume.name, sub: [o.pool, o.volume.capacity !== null ? fmtBytes(o.volume.capacity) : null].filter(Boolean).join(' · ') }))
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
  <div class="flex items-center gap-2">
    {#if done !== null}
      <span class="h-2 w-2 shrink-0 rounded-full {done ? 'bg-success' : 'bg-warning'}"></span>
    {/if}
    <h3 class="text-sm font-medium text-fg-strong">{title}</h3>
    {#if right}
      <span class="ml-auto truncate text-xs text-faint-fg">{right}</span>
    {/if}
  </div>
{/snippet}

{#snippet choice(items: { v: string; l: string; sub?: string }[], value: string, pick: (v: string) => void)}
  <ul class="max-h-64 overflow-y-auto rounded-lg border border-line p-1">
    {#each items as it (it.v)}
      <li>
        <button
          type="button"
          class="w-full rounded-lg px-3 py-2 text-left transition-colors {it.v === value ? 'bg-primary/10' : 'hover:bg-muted'}"
          aria-pressed={it.v === value}
          onclick={() => pick(it.v)}
        >
          <p class="truncate text-sm text-fg-strong">{it.l}</p>
          {#if it.sub}
            <p class="truncate text-xs text-muted-fg">{it.sub}</p>
          {/if}
        </button>
      </li>
    {/each}
  </ul>
{/snippet}

{#snippet seg(label: string, items: { v: string; l: string }[], value: string, pick: (v: string) => void)}
  <div class="flex flex-wrap items-center gap-2">
    <span class="w-24 shrink-0 text-sm text-muted-fg">{label}</span>
    <div class="flex flex-wrap gap-1">
      {#each items as it (it.v)}
        <Button type="button" size="sm" variant={it.v === value ? 'primary' : 'secondary'} aria-pressed={it.v === value} onclick={() => pick(it.v)}>{it.l}</Button>
      {/each}
    </div>
  </div>
{/snippet}

<form class="space-y-4" onsubmit={create}>
  <Card class="flex items-center gap-2">
    <Plus class="h-4 w-4 shrink-0 text-muted-fg" />
    <p class="truncate text-base font-semibold text-fg-strong">{lxc ? $LL.virtNewLxc() : $LL.virtNewVm()}</p>
    {#if loading}
      <Spinner size="sm" />
    {/if}
    <IconButton class="ml-auto" label={$LL.cancel()} onclick={oncancel}>
      <X class="h-4 w-4" />
    </IconButton>
  </Card>

  <!-- General: the kind (PVE), its name, its VMID, the node. -->
  <Card class="space-y-3">
    {@render head($LL.virtGroupGeneral(), okGeneral, pve && draft.node ? `${$LL.virtNode()} ${draft.node}` : '')}
    {#if pve && view.capabilities.lxc}
      {@render choice(
        [
          { v: 'qemu', l: $LL.virtVm(), sub: $LL.virtVmSub() },
          { v: 'lxc', l: $LL.virtLxc(), sub: $LL.virtLxcSub() },
        ],
        draft.kind,
        (v) => (draft.kind = v as CreateDraft['kind']),
      )}
    {/if}
    <div class="flex flex-wrap gap-3">
      <label class="block min-w-0 flex-1 space-y-1 text-sm">
        <span class="text-muted-fg">{lxc ? $LL.virtHostname() : $LL.virtName()}</span>
        <Input class="font-mono" bind:value={draft.name} oninput={() => (nameTyped = true)} />
      </label>
      {#if pve}
        <label class="block w-36 space-y-1 text-sm">
          <span class="text-muted-fg">VMID</span>
          <Input type="number" min="100" bind:value={draft.vmid} placeholder={$LL.virtVmidNext()} oninput={() => (vmidTyped = true)} />
        </label>
      {/if}
    </div>
    {#if pve && online.length > 1}
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtNode()}</span>
        <Select class="w-full" bind:value={draft.node}>
          {#each online as n (n.name)}
            <option value={n.name}>{n.name}</option>
          {/each}
        </Select>
      </label>
    {/if}
  </Card>

  {#if formError}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger whitespace-pre-wrap break-all">{formError}</p>
    </Card>
  {:else if !form}
    <Card><Spinner class="h-5 w-5" /></Card>
  {:else}
    {@const f = form}
    {@const o = f.options}
    <!-- System: what it boots from, its firmware; a container's template and login. -->
    <Card class="space-y-3">
      {@render head(lxc ? $LL.virtTemplate() : $LL.virtGroupSystem(), okSystem)}
      {#if lxc}
        {#if f.media.length === 0}
          <p class="text-sm text-muted-fg">{$LL.virtTemplateNone()}</p>
        {:else}
          {@render choice(offers(f.media), draft.media, (v) => (draft.media = v))}
        {/if}
        <label class="flex items-start gap-2 text-sm">
          <input class="mt-1" type="checkbox" bind:checked={draft.unprivileged} />
          <span>
            <span class="text-fg">{$LL.virtUnprivileged()}</span>
            <span class="block text-xs text-faint-fg">{$LL.virtUnprivilegedNote()}</span>
          </span>
        </label>
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtRootPassword()}</span>
          <Input type="password" autocomplete="new-password" bind:value={draft.password} />
        </label>
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtSshKeys()}</span>
          <textarea class="w-full rounded-lg border border-line bg-surface px-3 py-2 font-mono text-xs text-fg" rows="3" bind:value={draft.sshKeys} placeholder="ssh-ed25519 AAAA…"></textarea>
        </label>
        <p class="text-xs text-faint-fg">{$LL.virtRootLoginNote()}</p>
      {:else}
        {#if o.cloud_images}
          {@render seg(
            $LL.virtSource(),
            [
              { v: 'media', l: $LL.virtSourceMedia() },
              { v: 'image', l: $LL.virtSourceImage() },
            ],
            draft.source,
            (v) => (draft.source = v as CreateDraft['source']),
          )}
        {/if}
        {#if image}
          {#if f.images.length === 0}
            <p class="text-sm text-muted-fg">{$LL.virtImageNone()}</p>
          {:else}
            {@render choice(offers(f.images), draft.image, (v) => (draft.image = v))}
          {/if}
        {:else if f.media.length === 0}
          <p class="text-sm text-muted-fg">{$LL.virtMediaNone()}</p>
        {:else}
          {@render choice(offers(f.media), draft.media, (v) => (draft.media = v))}
        {/if}
        {#if o.uefi}
          {@render seg(
            $LL.virtFirmware(),
            [
              { v: 'uefi', l: 'UEFI' },
              { v: 'bios', l: 'BIOS' },
            ],
            draft.uefi ? 'uefi' : 'bios',
            (v) => (draft.uefi = v === 'uefi'),
          )}
        {/if}
        {#if (o.secure_boot && draft.uefi) || o.tpm}
          <div class="flex flex-wrap gap-4 text-sm">
            {#if o.secure_boot && draft.uefi}
              <label class="flex items-center gap-1.5 text-fg"><input type="checkbox" bind:checked={draft.secureBoot} /> {$LL.virtSecureBoot()}</label>
            {/if}
            {#if o.tpm}
              <label class="flex items-center gap-1.5 text-fg"><input type="checkbox" bind:checked={draft.tpm} /> {$LL.virtTpm()}</label>
            {/if}
          </div>
        {/if}
      {/if}
    </Card>

    {#if image}
      <!-- cloud-init: the account and address the image boots with. -->
      <Card class="space-y-3">
        {@render head($LL.virtCloudInit(), null)}
        {#if !o.cloud_init}
          <p class="text-sm text-muted-fg">{$LL.virtCiMissing({ why: o.cloud_init_missing ?? '' })}</p>
        {:else}
          <p class="text-xs text-faint-fg">{$LL.virtCiNote()}</p>
          <div class="flex flex-wrap gap-3">
            <label class="block min-w-40 flex-1 space-y-1 text-sm">
              <span class="text-muted-fg">{$LL.virtCiUser()}</span>
              <Input class="font-mono" autocomplete="off" bind:value={draft.ci.user} />
            </label>
            <label class="block min-w-40 flex-1 space-y-1 text-sm">
              <span class="text-muted-fg">{$LL.virtCiPassword()}</span>
              <Input type="password" autocomplete="new-password" bind:value={draft.ci.password} />
            </label>
          </div>
          <label class="block space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtSshKeys()}</span>
            <textarea class="w-full rounded-lg border border-line bg-surface px-3 py-2 font-mono text-xs text-fg" rows="3" bind:value={draft.ci.sshKeys} placeholder="ssh-ed25519 AAAA…"></textarea>
          </label>
          {#if !pve}
            <label class="block space-y-1 text-sm">
              <span class="text-muted-fg">{$LL.virtHostname()}</span>
              <Input class="font-mono" bind:value={draft.ci.hostname} placeholder={draft.name.trim()} />
            </label>
          {/if}
          {@render seg(
            $LL.virtCiNetwork(),
            [
              { v: 'dhcp', l: 'DHCP' },
              { v: 'static', l: $LL.virtCiStatic() },
            ],
            draft.ci.static ? 'static' : 'dhcp',
            (v) => (draft.ci.static = v === 'static'),
          )}
          {#if draft.ci.static}
            <div class="flex flex-wrap gap-3">
              <label class="block min-w-40 flex-1 space-y-1 text-sm">
                <span class="text-muted-fg">{$LL.virtCiAddress()}</span>
                <Input class="font-mono" bind:value={draft.ci.address} placeholder="192.168.1.50/24" />
              </label>
              <label class="block min-w-40 flex-1 space-y-1 text-sm">
                <span class="text-muted-fg">{$LL.virtCiGateway()}</span>
                <Input class="font-mono" bind:value={draft.ci.gateway} placeholder="192.168.1.1" />
              </label>
            </div>
          {/if}
          <div class="flex flex-wrap gap-3">
            <label class="block min-w-40 flex-1 space-y-1 text-sm">
              <span class="text-muted-fg">{$LL.virtCiDns()}</span>
              <Input class="font-mono" bind:value={draft.ci.dns} placeholder="1.1.1.1 9.9.9.9" />
            </label>
            <label class="block min-w-40 flex-1 space-y-1 text-sm">
              <span class="text-muted-fg">{$LL.virtCiSearch()}</span>
              <Input class="font-mono" bind:value={draft.ci.search} placeholder="lan" />
            </label>
          </div>
        {/if}
      </Card>
    {/if}

    <!-- Resources. -->
    <Card class="space-y-3">
      {@render head($LL.virtGroupResources(), null, free)}
      <div class="flex flex-wrap gap-3">
        <label class="block w-36 space-y-1 text-sm">
          <span class="text-muted-fg">{lxc ? $LL.virtCores() : 'vCPU'}</span>
          <Input type="number" min="1" bind:value={draft.cores} />
        </label>
        <label class="block w-36 space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtMemoryGib()}</span>
          <Input type="number" min="0.5" step="0.5" bind:value={draft.memoryGib} />
        </label>
      </div>
    </Card>

    <!-- Storage: where the disk goes, its size, its bus. -->
    <Card class="space-y-3">
      {@render head($LL.virtGroupStorage(), okStorage)}
      {#if f.storages.length === 0}
        <p class="text-sm text-muted-fg">{$LL.virtStorageNone()}</p>
      {:else}
        {@render choice(
          f.storages.map((p) => ({
            v: p.id,
            l: p.name,
            sub: p.available !== null ? $LL.virtStorageFree({ type: p.type, free: fmtBytes(p.available) }) : p.type,
          })),
          draft.storage,
          (v) => (draft.storage = v),
        )}
      {/if}
      <label class="block w-36 space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtDiskGib()}</span>
        <Input type="number" min="1" bind:value={draft.diskGib} />
      </label>
      {#if !lxc && o.buses.length > 0}
        {@render seg($LL.virtBus(), o.buses.map((b) => ({ v: b, l: b })), draft.bus, (v) => (draft.bus = v))}
      {/if}
    </Card>

    <!-- Network. -->
    <Card class="space-y-3">
      {@render head($LL.virtNetwork(), null)}
      {@render choice(
        [
          ...f.networks.map((n) => ({
            v: n.id,
            l: n.name,
            sub: [n.mode, n.bridge, n.cidrs[0]].filter(Boolean).join(' · '),
          })),
          { v: '', l: $LL.virtNoNetwork() },
        ],
        draft.network,
        (v) => (draft.network = v),
      )}
      {#if !lxc && o.nic_models.length > 0 && draft.network !== ''}
        {@render seg($LL.virtNicModel(), o.nic_models.map((m) => ({ v: m, l: m })), draft.nicModel, (v) => (draft.nicModel = v))}
      {/if}
    </Card>
  {/if}

  <!-- Confirm. -->
  <Card class="space-y-3">
    {@render head($LL.virtGroupConfirm(), ok)}
    <label class="flex items-center gap-1.5 text-sm text-fg"><input type="checkbox" bind:checked={draft.start} /> {$LL.virtStartAfter()}</label>
    {#if form && !ok}
      <p class="text-xs text-muted-fg">{$LL.virtIncomplete()}</p>
    {/if}
    {#if error}
      <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
    {/if}
    <div class="flex justify-end gap-2">
      <Button type="button" variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
      <Button type="submit" disabled={busy || !ok}>
        {#if busy}<Spinner size="sm" />{/if}
        {lxc ? $LL.virtCreateLxcAction() : $LL.virtCreateVmAction()}
      </Button>
    </div>
  </Card>
</form>
