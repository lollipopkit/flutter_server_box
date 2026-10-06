<script lang="ts">
  import { Button, Input, Select, Spinner } from '@serverbox/webui'
  import { CalendarCheck, X } from '@lucide/svelte'
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
    return new Date(seconds * 1000).toLocaleString()
  }
</script>

{#snippet seg(label: string, items: { value: string; text: string }[], value: string, pick: (v: string) => void)}
  <div class="flex flex-wrap items-center gap-2">
    <span class="w-28 shrink-0 text-sm text-muted-fg">{label}</span>
    <div class="flex flex-wrap gap-1">
      {#each items as it (it.value)}
        <Button type="button" size="sm" variant={it.value === value ? 'primary' : 'secondary'} aria-pressed={it.value === value} onclick={() => pick(it.value)}>{it.text}</Button>
      {/each}
    </div>
  </div>
{/snippet}

<form class="space-y-3" onsubmit={submit}>
  {#if full}
    <div class="flex flex-wrap gap-3">
      {#if d.isNew}
        <label class="block min-w-40 flex-1 space-y-1 text-sm">
          <span class="text-muted-fg">ID</span>
          <Input class="font-mono" bind:value={d.id} placeholder={$LL.virtBakJobIdAuto()} />
        </label>
      {/if}
      <label class="block min-w-40 flex-1 space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtNode()}</span>
        <Select class="w-full" bind:value={d.node}>
          <option value="">{$LL.virtBakAnyNode()}</option>
          {#each nodes as n (n)}
            <option value={n}>{n}</option>
          {/each}
        </Select>
      </label>
    </div>
  {/if}

  <div class="space-y-1">
    <div class="flex flex-wrap items-end gap-2">
      <label class="block min-w-0 flex-1 space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtBakSchedule()}</span>
        <Input class="font-mono" bind:value={d.schedule} placeholder="02:00" />
      </label>
      <Button type="button" variant="secondary" size="sm" disabled={checking || d.schedule.trim() === ''} onclick={() => void validate()}>
        <CalendarCheck class="h-4 w-4" />
        {$LL.virtBakValidate()}
      </Button>
    </div>
    <p class="text-xs text-faint-fg">{$LL.virtBakScheduleHint()}</p>
    {#if checking}
      <Spinner size="sm" />
    {:else if checkedFor !== null && checkedFor === d.schedule.trim()}
      {#if checkError}
        <p class="text-xs text-danger whitespace-pre-wrap break-all">{checkError}</p>
      {:else if check?.error}
        <p class="text-xs text-danger whitespace-pre-wrap break-all">{$LL.virtBakScheduleRefused({ why: check.error })}</p>
      {:else if check && check.next.length > 0}
        <div class="text-xs">
          <span class="text-faint-fg">{$LL.virtBakNextRuns()}</span>
          <ul class="text-muted-fg">
            {#each check.next.slice(0, 3) as t (t)}
              <li class="font-mono">{when(t)}</li>
            {/each}
          </ul>
        </div>
      {:else if check}
        <p class="text-xs text-muted-fg">{$LL.virtBakNoNextRuns()}</p>
      {/if}
    {/if}
  </div>

  <label class="block space-y-1 text-sm">
    <span class="text-muted-fg">{$LL.virtBakStorage()}</span>
    <Select class="w-full" bind:value={d.storage}>
      <option value="" disabled>{$LL.virtBakPickStorage()}</option>
      {#each names as n (n)}
        <option value={n}>{n}</option>
      {/each}
    </Select>
  </label>

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
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtBakExclude()}</span>
        <Input class="font-mono" bind:value={d.exclude} placeholder="101, 102" />
      </label>
    {:else if d.selection === 'vmids'}
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">VMID</span>
        <Input class="font-mono" bind:value={d.vmids} placeholder="100, 101" />
      </label>
    {:else}
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtBakPool()}</span>
        <Input class="font-mono" bind:value={d.pool} />
      </label>
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

  <div class="space-y-1">
    <span class="text-sm text-muted-fg">{$LL.virtBakRetention()}</span>
    <div class="grid grid-cols-3 gap-2 @2xl:grid-cols-6">
      {#each KEEP_KEYS as k (k)}
        <label class="block space-y-1 text-xs">
          <span class="text-faint-fg">{KEEP_LABEL[k]}</span>
          <Input type="number" min="0" bind:value={d.retention.keep[k]} />
        </label>
      {/each}
    </div>
    <p class="text-xs text-faint-fg">{$LL.virtBakRetentionNote()}</p>
  </div>

  {#if full}
    <label class="block space-y-1 text-sm">
      <span class="text-muted-fg">{$LL.virtBakNotesTemplate()}</span>
      <Input class="font-mono" bind:value={d.notesTemplate} />
    </label>
    <div class="flex flex-wrap gap-3">
      <label class="block min-w-40 flex-1 space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtBakComment()}</span>
        <Input bind:value={d.comment} />
      </label>
      <label class="block min-w-40 flex-1 space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtBakMail()}</span>
        <Select class="w-full" bind:value={d.mail}>
          <option value="">{$LL.virtHwDefault()}</option>
          <option value="always">{$LL.virtBakMailAlways()}</option>
          <option value="failure">{$LL.virtBakMailFailure()}</option>
        </Select>
      </label>
    </div>
  {/if}

  <label class="flex items-center gap-1.5 text-sm text-fg"><input type="checkbox" bind:checked={d.enabled} /> {$LL.virtBakEnabled()}</label>

  <div class="flex justify-end gap-2">
    <Button type="button" variant="secondary" size="sm" onclick={oncancel}>
      <X class="h-4 w-4" />
      {$LL.cancel()}
    </Button>
    <Button type="submit" size="sm" disabled={busy}>{$LL.save()}</Button>
  </div>
</form>
