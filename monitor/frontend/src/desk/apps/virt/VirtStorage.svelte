<script lang="ts">
  import { Badge, Button, Card, Checkbox, Dialog, Icon, IconButton, Input, Select, Spinner, Switch } from '../../lk'
  import { api } from '../../../lib/api'
  import { fmtBytes } from '../../../lib/format'
  import { refText, virtErrorText, virtRequestText } from '../../../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { VirtChange, VirtHostView, VirtPool, VirtPoolRule, VirtVolume } from '../../../types'

  /// The host's storage: its pools (PVE: each node's storages), one pool's
  /// volumes, and the changes to either. What a change may be is the agent's
  /// answer: it checks each against what the host lists at that moment and
  /// says why not (`sbm_virt::resource::issue`); this only asks.
  interface Props {
    view: VirtHostView
    sudoPassword: string | null
  }

  const { view, sudoPassword }: Props = $props()

  const caps = $derived(view.capabilities)
  const pve = $derived(view.host.kind === 'pve')
  const editable = $derived(caps.storage_edit === true)
  const poolTypes = $derived((caps.pool_types as string[] | undefined) ?? [])

  let pools = $state<VirtPool[] | null>(null)
  let rules = $state<Record<string, VirtPoolRule>>({})
  let selected = $state<string | null>(null)
  let volumes = $state<VirtVolume[] | null>(null)
  let volumesFor = $state<string | null>(null)
  let error = $state('')
  let busy = $state(false)
  let loading = $state(false)

  // Forms.
  let creatingPool = $state(false)
  let poolForm = $state({ name: '', type: '', source: '', target: '', node: '' })
  let creatingVolume = $state(false)
  let volumeForm = $state({ name: '', gib: '10', format: '' })
  let deletingPool = $state<VirtPool | null>(null)
  let deleteStorage = $state(false)
  let deletingVolume = $state<VirtVolume | null>(null)
  let resizing = $state<VirtVolume | null>(null)
  let resizeGib = $state('')
  let cloning = $state<VirtVolume | null>(null)
  let cloneName = $state('')

  const pool = $derived(pools?.find((p) => p.id === selected) ?? null)
  const rule = $derived(pool ? rules[pool.id] : undefined)

  $effect(() => {
    void sudoPassword
    untrack(() => void loadPools())
  })

  $effect(() => {
    const p = pool
    if (p && volumesFor !== p.id) untrack(() => void loadVolumes(p))
  })

  async function loadPools() {
    loading = true
    try {
      const answer = await api.virtStorage(sudoPassword ?? undefined)
      if (answer.error) {
        error = virtErrorText(answer.error)
        return
      }
      pools = answer.pools ?? []
      rules = answer.rules ?? {}
      if (!pools.some((p) => p.id === selected)) selected = pools[0]?.id ?? null
    } catch (e) {
      error = virtRequestText(e)
    } finally {
      loading = false
    }
  }

  async function loadVolumes(p: VirtPool) {
    volumesFor = p.id
    volumes = null
    try {
      const answer = await api.virtVolumes(p.id, sudoPassword ?? undefined)
      if (volumesFor !== p.id) return
      if (answer.error) error = virtErrorText(answer.error)
      volumes = answer.volumes ?? []
    } catch (e) {
      error = virtRequestText(e)
    }
  }

  /// Makes `change` and reads the host again; false when it was refused.
  async function run(change: VirtChange): Promise<boolean> {
    busy = true
    error = ''
    try {
      const { error: e } = await api.virtManage(change, sudoPassword ?? undefined)
      if (e) {
        error = virtErrorText(e)
        return false
      }
      await loadPools()
      volumesFor = null
      return true
    } catch (e) {
      error = virtRequestText(e)
      return false
    } finally {
      busy = false
    }
  }

  function openPoolForm() {
    poolForm = { name: '', type: poolTypes[0] ?? 'dir', source: '', target: '', node: view.host.nodes[0]?.name ?? '' }
    creatingPool = true
  }

  async function createPool(e: SubmitEvent) {
    e.preventDefault()
    const f = poolForm
    const ok = await run({
      op: 'pool_create',
      name: f.name.trim(),
      type: f.type,
      source: f.source.trim(),
      target: f.type === 'netfs' ? f.target.trim() : null,
      node: pve ? f.node || null : null,
    })
    if (ok) creatingPool = false
  }

  function openVolumeForm() {
    volumeForm = { name: '', gib: '10', format: rule?.formats[0] ?? 'raw' }
    creatingVolume = true
  }

  async function createVolume(e: SubmitEvent) {
    e.preventDefault()
    if (!pool) return
    const ok = await run({
      op: 'volume_create',
      pool: pool.id,
      name: volumeForm.name.trim(),
      gib: Math.floor(Number(volumeForm.gib)) || 0,
      format: volumeForm.format,
    })
    if (ok) creatingVolume = false
  }

  function usage(p: VirtPool): number | null {
    return p.capacity && p.used !== null ? Math.min(1, p.used / p.capacity) : null
  }

  const SOURCE_HINT: Record<string, string> = {
    dir: '/srv/images',
    netfs: 'nas.lan:/export/vm',
    nfs: '10.0.0.5:/export/pve',
    logical: 'vg_data',
    lvmthin: 'pve/data',
    zfspool: 'rpool/data',
  }
</script>

{#if error}
  <Card>
    <p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p>
  </Card>
{/if}

<div class="grid gap-[9px] @5xl:grid-cols-[minmax(16rem,20rem)_1fr]">
  <section class="space-y-[9px]">
    <div class="flex items-center gap-[9px]">
      {#if editable && poolTypes.length > 0}
        <Button size="sm" icon="add" onclick={openPoolForm}>{$LL.virtPoolCreate()}</Button>
      {/if}
      <IconButton class="ml-auto" icon="refresh" label={$LL.refresh()} disabled={loading} onclick={() => void loadPools()} />
    </div>
    {#if pools === null}
      <Card><Spinner class="h-5 w-5" /></Card>
    {:else if pools.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-[27px] text-(--text-tertiary)">
        <Icon name="hard_drive" size={48} weight={300} />
        <p class="text-[13px]">{$LL.virtEmptyStorage()}</p>
      </div>
    {:else}
      <ul class="flex flex-col gap-[7px]">
        {#each pools as p (p.id)}
          {@const frac = usage(p)}
          <li>
            <Card
              onclick={() => (selected = p.id)}
              selected={p.id === selected}
              padding="11px 13px"
              class="flex flex-col gap-[7px]"
            >
              <span class="flex min-w-0 items-center gap-[9px]">
                <Icon name="inventory_2" size={17} fill={p.active} color="var(--color-accent-text)" />
                <span class="truncate text-[13px] font-semibold">{p.name}</span>
                <span class="lk-mono ml-auto shrink-0 text-[12px] text-(--text-tertiary)">{p.type}{p.node && view.host.nodes.length > 1 ? ` · ${p.node}` : ''}</span>
              </span>
              {#if frac !== null}
                <span class="h-[3px] overflow-hidden rounded-full bg-(--surface-control)">
                  <span class="block h-full {frac > 0.9 ? 'bg-(--color-danger)' : 'bg-(--color-accent)'}" style="width: {frac * 100}%"></span>
                </span>
                <span class="lk-num text-[12px] text-(--text-tertiary)">{fmtBytes(p.used ?? 0)} / {fmtBytes(p.capacity ?? 0)}</span>
              {/if}
            </Card>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  <section class="min-w-0 space-y-[13px]">
    {#if pool}
      {@const p = pool}
      <Card class="space-y-[13px]">
        <div class="flex flex-wrap items-center gap-[9px]">
          <h3 class="text-[15px] font-semibold">{p.name}</h3>
          {#if !p.active}<Badge>{$LL.virtPoolInactive()}</Badge>{/if}
          {#if p.enabled === false}<Badge tone="warning" dot>{$LL.virtPoolDisabled()}</Badge>{/if}
          {#if p.shared}<Badge>{$LL.virtPoolShared()}</Badge>{/if}
          {#if p.autostart}<Badge>{$LL.virtPoolAutostart()}</Badge>{/if}
          {#if editable}
            <span class="ml-auto flex flex-wrap gap-[5px]">
              {#if pve}
                <Button variant="secondary" size="sm" disabled={busy} onclick={() => void run({ op: 'pool_set_active', pool: p.id, active: p.enabled === false })}>
                  {p.enabled === false ? $LL.virtPoolEnable() : $LL.virtPoolDisable()}
                </Button>
              {:else}
                <Button variant="secondary" size="sm" icon={p.active ? 'stop' : 'play_arrow'} disabled={busy} onclick={() => void run({ op: 'pool_set_active', pool: p.id, active: !p.active })}>
                  {p.active ? $LL.virtPoolStop() : $LL.virtPoolStart()}
                </Button>
                {#if caps.pool_autostart}
                  <Switch label={$LL.virtPoolAutostart()} checked={p.autostart === true} disabled={busy} onchange={(on) => void run({ op: 'pool_set_autostart', pool: p.id, on })} />
                {/if}
                {#if p.active}
                  <Button variant="secondary" size="sm" icon="refresh" disabled={busy} onclick={() => void run({ op: 'pool_refresh', pool: p.id })}>
                    {$LL.virtPoolRefresh()}
                  </Button>
                {/if}
              {/if}
              <IconButton icon="delete" label={$LL.virtPoolDelete()} disabled={busy} onclick={() => { deletingPool = p; deleteStorage = false }} />
            </span>
          {/if}
        </div>
        <dl class="grid grid-cols-[auto_1fr] gap-x-[9px] gap-y-[5px] text-[12px]">
          <dt class="text-(--text-tertiary)">{$LL.virtPoolType()}</dt>
          <dd class="lk-mono text-(--text-secondary)">{p.type}</dd>
          {#if p.path}
            <dt class="text-(--text-tertiary)">{$LL.virtPoolPath()}</dt>
            <dd class="break-all lk-mono text-(--text-secondary)">{p.path}</dd>
          {/if}
          {#if p.source}
            <dt class="text-(--text-tertiary)">{$LL.virtPoolSource()}</dt>
            <dd class="break-all lk-mono text-(--text-secondary)">{p.source}</dd>
          {/if}
          {#if p.content.length > 0}
            <dt class="text-(--text-tertiary)">{$LL.virtPoolContent()}</dt>
            <dd class="text-(--text-secondary)">{p.content.join(', ')}</dd>
          {/if}
          {#if p.available !== null}
            <dt class="text-(--text-tertiary)">{$LL.virtPoolFree()}</dt>
            <dd class="lk-num text-(--text-secondary)">{fmtBytes(p.available)}</dd>
          {/if}
        </dl>
      </Card>

      <Card class="space-y-[9px]">
        {#if editable && p.active}
          <Button size="sm" icon="add" disabled={busy} onclick={openVolumeForm}>{$LL.virtVolumeCreate()}</Button>
        {/if}
        {#if volumes === null}
          <Spinner class="h-5 w-5" />
        {:else if volumes.length === 0}
          <div class="flex flex-col items-center gap-[9px] py-[27px] text-(--text-tertiary)">
            <Icon name="inventory_2" size={48} weight={300} />
            <p class="text-[13px]">{$LL.virtEmptyVolumes()}</p>
          </div>
        {:else}
          <ul>
            {#each volumes as v (v.id)}
              <li class="flex flex-wrap items-center gap-[9px] border-t border-(--border-hairline) py-[7px]">
                <div class="min-w-0 flex-1">
                  <p class="break-all text-[13px] font-semibold">{v.name}</p>
                  <p class="text-[12px] text-(--text-secondary)">
                    {[v.format, v.content, v.capacity !== null ? fmtBytes(v.capacity) : null, v.allocation !== null ? $LL.virtVolumeOnDisk({ size: fmtBytes(v.allocation) }) : null]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                  {#if v.users.length > 0}
                    <p class="text-[12px] text-(--text-tertiary)">{$LL.virtVolumeUsedBy({ who: v.users.map((u) => refText(u, view.guests)).join(', ') })}</p>
                  {/if}
                  {#if v.backs.length > 0}
                    <p class="text-[12px] text-(--text-tertiary)" title={v.backs.join('\n')}>{$LL.virtVolumeBacks({ count: v.backs.length })}</p>
                  {/if}
                </div>
                {#if editable}
                  <span class="flex gap-[5px]">
                    {#if rule?.resizable && caps.volume_resize}
                      <IconButton icon="open_in_full" label={$LL.virtVolumeResize()} size="sm" disabled={busy} onclick={() => { resizing = v; resizeGib = String(Math.ceil((v.capacity ?? 0) / 2 ** 30) + 1) }} />
                    {/if}
                    {#if caps.volume_clone}
                      <IconButton icon="content_copy" label={$LL.virtVolumeClone()} size="sm" disabled={busy} onclick={() => { cloning = v; cloneName = '' }} />
                    {/if}
                    <IconButton icon="delete" label={$LL.virtDelete()} size="sm" disabled={busy} onclick={() => (deletingVolume = v)} />
                  </span>
                {/if}
              </li>
            {/each}
          </ul>
        {/if}
      </Card>
    {:else if pools && pools.length > 0}
      <Card><p class="text-[13px] text-(--text-secondary)">{$LL.virtPoolPick()}</p></Card>
    {/if}
  </section>
</div>

{#if creatingPool}
  <Dialog open wide title={$LL.virtPoolCreate()} onclose={() => (creatingPool = false)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (creatingPool = false)}>{$LL.cancel()}</Button>
      <Button variant="primary" type="submit" form="virt-pool-create" disabled={busy || poolForm.name.trim() === ''}>{$LL.virtCreate()}</Button>
    {/snippet}
    <form id="virt-pool-create" class="space-y-[13px]" onsubmit={(e) => { e.preventDefault(); void createPool(e) }}>
      <Input label={$LL.virtPoolName()} bind:value={poolForm.name} />
      <Select label={$LL.virtPoolType()} bind:value={poolForm.type} options={poolTypes.map((t) => ({ value: t, label: t }))} />
      <Input label={$LL.virtPoolSource()} class="lk-mono" bind:value={poolForm.source} placeholder={SOURCE_HINT[poolForm.type] ?? ''} />
      {#if poolForm.type === 'netfs'}
        <Input label={$LL.virtPoolTarget()} class="lk-mono" bind:value={poolForm.target} placeholder="/mnt/vm" />
      {/if}
      {#if pve && view.host.nodes.length > 1}
        <Select label={$LL.virtPoolNode()} bind:value={poolForm.node} options={view.host.nodes.map((n) => ({ value: n.name, label: n.name }))} />
      {/if}
      {#if error}<p class="text-[12px] text-(--color-danger) whitespace-pre-wrap">{error}</p>{/if}
    </form>
  </Dialog>
{/if}

{#if creatingVolume && pool}
  <Dialog open wide title={$LL.virtVolumeCreate()} onclose={() => (creatingVolume = false)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (creatingVolume = false)}>{$LL.cancel()}</Button>
      <Button variant="primary" type="submit" form="virt-volume-create" disabled={busy || volumeForm.name.trim() === ''}>{$LL.virtCreate()}</Button>
    {/snippet}
    <form id="virt-volume-create" class="space-y-[13px]" onsubmit={(e) => { e.preventDefault(); void createVolume(e) }}>
      <Input label={$LL.virtVolumeName()} class="lk-mono" bind:value={volumeForm.name} placeholder={pve ? 'vm-100-disk-1' : 'data.qcow2'} />
      <div class="flex gap-[13px]">
        <Input class="flex-1" label={$LL.virtVolumeSize()} type="number" min="1" bind:value={volumeForm.gib} />
        <Select label={$LL.virtVolumeFormat()} bind:value={volumeForm.format} options={(rule?.formats ?? ['raw']).map((f) => ({ value: f, label: f }))} />
      </div>
      {#if error}<p class="text-[12px] text-(--color-danger) whitespace-pre-wrap">{error}</p>{/if}
    </form>
  </Dialog>
{/if}

{#if deletingPool}
  {@const p = deletingPool}
  <Dialog open title={$LL.virtPoolDelete()} message={$LL.virtPoolDeleteConfirm({ name: p.name })} onclose={() => (deletingPool = null)}>
    {#snippet icon()}<Icon name="delete" size={52} weight={300} />{/snippet}
    {#if caps.pool_delete_storage && !pve}
      <Checkbox bind:checked={deleteStorage} label={$LL.virtPoolDeleteStorage()} />
    {/if}
    {#snippet actions()}
      <Button block variant="destructive" disabled={busy} onclick={async () => { const change: VirtChange = { op: 'pool_delete', pool: p.id, delete_storage: deleteStorage }; deletingPool = null; await run(change) }}>{$LL.virtDelete()}</Button>
      <Button block variant="secondary" onclick={() => (deletingPool = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if deletingVolume && pool}
  {@const v = deletingVolume}
  {@const p = pool}
  <Dialog open title={$LL.virtDelete()} message={$LL.virtVolumeDeleteConfirm({ name: v.name })} onclose={() => (deletingVolume = null)}>
    {#snippet icon()}<Icon name="delete" size={52} weight={300} />{/snippet}
    {#snippet actions()}
      <Button block variant="destructive" disabled={busy} onclick={async () => { const change: VirtChange = { op: 'volume_delete', pool: p.id, volume: v.id }; deletingVolume = null; await run(change) }}>{$LL.virtDelete()}</Button>
      <Button block variant="secondary" onclick={() => (deletingVolume = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if resizing && pool}
  {@const v = resizing}
  {@const p = pool}
  <Dialog open wide title={$LL.virtVolumeResize()} onclose={() => (resizing = null)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (resizing = null)}>{$LL.cancel()}</Button>
      <Button variant="primary" type="submit" form="virt-volume-resize" disabled={busy}>{$LL.virtVolumeResize()}</Button>
    {/snippet}
    <form id="virt-volume-resize" class="space-y-[13px]" onsubmit={async (e) => { e.preventDefault(); if (await run({ op: 'volume_resize', pool: p.id, volume: v.id, bytes: (Math.floor(Number(resizeGib)) || 0) * 2 ** 30 })) resizing = null }}>
      <p class="text-[13px] text-(--text-secondary)">{v.name} · {fmtBytes(v.capacity ?? 0)}</p>
      <Input label={$LL.virtVolumeResizeTo()} type="number" min="1" bind:value={resizeGib} />
      {#if error}<p class="text-[12px] text-(--color-danger) whitespace-pre-wrap">{error}</p>{/if}
    </form>
  </Dialog>
{/if}

{#if cloning && pool}
  {@const v = cloning}
  {@const p = pool}
  <Dialog open wide title={$LL.virtVolumeClone()} onclose={() => (cloning = null)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (cloning = null)}>{$LL.cancel()}</Button>
      <Button variant="primary" type="submit" form="virt-volume-clone" disabled={busy || cloneName.trim() === ''}>{$LL.virtVolumeClone()}</Button>
    {/snippet}
    <form id="virt-volume-clone" class="space-y-[13px]" onsubmit={async (e) => { e.preventDefault(); if (await run({ op: 'volume_clone', pool: p.id, volume: v.id, name: cloneName.trim() })) cloning = null }}>
      <p class="text-[13px] text-(--text-secondary)">{v.name}</p>
      <Input label={$LL.virtVolumeCloneName()} class="lk-mono" bind:value={cloneName} />
      {#if error}<p class="text-[12px] text-(--color-danger) whitespace-pre-wrap">{error}</p>{/if}
    </form>
  </Dialog>
{/if}
