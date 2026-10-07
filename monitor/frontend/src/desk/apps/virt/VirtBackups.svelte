<script lang="ts">
  import { Badge, Button, Card, Checkbox, Icon, Input, Select, SegmentedControl, Spinner } from '../../lk/index'
  import VirtBackupJobForm from './VirtBackupJobForm.svelte'
  import { api } from '../../../lib/api'
  import { fmtBytes } from '../../../lib/format'
  import {
    BACKUP_COMPRESSIONS,
    BACKUP_MODES,
    compressText,
    jobEdit,
    modeText,
    newestFirst,
    ownJob,
    ownJobDraft,
    pruneText,
    selectionText,
    storageNames,
    virtErrorText,
    virtRequestText,
    type JobDraft,
  } from '../../../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type {
    VirtBackup,
    VirtBackupCompress,
    VirtBackupJobEdit,
    VirtBackupMode,
    VirtBackupRequest,
    VirtBackups,
    VirtError,
    VirtGuest,
    VirtHostView,
    VirtPool,
  } from '../../../types'

  /// A guest's backups (PVE): the jobs that take it, with an editor for its
  /// own job (the one that takes it alone), one taken now, and each backup's
  /// notes, protection, deletion and restore. What may be done is the
  /// agent's answer (`sbm_virt::backup`'s rules), said after it is sent.
  interface Props {
    view: VirtHostView
    guest: VirtGuest
    /// Told after a change the guest list shows (a restore), so the page
    /// reads the host again.
    onchanged: () => void
    /// Opens the datacenter's backup jobs.
    onjobs?: () => void
  }

  const { view, guest, onchanged, onjobs }: Props = $props()

  let data = $state<VirtBackups | null>(null)
  let readError = $state('')
  let error = $state('')
  let notice = $state('')
  /// What is running, the buttons closed until it ends: a backup or a
  /// restore can take minutes.
  let busy = $state<'backup' | 'restore' | 'save' | null>(null)
  /// The job editor's draft; null while closed.
  let plan = $state<JobDraft | null>(null)
  /// Which two-click action is armed: `plan`, `delete:<id>`, `restore:<id>`.
  let confirm = $state<string | null>(null)
  let open = $state<Record<string, boolean>>({})
  // Back up now.
  let taking = $state(false)
  let take = $state<{ storage: string; mode: VirtBackupMode; compress: VirtBackupCompress; notes: string; protected: boolean }>({
    storage: '',
    mode: 'snapshot',
    compress: 'zstd',
    notes: '',
    protected: false,
  })
  // Each backup's own fields and restore target, by id.
  let edits = $state<Record<string, { notes: string; protected: boolean }>>({})
  let restores = $state<Record<string, { asNew: boolean; vmid: string; storage: string }>>({})
  /// Where restored disks may land: the guest's node's storages that hold
  /// its kind of disk. Read when a restore form first opens.
  let diskStorages = $state<VirtPool[] | null>(null)

  const stopped = $derived(guest.state === 'stopped')
  const vmid = $derived(guest.vmid)
  const backups = $derived(newestFirst(data?.backups ?? []))
  const jobs = $derived(data?.jobs ?? [])
  const own = $derived(ownJob(jobs, vmid))
  const storages = $derived(data?.storages ?? [])
  const names = $derived(storageNames(storages, ''))

  /// The page hands a new guest object on every read of the host; only
  /// another guest starts the pane over.
  const guestId = $derived(guest.id)

  $effect(() => {
    void guestId
    untrack(() => {
      data = null
      plan = null
      confirm = null
      open = {}
      edits = {}
      restores = {}
      taking = false
      error = ''
      notice = ''
      diskStorages = null
      void load()
    })
  })

  async function load() {
    const id = guest.id
    try {
      const next = await api.virtBackups(id)
      if (guest.id !== id) return
      readError = next.error ? virtErrorText(next.error) : ''
      data = next
      if (take.storage === '' || !storageNames(next.storages ?? [], '').includes(take.storage)) {
        take.storage = storageNames(next.storages ?? [], '')[0] ?? ''
      }
    } catch (e) {
      if (guest.id === id) readError = virtRequestText(e)
    }
  }

  /// Sends one request with the pane closed to others; the listing is read
  /// again after it, whatever the host said.
  async function run(kind: NonNullable<typeof busy>, send: () => Promise<{ error: VirtError | null }>, done: string): Promise<boolean> {
    const id = guest.id
    busy = kind
    error = ''
    notice = ''
    try {
      const { error: err } = await send()
      if (guest.id !== id) return false
      if (err) {
        error = virtErrorText(err)
        return false
      }
      notice = done
      return true
    } catch (e) {
      if (guest.id === id) error = virtRequestText(e)
      return false
    } finally {
      busy = null
      if (guest.id === id) await load()
    }
  }

  async function backUp(e: SubmitEvent) {
    e.preventDefault()
    const g = guest
    const request: VirtBackupRequest = { storage: take.storage, mode: take.mode, compress: take.compress, protected: take.protected }
    if (take.notes.trim()) request.notes = take.notes.trim()
    if (await run('backup', () => api.virtBackup(g.id, request), $LL.virtBakTaken({ name: g.name }))) {
      taking = false
      take.notes = ''
      take.protected = false
    }
  }

  async function savePlan(edit: VirtBackupJobEdit) {
    if (await run('save', () => api.editBackupJob(edit), $LL.virtBakPlanSaved())) plan = null
  }

  async function removePlan() {
    const job = own
    if (!job || vmid === null) return
    if (confirm !== 'plan') {
      confirm = 'plan'
      return
    }
    // What is asked, before the confirmation that asked it goes.
    const edit = jobEdit(ownJobDraft(job, vmid))
    confirm = null
    await run('save', () => api.editBackupJob(edit, true), $LL.virtBakPlanRemoved())
  }

  function toggle(b: VirtBackup) {
    const now = !open[b.id]
    open[b.id] = now
    if (now) {
      edits[b.id] ??= { notes: b.notes ?? '', protected: b.protected }
      restores[b.id] ??= { asNew: !stopped, vmid: '', storage: '' }
      if (diskStorages === null) void readDiskStorages()
    }
  }

  async function readDiskStorages() {
    const id = guest.id
    try {
      const answer = await api.virtStorage()
      if (guest.id !== id) return
      const content = guest.kind === 'lxc' ? 'rootdir' : 'images'
      diskStorages = (answer.pools ?? []).filter((p) => p.content.includes(content) && (p.node === null || p.node === guest.node))
    } catch {
      // The picker keeps the backup's own storage; the restore still works.
      if (guest.id === id) diskStorages = []
    }
  }

  async function saveEdit(b: VirtBackup) {
    const g = guest
    const edit = { ...edits[b.id] }
    await run('save', () => api.virtEditBackup(g.id, b.id, edit), $LL.virtBakEdited())
  }

  async function remove(b: VirtBackup) {
    const key = `delete:${b.id}`
    if (confirm !== key) {
      confirm = key
      return
    }
    const g = guest
    const id = b.id
    confirm = null
    await run('save', () => api.virtDeleteBackup(g.id, id), $LL.virtBakDeleted())
  }

  async function restore(b: VirtBackup) {
    const r = restores[b.id]
    if (!r) return
    const key = `restore:${b.id}`
    // Over the guest overwrites it: asked twice. As a new guest is not.
    if (!r.asNew && confirm !== key) {
      confirm = key
      return
    }
    const g = guest
    const id = b.id
    const target: { vmid?: number; storage?: string } = {}
    if (r.asNew && String(r.vmid).trim() !== '') target.vmid = Math.floor(Number(r.vmid))
    if (r.storage) target.storage = r.storage
    const asNew = r.asNew
    confirm = null
    const ok = await run('restore', () => api.virtRestoreBackup(g.id, id, target), asNew ? $LL.virtBakRestoredNew() : $LL.virtBakRestored({ name: g.name }))
    if (ok) onchanged()
  }

  function when(seconds: number | null): string {
    return seconds === null ? '—' : new Date(seconds * 1000).toLocaleString()
  }

  function summary(b: VirtBackup): string {
    return [b.size !== null ? fmtBytes(b.size) : null, b.format, b.storage].filter(Boolean).join(' · ')
  }
</script>

{#snippet head(title: string, right: string = '')}
  <div class="flex items-center gap-[9px]">
    <h3 class="text-[15px] font-semibold">{title}</h3>
    {#if right}
      <span class="lk-num ml-auto truncate text-[12px] text-(--text-tertiary)">{right}</span>
    {/if}
  </div>
{/snippet}

{#snippet field(label: string, value: string, mono: boolean = false)}
  <div class="min-w-0">
    <dt class="text-[12px] text-(--text-tertiary)">{label}</dt>
    <dd class="break-all text-[12px] text-(--text-secondary) {mono ? 'lk-mono' : ''}">{value}</dd>
  </div>
{/snippet}

{#if error}
  <Card>
    <p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p>
  </Card>
{/if}
{#if notice}
  <Card>
    <p class="whitespace-pre-wrap text-[13px] text-(--text-secondary)">{notice}</p>
  </Card>
{/if}

{#if readError}
  <Card><p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{readError}</p></Card>
{:else if !data}
  <Card><Spinner class="h-5 w-5" /></Card>
{:else}
  <!-- Plan: the jobs that take this guest. -->
  <Card class="space-y-[13px]">
    <div class="flex items-center gap-[9px]">
      <h3 class="text-[15px] font-semibold">{$LL.virtBakPlan()}</h3>
      {#if onjobs && view.capabilities.backup_jobs === true}
        <Button type="button" variant="ghost" size="sm" class="ml-auto" iconRight="chevron_right" onclick={onjobs}>{$LL.virtBakDatacenter()}</Button>
      {/if}
    </div>

    {#if jobs.length === 0 && !plan}
      <p class="text-[13px] text-(--text-secondary)">{$LL.virtBakNoPlan()}</p>
    {/if}

    {#each jobs as job (job.id)}
      {@const mine = job.id === own?.id}
      <Card variant="raised" class="space-y-[9px]">
        <div class="flex flex-wrap items-center gap-[9px]">
          <span class="lk-mono text-[13px] font-semibold">{job.id}</span>
          {#if !job.enabled}<Badge>{$LL.virtBakDisabled()}</Badge>{/if}
          {#if !mine}<span class="text-[12px] text-(--text-tertiary)">{selectionText(job)}</span>{/if}
        </div>
        <dl class="grid grid-cols-2 gap-x-[13px] gap-y-[9px] text-[12px] @2xl:grid-cols-4">
          {@render field($LL.virtBakSchedule(), job.schedule ?? '—', true)}
          {@render field($LL.virtBakStorage(), job.storage ?? '—')}
          {@render field($LL.virtBakRetention(), pruneText(job.prune))}
          {@render field($LL.virtBakMode(), modeText(job.mode, job.compress))}
        </dl>
        {#if mine && vmid !== null}
          {#if plan && !plan.isNew}
            <VirtBackupJobForm draft={plan} {storages} busy={busy !== null} onsave={(e) => void savePlan(e)} oncancel={() => (plan = null)} />
          {:else}
            {#if confirm === 'plan'}
              <p class="text-[12px] text-(--color-danger)">{$LL.virtConfirmAgain()}</p>
            {/if}
            <div class="flex justify-end gap-[5px]">
              {#if confirm === 'plan'}
                <Button variant="secondary" size="sm" onclick={() => (confirm = null)} icon="close">{$LL.cancel()}</Button>
              {/if}
              <Button variant="destructive" size="sm" disabled={busy !== null} onclick={() => void removePlan()} icon="delete">
                {confirm === 'plan' ? $LL.virtBakConfirmRemovePlan({ id: job.id }) : $LL.virtBakRemovePlan()}
              </Button>
              <Button size="sm" disabled={busy !== null} onclick={() => { confirm = null; plan = ownJobDraft(job, vmid) }} icon="edit">
                {$LL.virtBakEditPlan()}
              </Button>
            </div>
          {/if}
        {:else}
          <p class="text-[12px] text-(--text-tertiary)">{$LL.virtBakSharedJob()}</p>
        {/if}
      </Card>
    {/each}

    {#if vmid !== null && !own}
      {#if plan?.isNew}
        <Card variant="raised">
          <VirtBackupJobForm draft={plan} {storages} busy={busy !== null} onsave={(e) => void savePlan(e)} oncancel={() => (plan = null)} />
        </Card>
      {:else}
        <div class="flex justify-end">
          <Button variant="secondary" size="sm" disabled={busy !== null} onclick={() => (plan = ownJobDraft(null, vmid, names[0] ?? ''))} icon="add">
            {$LL.virtBakAddPlan()}
          </Button>
        </div>
      {/if}
    {/if}
  </Card>

  <!-- Backups: one taken now, then each, newest first. -->
  <Card class="space-y-[9px]">
    {@render head($LL.virtBakList(), backups.length ? String(backups.length) : '')}

    {#if busy === 'backup' || busy === 'restore'}
      <Card padding="11px 13px" class="flex items-center gap-[9px] text-[13px] text-(--text-secondary)">
        <Spinner size="sm" />
        {busy === 'backup' ? $LL.virtBakRunning() : $LL.virtBakRestoring()}
      </Card>
    {/if}

    {#if taking}
      <Card variant="raised" class="space-y-[13px]">
        <form class="space-y-[13px]" onsubmit={backUp}>
          <Select label={$LL.virtBakStorage()} class="w-full" bind:value={take.storage} options={names.map((n) => ({ value: n, label: n }))} />
          <div class="flex flex-wrap items-center gap-[9px]">
            <span class="text-[12px] text-(--text-secondary)">{$LL.virtBakMode()}</span>
            <SegmentedControl size="sm" label={$LL.virtBakMode()} value={take.mode} options={BACKUP_MODES.map((m) => ({ value: m, label: m }))} onchange={(mode) => (take.mode = mode as VirtBackupMode)} />
          </div>
          <div class="flex flex-wrap items-center gap-[9px]">
            <span class="text-[12px] text-(--text-secondary)">{$LL.virtBakCompress()}</span>
            <SegmentedControl size="sm" label={$LL.virtBakCompress()} value={take.compress} options={BACKUP_COMPRESSIONS.map((c) => ({ value: c, label: compressText(c) }))} onchange={(compress) => (take.compress = compress as VirtBackupCompress)} />
          </div>
          <Input label={$LL.virtBakNotes()} bind:value={take.notes} placeholder={$LL.virtBakOptional()} />
          <Checkbox bind:checked={take.protected} label={$LL.virtBakProtected()} />
          <div class="flex justify-end gap-[9px]">
            <Button type="button" variant="secondary" size="sm" icon="close" onclick={() => (taking = false)}>{$LL.cancel()}</Button>
            <Button type="submit" size="sm" icon="backup" disabled={busy !== null || take.storage === ''}>{$LL.virtBakStart()}</Button>
          </div>
        </form>
      </Card>
    {:else}
      <div class="flex flex-col items-center gap-[9px] py-[17px] text-center">
        <p class="text-[12px] text-(--text-secondary)">{$LL.virtBakNowNote()}</p>
        <Button size="sm" icon="backup" disabled={busy !== null || names.length === 0} onclick={() => (taking = true)}>
          {$LL.virtBakNow()}
        </Button>
        {#if names.length === 0}
          <p class="text-[12px] text-(--color-warning)">{$LL.virtBakNoStorage()}</p>
        {/if}
      </div>
    {/if}

    {#if backups.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-[17px] text-(--text-tertiary)">
        <Icon name="backup" size={48} weight={300} />
        <p class="text-[13px]">{$LL.virtEmptyBackups()}</p>
      </div>
    {/if}
    {#each backups as b (b.id)}
      {@const ed = edits[b.id]}
      {@const r = restores[b.id]}
      <Card variant="raised" padding="0">
        <button type="button" class="flex w-full items-center gap-[9px] rounded-[13px] px-[13px] py-[9px] text-left" aria-expanded={!!open[b.id]} onclick={() => toggle(b)}>
          <span class="text-[13px] font-semibold text-(--text-primary)">{when(b.created_at)}</span>
          <span class="min-w-0 flex-1 truncate text-[12px] text-(--text-secondary)">{summary(b)}</span>
          {#if b.protected}<Icon name="lock" size={16} title={$LL.virtBakProtected()} />{/if}
          {#if b.verification === 'ok'}
            <Badge tone="success" dot>{$LL.virtBakVerified()}</Badge>
          {:else if b.verification === 'failed'}
            <Badge tone="danger" dot>{$LL.virtBakVerifyFailed()}</Badge>
          {/if}
          <Icon name={open[b.id] ? 'expand_less' : 'expand_more'} size={18} />
        </button>
        {#if open[b.id] && ed && r}
          <div class="space-y-[13px] border-t border-(--border-hairline) p-[13px]">
            <dl class="grid grid-cols-[auto_1fr] gap-x-[9px] gap-y-[5px] text-[12px]">
              <dt class="text-(--text-tertiary)">{$LL.virtBakFile()}</dt>
              <dd class="break-all lk-mono text-(--text-secondary)">{b.id}</dd>
            </dl>

            <!-- Its own fields. -->
            <Input label={$LL.virtBakNotes()} bind:value={ed.notes} />
            <div class="flex flex-wrap items-start justify-between gap-[9px]">
              <div>
                <p class="text-[13px]">{$LL.virtBakProtected()}</p>
                <p class="text-[12px] text-(--text-tertiary)">{$LL.virtBakProtectedNote()}</p>
              </div>
              <Checkbox bind:checked={ed.protected} label={$LL.virtBakProtected()} />
            </div>
            <div class="flex justify-end">
              <Button size="sm" disabled={busy !== null || (ed.notes === (b.notes ?? '') && ed.protected === b.protected)} onclick={() => void saveEdit(b)}>{$LL.save()}</Button>
            </div>

            <!-- Restore. -->
            <div class="space-y-[9px] border-t border-(--border-hairline) pt-[13px]">
              <SegmentedControl
                size="sm"
                label={$LL.virtBakRestore()}
                value={r.asNew ? 'new' : 'over'}
                options={[{ value: 'over', label: $LL.virtBakOverGuest() }, { value: 'new', label: $LL.virtBakAsNew() }]}
                onchange={(value) => { r.asNew = value === 'new'; confirm = null }}
              />
              <div class="flex flex-wrap gap-[13px]">
                {#if r.asNew}
                  <Input class="w-36" label="VMID" type="number" min="100" bind:value={r.vmid} placeholder={$LL.virtVmidNext()} />
                {/if}
                <Select class="min-w-40 flex-1" label={$LL.virtBakRestoreStorage()} bind:value={r.storage} options={[{ value: '', label: $LL.virtBakRestoreStorageOwn() }, ...(diskStorages ?? []).map((p) => ({ value: p.name, label: `${p.name} · ${p.type}` }))]} />
              </div>
              {#if !r.asNew}
                <p class="text-[12px] text-(--color-warning)">{$LL.virtBakOverwrites()}</p>
                {#if !stopped}
                  <p class="text-[12px] text-(--text-secondary)">{$LL.virtStopFirst()}</p>
                {/if}
              {/if}
              {#if confirm === `restore:${b.id}`}
                <p class="text-[12px] text-(--color-danger)">{$LL.virtConfirmAgain()}</p>
              {/if}
              <div class="flex justify-end gap-[9px]">
                {#if confirm === `restore:${b.id}`}
                  <Button variant="secondary" size="sm" onclick={() => (confirm = null)} icon="close">{$LL.cancel()}</Button>
                {/if}
                <Button variant={r.asNew ? 'primary' : 'destructive'} size="sm" disabled={busy !== null || (!r.asNew && !stopped)} onclick={() => void restore(b)} icon="restart_alt">
                  {confirm === `restore:${b.id}` ? $LL.virtBakConfirmRestore({ name: guest.name }) : $LL.virtBakRestore()}
                </Button>
              </div>
            </div>

            <!-- Delete. -->
            <div class="space-y-[9px] border-t border-(--border-hairline) pt-[13px]">
              {#if b.protected}
                <p class="text-[12px] text-(--text-secondary)">{$LL.virtBakProtectedNoDelete()}</p>
              {/if}
              {#if confirm === `delete:${b.id}`}
                <p class="text-[12px] text-(--color-danger)">{$LL.virtConfirmAgain()}</p>
              {/if}
              <div class="flex justify-end gap-[9px]">
                {#if confirm === `delete:${b.id}`}
                  <Button variant="secondary" size="sm" onclick={() => (confirm = null)} icon="close">{$LL.cancel()}</Button>
                {/if}
                <Button variant="destructive" size="sm" disabled={busy !== null || b.protected} onclick={() => void remove(b)} icon="delete">
                  {confirm === `delete:${b.id}` ? $LL.virtBakConfirmDelete() : $LL.virtBakDelete()}
                </Button>
              </div>
            </div>
          </div>
        {/if}
      </Card>
    {/each}
  </Card>
{/if}
