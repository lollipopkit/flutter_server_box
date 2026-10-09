<script lang="ts">
  import { DATE_TIME, fmtDate } from '../../../lib/format'
  import { Button, Checkbox, Input, SegmentedControl, Select, Spinner } from '../../lk'
  import { api } from '../../../lib/api'
  import {
    BACKUP_COMPRESSIONS,
    BACKUP_MODES,
    KEEP_KEYS,
    compressText,
    jobEdit,
    storageNames,
    virtErrorText,
    virtRequestText,
    type JobDraft,
    type KeepKey,
  } from '../../../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { VirtBackupJobEdit, VirtPool, VirtScheduleCheck } from '../../../types'

  /// A backup job's editor: the guest's own job (`full` off: when, where,
  /// how, how many kept) or any of the datacenter's (`full`: also its id,
  /// node, guests, notes and mail). Validate asks the host what it makes of
  /// the schedule; whether the job is taken is the agent's answer on save.
  interface Props {
    draft: JobDraft
    storages: VirtPool[]
    /// The cluster's nodes, for a job restricted to one.
    nodes?: string[]
    full?: boolean
    busy: boolean
    onsave: (edit: VirtBackupJobEdit) => void
    oncancel: () => void
  }

  const { draft, storages, nodes = [], full = false, busy, onsave, oncancel }: Props = $props()

  /// The form's own copy: the caller's draft is where it starts.
  let d = $state<JobDraft>(untrack(() => structuredClone($state.snapshot(draft))))
  let checking = $state(false)
  let check = $state<VirtScheduleCheck | null>(null)
  let checkError = $state('')
  /// The schedule the shown check is for; typing another hides it.
  let checkedFor = $state<string | null>(null)

  const names = $derived.by(() => {
    const listed = storageNames(storages, d.node)
    return d.storage === '' || listed.includes(d.storage) ? listed : [d.storage, ...listed]
  })
  const KEEP_LABEL = $derived<Record<KeepKey, string>>({
    'keep-last': $LL.virtBakKeepLast(),
    'keep-hourly': $LL.virtBakKeepHourly(),
    'keep-daily': $LL.virtBakKeepDaily(),
    'keep-weekly': $LL.virtBakKeepWeekly(),
    'keep-monthly': $LL.virtBakKeepMonthly(),
    'keep-yearly': $LL.virtBakKeepYearly(),
  })

  async function validate() {
    const schedule = d.schedule.trim()
    checking = true
    checkError = ''
    check = null
    try {
      const answer = await api.checkBackupSchedule(schedule)
      if (answer.error) checkError = virtErrorText(answer.error)
      else check = answer.check ?? { error: null, next: [] }
      checkedFor = schedule
    } catch (e) {
      checkError = virtRequestText(e)
      checkedFor = schedule
    } finally {
      checking = false
    }
  }

  function submit(e: SubmitEvent) {
    e.preventDefault()
    onsave(jobEdit(d))
  }

  function when(seconds: number): string {
    return fmtDate(seconds * 1000, DATE_TIME)
  }
</script>

{#snippet seg(label: string, items: { value: string; text: string }[], value: string, pick: (v: string) => void)}
  <div class="flex flex-wrap items-center gap-[9px]">
    <span class="text-[12px] text-(--text-secondary)">{label}</span>
    <SegmentedControl size="sm" {value} label={label} options={items.map((it) => ({ value: it.value, label: it.text }))} onchange={pick} />
  </div>
{/snippet}

<form class="space-y-[13px]" onsubmit={submit}>
  {#if full}
    <div class="flex flex-wrap gap-[13px]">
      {#if d.isNew}
        <Input class="min-w-40 flex-1 lk-mono" label="ID" bind:value={d.id} placeholder={$LL.virtBakJobIdAuto()} />
      {/if}
      <Select class="min-w-40 flex-1" label={$LL.virtNode()} bind:value={d.node} options={[{ value: '', label: $LL.virtBakAnyNode() }, ...nodes.map((n) => ({ value: n, label: n }))]} />
    </div>
  {/if}

  <div class="space-y-[9px]">
    <div class="flex flex-wrap items-end gap-[9px]">
      <Input class="min-w-0 flex-1 lk-mono" label={$LL.virtBakSchedule()} bind:value={d.schedule} placeholder="02:00" />
      <Button type="button" variant="secondary" size="sm" icon="event_available" disabled={checking || d.schedule.trim() === ''} onclick={() => void validate()}>{$LL.virtBakValidate()}</Button>
    </div>
    <p class="text-[12px] text-(--text-tertiary)">{$LL.virtBakScheduleHint()}</p>
    {#if checking}
      <Spinner size="sm" />
    {:else if checkedFor !== null && checkedFor === d.schedule.trim()}
      {#if checkError}
        <p class="whitespace-pre-wrap break-all text-[12px] text-(--color-danger)">{checkError}</p>
      {:else if check?.error}
        <p class="whitespace-pre-wrap break-all text-[12px] text-(--color-danger)">{$LL.virtBakScheduleRefused({ why: check.error })}</p>
      {:else if check && check.next.length > 0}
        <div class="text-[12px]">
          <span class="text-(--text-tertiary)">{$LL.virtBakNextRuns()}</span>
          <ul class="lk-mono text-(--text-secondary)">
            {#each check.next.slice(0, 3) as t (t)}
              <li>{when(t)}</li>
            {/each}
          </ul>
        </div>
      {:else if check}
        <p class="text-[12px] text-(--text-secondary)">{$LL.virtBakNoNextRuns()}</p>
      {/if}
    {/if}
  </div>

  <Select label={$LL.virtBakStorage()} class="w-full" bind:value={d.storage} options={[{ value: '', label: $LL.virtBakPickStorage() }, ...names.map((n) => ({ value: n, label: n }))]} />

  {#if full}
    {@render seg(
      $LL.virtBakSelection(),
      [
        { value: 'all', text: $LL.virtBakSelAll() },
        { value: 'vmids', text: 'VMID' },
        { value: 'pool', text: $LL.virtBakPool() },
      ],
      d.selection,
      (v) => (d.selection = v as JobDraft['selection']),
    )}
    {#if d.selection === 'all'}
      <Input label={$LL.virtBakExclude()} mono bind:value={d.exclude} placeholder="101, 102" />
    {:else if d.selection === 'vmids'}
      <Input label="VMID" mono bind:value={d.vmids} placeholder="100, 101" />
    {:else}
      <Input label={$LL.virtBakPool()} mono bind:value={d.pool} />
    {/if}
  {/if}

  {@render seg(
    $LL.virtBakMode(),
    BACKUP_MODES.map((m) => ({ value: m, text: m })),
    d.mode,
    (v) => (d.mode = v as JobDraft['mode']),
  )}
  {@render seg(
    $LL.virtBakCompress(),
    BACKUP_COMPRESSIONS.map((c) => ({ value: c, text: compressText(c) })),
    d.compress,
    (v) => (d.compress = v as JobDraft['compress']),
  )}

  <div class="space-y-[9px]">
    <span class="text-[12px] text-(--text-secondary)">{$LL.virtBakRetention()}</span>
    <div class="grid grid-cols-3 gap-[9px] @2xl:grid-cols-6">
      {#each KEEP_KEYS as k (k)}
        <Input type="number" min="0" label={KEEP_LABEL[k]} bind:value={d.retention.keep[k]} />
      {/each}
    </div>
    <p class="text-[12px] text-(--text-tertiary)">{$LL.virtBakRetentionNote()}</p>
  </div>

  {#if full}
    <Input label={$LL.virtBakNotesTemplate()} mono bind:value={d.notesTemplate} />
    <div class="flex flex-wrap gap-[13px]">
      <Input class="min-w-40 flex-1" label={$LL.virtBakComment()} bind:value={d.comment} />
      <Select class="min-w-40 flex-1" label={$LL.virtBakMail()} bind:value={d.mail} options={[{ value: '', label: $LL.virtHwDefault() }, { value: 'always', label: $LL.virtBakMailAlways() }, { value: 'failure', label: $LL.virtBakMailFailure() }]} />
    </div>
  {/if}

  <Checkbox bind:checked={d.enabled} label={$LL.virtBakEnabled()} />

  <div class="flex justify-end gap-[9px]">
    <Button type="button" variant="secondary" size="sm" icon="close" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button type="submit" size="sm" disabled={busy}>{$LL.save()}</Button>
  </div>
</form>
