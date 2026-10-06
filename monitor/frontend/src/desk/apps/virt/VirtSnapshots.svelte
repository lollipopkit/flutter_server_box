<script lang="ts">
  import { Badge, Button, Card, Input, Modal, Select, Spinner } from '@serverbox/webui'
  import { Camera, GitCompare, RotateCcw, Trash2 } from '@lucide/svelte'
  import { api } from '../../../lib/api'
  import { snapshotTree, virtErrorText, virtRequestText } from '../../../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { VirtGuest, VirtSnapDiff, VirtSnapshot, VirtSnapshots } from '../../../types'

  /// A guest's snapshots: the tree, a new one, revert, delete, and how one
  /// differs from the guest now. What may be done is the agent's answer
  /// (`refusal`, `memory`, the chain); a refused request says why.
  interface Props {
    guest: VirtGuest
    sudoPassword: string | null
    /// Told after a change, so the page reads the host again.
    onchanged: () => void
  }

  const { guest, sudoPassword, onchanged }: Props = $props()

  let data = $state<VirtSnapshots | null>(null)
  let loading = $state(false)
  let error = $state('')
  let busy = $state(false)
  let name = $state('')
  let description = $state('')
  let memory = $state(true)
  let external = $state(false)
  let pool = $state('')
  let reverting = $state<VirtSnapshot | null>(null)
  let startAfter = $state(false)
  let deleting = $state<VirtSnapshot | null>(null)
  let diffFor = $state<string | null>(null)
  let diff = $state<VirtSnapDiff[] | null>(null)

  /// The guest by its id: every poll hands a new object for the same guest,
  /// which is not a reason to read its snapshots again.
  const guestId = $derived(guest.id)

  $effect(() => {
    void guestId
    untrack(() => void load())
  })

  async function load() {
    loading = true
    error = ''
    try {
      const next = await api.virtSnapshots(guest.id, sudoPassword ?? undefined)
      if (next.error) error = virtErrorText(next.error)
      data = next
    } catch (e) {
      error = virtRequestText(e)
    } finally {
      loading = false
    }
  }

  async function run(op: Parameters<typeof api.virtSnapshot>[1]) {
    busy = true
    error = ''
    try {
      const { error: e } = await api.virtSnapshot(guest.id, op, sudoPassword ?? undefined)
      if (e) {
        error = virtErrorText(e)
        return false
      }
      onchanged()
      await load()
      return true
    } catch (e) {
      error = virtRequestText(e)
      return false
    } finally {
      busy = false
    }
  }

  async function create(e: SubmitEvent) {
    e.preventDefault()
    const ok = await run({
      op: 'create',
      name: name.trim(),
      description: description.trim() || null,
      memory: data?.memory === 'optional' ? memory : data?.memory === 'always',
      external,
      pool: external && pool ? pool : null,
    })
    if (ok) {
      name = ''
      description = ''
    }
  }

  async function showDiff(s: VirtSnapshot) {
    if (diffFor === s.name) {
      diffFor = null
      return
    }
    diffFor = s.name
    diff = null
    try {
      const answer = await api.virtSnapshotDiff(guest.id, s.name, sudoPassword ?? undefined)
      if (answer.error) error = virtErrorText(answer.error)
      else diff = answer.diff
    } catch (e) {
      error = virtRequestText(e)
    }
  }

  const tree = $derived(snapshotTree(data?.snapshots ?? []))
  const chain = $derived(data?.chain ?? null)
  const canExternal = $derived(chain !== null && !chain.external_refusal)

  function date(seconds: number | null): string {
    return seconds === null ? '' : new Date(seconds * 1000).toLocaleString()
  }
</script>

<Card class="space-y-3">
  {#if error}
    <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
  {/if}
  {#if loading && !data}
    <Spinner class="w-5 h-5" />
  {/if}

  {#if data && !data.error}
    {#if data.refusal}
      <p class="text-xs text-warning whitespace-pre-wrap">{$LL.virtSnapRefused({ why: data.refusal })}</p>
    {:else}
      <form class="space-y-2" onsubmit={create}>
        <div class="flex flex-wrap gap-2">
          <Input class="w-48" bind:value={name} placeholder={$LL.virtSnapName()} />
          <Input class="min-w-0 flex-1" bind:value={description} placeholder={$LL.virtSnapDescription()} />
          <Button type="submit" size="sm" disabled={busy || name.trim() === ''}>
            <Camera class="h-4 w-4" />
            {$LL.virtSnapTake()}
          </Button>
        </div>
        <div class="flex flex-wrap items-center gap-4 text-xs text-muted-fg">
          {#if data.memory === 'optional'}
            <label class="flex items-center gap-1.5"><input type="checkbox" bind:checked={memory} /> {$LL.virtSnapWithMemory()}</label>
          {:else if data.memory === 'always' && !external}
            <span>{$LL.virtSnapMemoryAlways()}</span>
          {/if}
          {#if canExternal}
            <label class="flex items-center gap-1.5"><input type="checkbox" bind:checked={external} /> {$LL.virtSnapExternal()}</label>
            {#if external && chain && chain.pools.length > 0}
              <Select bind:value={pool}>
                <option value="">{$LL.virtSnapPoolOwn()}</option>
                {#each chain.pools as p (p)}
                  <option value={p}>{p}</option>
                {/each}
              </Select>
            {/if}
          {:else if chain?.external_refusal}
            <span>{$LL.virtSnapNoExternal({ why: chain.external_refusal })}</span>
          {/if}
        </div>
      </form>
    {/if}

    {#if tree.length === 0}
      <p class="text-sm text-muted-fg">{$LL.virtSnapNone()}</p>
    {:else}
      <ul class="divide-y divide-line">
        {#each tree as [s, depth] (s.name)}
          <li class="py-2" style="padding-left: {depth * 1.25}rem">
            <div class="flex flex-wrap items-center gap-2">
              <span class="text-sm text-fg-strong">{s.name}</span>
              {#if s.current}<Badge tone="success">{$LL.virtSnapCurrent()}</Badge>{/if}
              {#if s.with_memory}<Badge>{$LL.virtSnapMemory()}</Badge>{/if}
              {#if s.external}<Badge>{$LL.virtSnapExternalBadge()}</Badge>{/if}
              <span class="text-xs text-faint-fg">{date(s.created_at)}</span>
              <span class="ml-auto flex gap-1">
                <Button variant="secondary" size="sm" onclick={() => void showDiff(s)}>
                  <GitCompare class="h-4 w-4" />
                  {$LL.virtSnapDiff()}
                </Button>
                <Button variant="secondary" size="sm" disabled={busy} onclick={() => { reverting = s; startAfter = false }}>
                  <RotateCcw class="h-4 w-4" />
                  {$LL.virtSnapRevert()}
                </Button>
                <Button variant="secondary" size="sm" disabled={busy} onclick={() => (deleting = s)}>
                  <Trash2 class="h-4 w-4" />
                </Button>
              </span>
            </div>
            {#if s.description}
              <p class="text-xs text-muted-fg whitespace-pre-wrap">{s.description}</p>
            {/if}
            {#if diffFor === s.name}
              {#if diff === null}
                <Spinner size="sm" />
              {:else if diff.length === 0}
                <p class="text-xs text-muted-fg">{$LL.virtSnapSame()}</p>
              {:else}
                <dl class="mt-1 grid grid-cols-[auto_1fr_1fr] gap-x-3 gap-y-0.5 text-xs">
                  {#each diff as d (d.key)}
                    <dt class="font-mono text-fg">{d.key}</dt>
                    <dd class="break-all text-faint-fg line-through">{d.before ?? '—'}</dd>
                    <dd class="break-all text-muted-fg">{d.after ?? '—'}</dd>
                  {/each}
                </dl>
              {/if}
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  {/if}
</Card>

{#if reverting}
  {@const s = reverting}
  <Modal open title={$LL.virtSnapRevert()} onclose={() => (reverting = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{s.with_memory ? $LL.virtSnapRevertMemory({ name: s.name }) : $LL.virtSnapRevertDisk({ name: s.name })}</p>
      {#if !s.with_memory}
        <label class="flex items-center gap-1.5 text-sm text-muted-fg"><input type="checkbox" bind:checked={startAfter} /> {$LL.virtSnapStartAfter()}</label>
      {/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (reverting = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy} onclick={async () => { const op = { op: 'revert' as const, name: s.name, start: startAfter }; reverting = null; await run(op) }}>{$LL.virtSnapRevert()}</Button>
      </div>
    </div>
  </Modal>
{/if}

{#if deleting}
  {@const s = deleting}
  <Modal open title={$LL.virtSnapDelete()} onclose={() => (deleting = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.virtSnapDeleteConfirm({ name: s.name })}</p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (deleting = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy} onclick={async () => { const op = { op: 'delete' as const, name: s.name }; deleting = null; await run(op) }}>{$LL.virtSnapDelete()}</Button>
      </div>
    </div>
  </Modal>
{/if}
