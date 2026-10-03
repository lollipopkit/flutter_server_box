<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Select, Spinner } from '@serverbox/webui'
  import { Copy, Expand, Play, Plus, RefreshCw, Square, Trash2 } from '@lucide/svelte'
  import { api } from '../lib/api'
  import { fmtBytes } from '../lib/format'
  import { refText, virtErrorText, virtRequestText } from '../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { VirtChange, VirtHostView, VirtPool, VirtPoolRule, VirtVolume } from '../types'

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
  <Card class="border-danger/40 bg-danger/5">
    <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
  </Card>
{/if}

<div class="grid gap-4 lg:grid-cols-[minmax(16rem,20rem)_1fr]">
  <section class="space-y-3">
    <div class="flex items-center gap-2">
      {#if editable && poolTypes.length > 0}
        <Button size="sm" onclick={openPoolForm}><Plus class="h-4 w-4" />{$LL.virtPoolCreate()}</Button>
      {/if}
      <IconButton class="ml-auto" label={$LL.refresh()} disabled={loading} onclick={() => void loadPools()}>
        <RefreshCw class="h-4 w-4" />
      </IconButton>
    </div>
    {#if pools === null}
      <Card><Spinner class="h-5 w-5" /></Card>
    {:else if pools.length === 0}
      <Card><p class="text-sm text-muted-fg">{$LL.virtPoolNone()}</p></Card>
    {:else}
      <Card class="p-1">
        <ul>
          {#each pools as p (p.id)}
            {@const frac = usage(p)}
            <li>
              <button
                class="w-full rounded-lg px-3 py-2 text-left transition-colors {p.id === selected ? 'bg-primary/10' : 'hover:bg-muted'}"
                aria-current={p.id === selected ? 'true' : undefined}
                onclick={() => (selected = p.id)}
              >
                <div class="flex items-center gap-2">
                  <span class="h-2 w-2 shrink-0 rounded-full {p.active ? 'bg-success' : 'bg-faint-fg'}"></span>
                  <span class="truncate text-sm text-fg-strong">{p.name}</span>
                  <span class="ml-auto shrink-0 font-mono text-xs text-faint-fg">{p.type}{p.node && view.host.nodes.length > 1 ? ` · ${p.node}` : ''}</span>
                </div>
                {#if frac !== null}
                  <div class="mt-1 h-0.5 overflow-hidden rounded bg-line">
                    <div class="h-full {frac > 0.9 ? 'bg-danger' : 'bg-primary'}" style="width: {frac * 100}%"></div>
                  </div>
                  <p class="pl-0 text-xs text-muted-fg">{fmtBytes(p.used ?? 0)} / {fmtBytes(p.capacity ?? 0)}</p>
                {/if}
              </button>
            </li>
          {/each}
        </ul>
      </Card>
    {/if}
  </section>

  <section class="min-w-0 space-y-4">
    {#if pool}
      {@const p = pool}
      <Card class="space-y-3">
        <div class="flex flex-wrap items-center gap-2">
          <h3 class="text-base font-medium text-fg-strong">{p.name}</h3>
          {#if !p.active}<Badge>{$LL.virtPoolInactive()}</Badge>{/if}
          {#if p.enabled === false}<Badge tone="warning">{$LL.virtPoolDisabled()}</Badge>{/if}
          {#if p.shared}<Badge>{$LL.virtPoolShared()}</Badge>{/if}
          {#if p.autostart}<Badge>{$LL.virtPoolAutostart()}</Badge>{/if}
          {#if editable}
            <span class="ml-auto flex flex-wrap gap-1">
              {#if pve}
                <Button variant="secondary" size="sm" disabled={busy} onclick={() => void run({ op: 'pool_set_active', pool: p.id, active: p.enabled === false })}>
                  {p.enabled === false ? $LL.virtPoolEnable() : $LL.virtPoolDisable()}
                </Button>
              {:else}
                <Button variant="secondary" size="sm" disabled={busy} onclick={() => void run({ op: 'pool_set_active', pool: p.id, active: !p.active })}>
                  {#if p.active}<Square class="h-4 w-4" />{$LL.virtPoolStop()}{:else}<Play class="h-4 w-4" />{$LL.virtPoolStart()}{/if}
                </Button>
                {#if caps.pool_autostart}
                  <label class="flex items-center gap-1.5 px-2 text-xs text-muted-fg">
                    <input type="checkbox" checked={p.autostart === true} disabled={busy} onchange={(e) => void run({ op: 'pool_set_autostart', pool: p.id, on: e.currentTarget.checked })} />
                    {$LL.virtPoolAutostart()}
                  </label>
                {/if}
                {#if p.active}
                  <Button variant="secondary" size="sm" disabled={busy} onclick={() => void run({ op: 'pool_refresh', pool: p.id })}>
                    <RefreshCw class="h-4 w-4" />{$LL.virtPoolRefresh()}
                  </Button>
                {/if}
              {/if}
              <Button variant="secondary" size="sm" disabled={busy} onclick={() => { deletingPool = p; deleteStorage = false }}>
                <Trash2 class="h-4 w-4" />
              </Button>
            </span>
          {/if}
        </div>
        <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-xs">
          <dt class="text-faint-fg">{$LL.virtPoolType()}</dt>
          <dd class="font-mono text-muted-fg">{p.type}</dd>
          {#if p.path}
            <dt class="text-faint-fg">{$LL.virtPoolPath()}</dt>
            <dd class="break-all font-mono text-muted-fg">{p.path}</dd>
          {/if}
          {#if p.source}
            <dt class="text-faint-fg">{$LL.virtPoolSource()}</dt>
            <dd class="break-all font-mono text-muted-fg">{p.source}</dd>
          {/if}
          {#if p.content.length > 0}
            <dt class="text-faint-fg">{$LL.virtPoolContent()}</dt>
            <dd class="text-muted-fg">{p.content.join(', ')}</dd>
          {/if}
          {#if p.available !== null}
            <dt class="text-faint-fg">{$LL.virtPoolFree()}</dt>
            <dd class="text-muted-fg">{fmtBytes(p.available)}</dd>
          {/if}
        </dl>
      </Card>

      <Card class="space-y-2">
        {#if editable && p.active}
          <Button size="sm" disabled={busy} onclick={openVolumeForm}><Plus class="h-4 w-4" />{$LL.virtVolumeCreate()}</Button>
        {/if}
        {#if volumes === null}
          <Spinner class="h-5 w-5" />
        {:else if volumes.length === 0}
          <p class="text-sm text-muted-fg">{$LL.virtVolumeNone()}</p>
        {:else}
          <ul class="divide-y divide-line">
            {#each volumes as v (v.id)}
              <li class="flex flex-wrap items-center gap-2 py-2">
                <div class="min-w-0 flex-1">
                  <p class="break-all text-sm text-fg-strong">{v.name}</p>
                  <p class="text-xs text-muted-fg">
                    {[v.format, v.content, v.capacity !== null ? fmtBytes(v.capacity) : null, v.allocation !== null ? $LL.virtVolumeOnDisk({ size: fmtBytes(v.allocation) }) : null]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                  {#if v.users.length > 0}
                    <p class="text-xs text-faint-fg">{$LL.virtVolumeUsedBy({ who: v.users.map((u) => refText(u, view.guests)).join(', ') })}</p>
                  {/if}
                  {#if v.backs.length > 0}
                    <p class="text-xs text-faint-fg" title={v.backs.join('\n')}>{$LL.virtVolumeBacks({ count: v.backs.length })}</p>
                  {/if}
                </div>
                {#if editable}
                  <span class="flex gap-1">
                    {#if rule?.resizable && caps.volume_resize}
                      <Button variant="secondary" size="sm" disabled={busy} onclick={() => { resizing = v; resizeGib = String(Math.ceil((v.capacity ?? 0) / 2 ** 30) + 1) }}>
                        <Expand class="h-4 w-4" />{$LL.virtVolumeResize()}
                      </Button>
                    {/if}
                    {#if caps.volume_clone}
                      <Button variant="secondary" size="sm" disabled={busy} onclick={() => { cloning = v; cloneName = '' }}>
                        <Copy class="h-4 w-4" />{$LL.virtVolumeClone()}
                      </Button>
                    {/if}
                    <Button variant="secondary" size="sm" disabled={busy} onclick={() => (deletingVolume = v)}>
                      <Trash2 class="h-4 w-4" />
                    </Button>
                  </span>
                {/if}
              </li>
            {/each}
          </ul>
        {/if}
      </Card>
    {:else if pools && pools.length > 0}
      <Card><p class="text-sm text-muted-fg">{$LL.virtPoolPick()}</p></Card>
    {/if}
  </section>
</div>

{#if creatingPool}
  <Modal open title={$LL.virtPoolCreate()} onclose={() => (creatingPool = false)}>
    <form class="space-y-3" onsubmit={createPool}>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtPoolName()}</span>
        <Input bind:value={poolForm.name} />
      </label>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtPoolType()}</span>
        <Select bind:value={poolForm.type}>
          {#each poolTypes as t (t)}
            <option value={t}>{t}</option>
          {/each}
        </Select>
      </label>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtPoolSource()}</span>
        <Input class="font-mono" bind:value={poolForm.source} placeholder={SOURCE_HINT[poolForm.type] ?? ''} />
      </label>
      {#if poolForm.type === 'netfs'}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtPoolTarget()}</span>
          <Input class="font-mono" bind:value={poolForm.target} placeholder="/mnt/vm" />
        </label>
      {/if}
      {#if pve && view.host.nodes.length > 1}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtPoolNode()}</span>
          <Select bind:value={poolForm.node}>
            {#each view.host.nodes as n (n.name)}
              <option value={n.name}>{n.name}</option>
            {/each}
          </Select>
        </label>
      {/if}
      {#if error}<p class="text-xs text-danger whitespace-pre-wrap">{error}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (creatingPool = false)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy || poolForm.name.trim() === ''}>{$LL.virtCreate()}</Button>
      </div>
    </form>
  </Modal>
{/if}

{#if creatingVolume && pool}
  <Modal open title={$LL.virtVolumeCreate()} onclose={() => (creatingVolume = false)}>
    <form class="space-y-3" onsubmit={createVolume}>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtVolumeName()}</span>
        <Input class="font-mono" bind:value={volumeForm.name} placeholder={pve ? 'vm-100-disk-1' : 'data.qcow2'} />
      </label>
      <div class="flex gap-3">
        <label class="block flex-1 space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtVolumeSize()}</span>
          <Input type="number" min="1" bind:value={volumeForm.gib} />
        </label>
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtVolumeFormat()}</span>
          <Select bind:value={volumeForm.format}>
            {#each rule?.formats ?? ['raw'] as f (f)}
              <option value={f}>{f}</option>
            {/each}
          </Select>
        </label>
      </div>
      {#if error}<p class="text-xs text-danger whitespace-pre-wrap">{error}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (creatingVolume = false)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy || volumeForm.name.trim() === ''}>{$LL.virtCreate()}</Button>
      </div>
    </form>
  </Modal>
{/if}

{#if deletingPool}
  {@const p = deletingPool}
  <Modal open title={$LL.virtPoolDelete()} onclose={() => (deletingPool = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.virtPoolDeleteConfirm({ name: p.name })}</p>
      {#if caps.pool_delete_storage && !pve}
        <label class="flex items-center gap-1.5 text-sm text-muted-fg"><input type="checkbox" bind:checked={deleteStorage} /> {$LL.virtPoolDeleteStorage()}</label>
      {/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (deletingPool = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy} onclick={async () => { const change: VirtChange = { op: 'pool_delete', pool: p.id, delete_storage: deleteStorage }; deletingPool = null; await run(change) }}>{$LL.virtDelete()}</Button>
      </div>
    </div>
  </Modal>
{/if}

{#if deletingVolume && pool}
  {@const v = deletingVolume}
  {@const p = pool}
  <Modal open title={$LL.virtDelete()} onclose={() => (deletingVolume = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.virtVolumeDeleteConfirm({ name: v.name })}</p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (deletingVolume = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy} onclick={async () => { const change: VirtChange = { op: 'volume_delete', pool: p.id, volume: v.id }; deletingVolume = null; await run(change) }}>{$LL.virtDelete()}</Button>
      </div>
    </div>
  </Modal>
{/if}

{#if resizing && pool}
  {@const v = resizing}
  {@const p = pool}
  <Modal open title={$LL.virtVolumeResize()} onclose={() => (resizing = null)}>
    <form class="space-y-3" onsubmit={async (e) => { e.preventDefault(); if (await run({ op: 'volume_resize', pool: p.id, volume: v.id, bytes: (Math.floor(Number(resizeGib)) || 0) * 2 ** 30 })) resizing = null }}>
      <p class="text-sm text-muted-fg">{v.name} · {fmtBytes(v.capacity ?? 0)}</p>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtVolumeResizeTo()}</span>
        <Input type="number" min="1" bind:value={resizeGib} />
      </label>
      {#if error}<p class="text-xs text-danger whitespace-pre-wrap">{error}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (resizing = null)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy}>{$LL.virtVolumeResize()}</Button>
      </div>
    </form>
  </Modal>
{/if}

{#if cloning && pool}
  {@const v = cloning}
  {@const p = pool}
  <Modal open title={$LL.virtVolumeClone()} onclose={() => (cloning = null)}>
    <form class="space-y-3" onsubmit={async (e) => { e.preventDefault(); if (await run({ op: 'volume_clone', pool: p.id, volume: v.id, name: cloneName.trim() })) cloning = null }}>
      <p class="text-sm text-muted-fg">{v.name}</p>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtVolumeCloneName()}</span>
        <Input class="font-mono" bind:value={cloneName} />
      </label>
      {#if error}<p class="text-xs text-danger whitespace-pre-wrap">{error}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (cloning = null)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy || cloneName.trim() === ''}>{$LL.virtVolumeClone()}</Button>
      </div>
    </form>
  </Modal>
{/if}
