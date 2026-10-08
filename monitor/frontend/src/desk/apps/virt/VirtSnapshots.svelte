<script lang="ts">
  import { DATE_TIME, fmtDate } from '../../../lib/format'
  import { Badge, Button, Card, Checkbox, Dialog, Icon, IconButton, Input, Select, Spinner } from '@lollipopkit/desk-ui'
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
    return seconds === null ? '' : fmtDate(seconds * 1000, DATE_TIME)
  }
</script>

<Card class="space-y-[13px]">
  {#if error}
    <p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p>
  {/if}
  {#if loading && !data}
    <Spinner class="w-5 h-5" />
  {/if}

  {#if data && !data.error}
    {#if data.refusal}
      <p class="whitespace-pre-wrap text-[12px] text-(--color-warning)">{$LL.virtSnapRefused({ why: data.refusal })}</p>
    {:else}
      <form class="space-y-[13px]" onsubmit={create}>
        <div class="flex flex-wrap items-end gap-[9px]">
          <Input class="w-48" label={$LL.virtSnapName()} bind:value={name} placeholder={$LL.virtSnapName()} />
          <Input class="min-w-0 flex-1" label={$LL.virtSnapDescription()} bind:value={description} />
          <Button type="submit" size="sm" icon="add" disabled={busy || name.trim() === ''}>{$LL.virtSnapTake()}</Button>
        </div>
        <div class="flex flex-wrap items-center gap-[13px]">
          {#if data.memory === 'optional'}
            <Checkbox bind:checked={memory} label={$LL.virtSnapWithMemory()} />
          {:else if data.memory === 'always' && !external}
            <span class="text-[12px] text-(--text-secondary)">{$LL.virtSnapMemoryAlways()}</span>
          {/if}
          {#if canExternal}
            <Checkbox bind:checked={external} label={$LL.virtSnapExternal()} />
            {#if external && chain && chain.pools.length > 0}
              <Select bind:value={pool} options={[{ value: '', label: $LL.virtSnapPoolOwn() }, ...chain.pools.map((p) => ({ value: p, label: p }))]} />
            {/if}
          {:else if chain?.external_refusal}
            <span class="text-[12px] text-(--text-secondary)">{$LL.virtSnapNoExternal({ why: chain.external_refusal })}</span>
          {/if}
        </div>
      </form>
    {/if}

    {#if tree.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-[27px] text-(--text-tertiary)">
        <Icon name="photo_camera" size={48} weight={300} />
        <p class="text-[13px]">{$LL.virtEmptySnapshots()}</p>
      </div>
    {:else}
      <ul>
        {#each tree as [s, depth] (s.name)}
          <li class="border-t border-(--border-hairline) py-[7px]" style="padding-left: {depth * 1.25}rem">
            <div class="flex flex-wrap items-center gap-[9px]">
              <span class="text-[13px] font-semibold text-(--text-primary)">{s.name}</span>
              {#if s.current}<Badge tone="success" dot>{$LL.virtSnapCurrent()}</Badge>{/if}
              {#if s.with_memory}<Badge>{$LL.virtSnapMemory()}</Badge>{/if}
              {#if s.external}<Badge>{$LL.virtSnapExternalBadge()}</Badge>{/if}
              <span class="text-[12px] text-(--text-tertiary)">{date(s.created_at)}</span>
              <span class="ml-auto flex gap-[5px]">
                <Button variant="secondary" size="sm" icon="compare_arrows" onclick={() => void showDiff(s)}>{$LL.virtSnapDiff()}</Button>
                <Button variant="secondary" size="sm" icon="restart_alt" disabled={busy} onclick={() => { reverting = s; startAfter = false }}>
                  {$LL.virtSnapRevert()}
                </Button>
                <IconButton icon="delete" label={$LL.virtSnapDelete()} disabled={busy} onclick={() => (deleting = s)} />
              </span>
            </div>
            {#if s.description}
              <p class="whitespace-pre-wrap text-[12px] text-(--text-secondary)">{s.description}</p>
            {/if}
            {#if diffFor === s.name}
              {#if diff === null}
                <Spinner size="sm" />
              {:else if diff.length === 0}
                <p class="text-[12px] text-(--text-secondary)">{$LL.virtSnapSame()}</p>
              {:else}
                <dl class="mt-[7px] grid grid-cols-[auto_1fr_1fr] gap-x-[9px] gap-y-[3px] text-[12px]">
                  {#each diff as d (d.key)}
                    <dt class="lk-mono text-(--text-primary)">{d.key}</dt>
                    <dd class="break-all text-(--text-tertiary) line-through">{d.before ?? '—'}</dd>
                    <dd class="break-all text-(--text-secondary)">{d.after ?? '—'}</dd>
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
  <Dialog open title={$LL.virtSnapRevert()} message={s.with_memory ? $LL.virtSnapRevertMemory({ name: s.name }) : $LL.virtSnapRevertDisk({ name: s.name })} onclose={() => (reverting = null)}>
    {#snippet icon()}<Icon name="restart_alt" size={52} weight={300} />{/snippet}
    {#if !s.with_memory}
      <Checkbox bind:checked={startAfter} label={$LL.virtSnapStartAfter()} />
    {/if}
    {#snippet actions()}
      <Button block variant="destructive" disabled={busy} onclick={async () => { const op = { op: 'revert' as const, name: s.name, start: startAfter }; reverting = null; await run(op) }}>{$LL.virtSnapRevert()}</Button>
      <Button block variant="secondary" onclick={() => (reverting = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if deleting}
  {@const s = deleting}
  <Dialog open title={$LL.virtSnapDelete()} message={$LL.virtSnapDeleteConfirm({ name: s.name })} onclose={() => (deleting = null)}>
    {#snippet icon()}<Icon name="delete" size={52} weight={300} />{/snippet}
    {#snippet actions()}
      <Button block variant="destructive" disabled={busy} onclick={async () => { const op = { op: 'delete' as const, name: s.name }; deleting = null; await run(op) }}>{$LL.virtSnapDelete()}</Button>
      <Button block variant="secondary" onclick={() => (deleting = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}
