<script lang="ts">
  import { Badge, Button, Card, Input, Select, Spinner } from '@serverbox/webui'
  import { Archive, ChevronDown, ChevronRight, Lock, Pencil, Plus, RotateCcw, Trash2, X } from '@lucide/svelte'
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
  <div class="flex items-center gap-2">
    <h3 class="text-sm font-medium text-fg-strong">{title}</h3>
    {#if right}
      <span class="ml-auto truncate text-xs text-faint-fg">{right}</span>
    {/if}
  </div>
{/snippet}

{#snippet field(label: string, value: string, mono: boolean = false)}
  <div class="min-w-0">
    <dt class="text-faint-fg">{label}</dt>
    <dd class="break-all text-muted-fg {mono ? 'font-mono' : ''}">{value}</dd>
  </div>
{/snippet}

{#if error}
  <Card class="border-danger/40 bg-danger/5">
    <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
  </Card>
{/if}
{#if notice}
  <Card>
    <p class="text-sm text-muted-fg whitespace-pre-wrap">{notice}</p>
  </Card>
{/if}

{#if readError}
  <Card><p class="text-sm text-danger whitespace-pre-wrap break-all">{readError}</p></Card>
{:else if !data}
  <Card><Spinner class="h-5 w-5" /></Card>
{:else}
  <!-- Plan: the jobs that take this guest. -->
  <Card class="space-y-3">
    <div class="flex items-center gap-2">
      <h3 class="text-sm font-medium text-fg-strong">{$LL.virtBakPlan()}</h3>
      {#if onjobs && view.capabilities.backup_jobs === true}
        <button type="button" class="ml-auto flex items-center gap-0.5 text-xs text-faint-fg hover:text-fg" onclick={onjobs}>
          {$LL.virtBakDatacenter()}
          <ChevronRight class="h-3.5 w-3.5" />
        </button>
      {/if}
    </div>

    {#if jobs.length === 0 && !plan}
      <p class="text-sm text-muted-fg">{$LL.virtBakNoPlan()}</p>
    {/if}

    {#each jobs as job (job.id)}
      {@const mine = job.id === own?.id}
      <div class="space-y-2 rounded-lg border border-line p-3">
        <div class="flex flex-wrap items-center gap-2">
          <span class="font-mono text-sm text-fg-strong">{job.id}</span>
          {#if !job.enabled}<Badge>{$LL.virtBakDisabled()}</Badge>{/if}
          {#if !mine}<span class="text-xs text-faint-fg">{selectionText(job)}</span>{/if}
        </div>
        <dl class="grid grid-cols-2 gap-x-4 gap-y-2 text-xs @2xl:grid-cols-4">
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
              <p class="text-xs text-danger">{$LL.virtConfirmAgain()}</p>
            {/if}
            <div class="flex justify-end gap-2">
              {#if confirm === 'plan'}
                <Button variant="secondary" size="sm" onclick={() => (confirm = null)}>
                  <X class="h-4 w-4" />
                  {$LL.cancel()}
                </Button>
              {/if}
              <Button variant="secondary" size="sm" disabled={busy !== null} onclick={() => void removePlan()}>
                <Trash2 class="h-4 w-4" />
                {confirm === 'plan' ? $LL.virtBakConfirmRemovePlan({ id: job.id }) : $LL.virtBakRemovePlan()}
              </Button>
              <Button size="sm" disabled={busy !== null} onclick={() => { confirm = null; plan = ownJobDraft(job, vmid) }}>
                <Pencil class="h-4 w-4" />
                {$LL.virtBakEditPlan()}
              </Button>
            </div>
          {/if}
        {:else}
          <p class="text-xs text-faint-fg">{$LL.virtBakSharedJob()}</p>
        {/if}
      </div>
    {/each}

    {#if vmid !== null && !own}
      {#if plan?.isNew}
        <div class="rounded-lg border border-line p-3">
          <VirtBackupJobForm draft={plan} {storages} busy={busy !== null} onsave={(e) => void savePlan(e)} oncancel={() => (plan = null)} />
        </div>
      {:else}
        <div class="flex justify-end">
          <Button variant="secondary" size="sm" disabled={busy !== null} onclick={() => (plan = ownJobDraft(null, vmid, names[0] ?? ''))}>
            <Plus class="h-4 w-4" />
            {$LL.virtBakAddPlan()}
          </Button>
        </div>
      {/if}
    {/if}
  </Card>

  <!-- Backups: one taken now, then each, newest first. -->
  <Card class="space-y-2">
    {@render head($LL.virtBakList(), backups.length ? String(backups.length) : '')}

    {#if busy === 'backup' || busy === 'restore'}
      <div class="flex items-center gap-2 rounded-lg bg-muted px-3 py-2 text-sm text-muted-fg">
        <Spinner size="sm" />
        {busy === 'backup' ? $LL.virtBakRunning() : $LL.virtBakRestoring()}
      </div>
    {/if}

    {#if taking}
      <form class="space-y-3 rounded-lg border border-line p-3" onsubmit={backUp}>
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtBakStorage()}</span>
          <Select class="w-full" bind:value={take.storage}>
            {#each names as n (n)}
              <option value={n}>{n}</option>
            {/each}
          </Select>
        </label>
        <div class="flex flex-wrap items-center gap-2">
          <span class="w-28 shrink-0 text-sm text-muted-fg">{$LL.virtBakMode()}</span>
          <div class="flex flex-wrap gap-1">
            {#each BACKUP_MODES as m (m)}
              <Button type="button" size="sm" variant={take.mode === m ? 'primary' : 'secondary'} aria-pressed={take.mode === m} onclick={() => (take.mode = m)}>{m}</Button>
            {/each}
          </div>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <span class="w-28 shrink-0 text-sm text-muted-fg">{$LL.virtBakCompress()}</span>
          <div class="flex flex-wrap gap-1">
            {#each BACKUP_COMPRESSIONS as c (c)}
              <Button type="button" size="sm" variant={take.compress === c ? 'primary' : 'secondary'} aria-pressed={take.compress === c} onclick={() => (take.compress = c)}>{compressText(c)}</Button>
            {/each}
          </div>
        </div>
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtBakNotes()}</span>
          <Input bind:value={take.notes} placeholder={$LL.virtBakOptional()} />
        </label>
        <label class="flex items-center gap-1.5 text-sm text-fg"><input type="checkbox" bind:checked={take.protected} /> {$LL.virtBakProtected()}</label>
        <div class="flex justify-end gap-2">
          <Button type="button" variant="secondary" size="sm" onclick={() => (taking = false)}>
            <X class="h-4 w-4" />
            {$LL.cancel()}
          </Button>
          <Button type="submit" size="sm" disabled={busy !== null || take.storage === ''}>
            <Archive class="h-4 w-4" />
            {$LL.virtBakStart()}
          </Button>
        </div>
      </form>
    {:else}
      <div class="flex flex-col items-center gap-2 rounded-lg border border-dashed border-line py-4 text-center">
        <p class="text-xs text-muted-fg">{$LL.virtBakNowNote()}</p>
        <Button size="sm" disabled={busy !== null || names.length === 0} onclick={() => (taking = true)}>
          <Archive class="h-4 w-4" />
          {$LL.virtBakNow()}
        </Button>
        {#if names.length === 0}
          <p class="text-xs text-warning">{$LL.virtBakNoStorage()}</p>
        {/if}
      </div>
    {/if}

    {#if backups.length === 0}
      <p class="text-sm text-muted-fg">{$LL.virtBakNone()}</p>
    {/if}
    {#each backups as b (b.id)}
      {@const ed = edits[b.id]}
      {@const r = restores[b.id]}
      <div class="rounded-lg border border-line">
        <button type="button" class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left transition-colors hover:bg-muted" aria-expanded={!!open[b.id]} onclick={() => toggle(b)}>
          <span class="text-sm text-fg-strong">{when(b.created_at)}</span>
          <span class="min-w-0 flex-1 truncate text-xs text-muted-fg">{summary(b)}</span>
          {#if b.protected}<Lock class="h-3.5 w-3.5 shrink-0 text-faint-fg" aria-label={$LL.virtBakProtected()} />{/if}
          {#if b.verification === 'ok'}
            <Badge tone="success">{$LL.virtBakVerified()}</Badge>
          {:else if b.verification === 'failed'}
            <Badge tone="danger">{$LL.virtBakVerifyFailed()}</Badge>
          {/if}
          <ChevronDown class="h-4 w-4 shrink-0 text-faint-fg transition-transform {open[b.id] ? 'rotate-180' : ''}" />
        </button>
        {#if open[b.id] && ed && r}
          <div class="space-y-3 border-t border-line p-3">
            <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-xs">
              <dt class="text-faint-fg">{$LL.virtBakFile()}</dt>
              <dd class="break-all font-mono text-muted-fg">{b.id}</dd>
            </dl>

            <!-- Its own fields. -->
            <label class="block space-y-1 text-sm">
              <span class="text-muted-fg">{$LL.virtBakNotes()}</span>
              <textarea class="w-full rounded-lg border border-line bg-surface px-3 py-2 text-sm text-fg" rows="2" bind:value={ed.notes}></textarea>
            </label>
            <label class="flex items-start gap-2 text-sm">
              <input class="mt-1" type="checkbox" bind:checked={ed.protected} />
              <span>
                <span class="text-fg">{$LL.virtBakProtected()}</span>
                <span class="block text-xs text-faint-fg">{$LL.virtBakProtectedNote()}</span>
              </span>
            </label>
            <div class="flex justify-end">
              <Button size="sm" disabled={busy !== null || (ed.notes === (b.notes ?? '') && ed.protected === b.protected)} onclick={() => void saveEdit(b)}>{$LL.save()}</Button>
            </div>

            <!-- Restore. -->
            <div class="space-y-2 border-t border-line pt-3">
              <div class="flex flex-wrap gap-1">
                <Button type="button" size="sm" variant={r.asNew ? 'secondary' : 'primary'} aria-pressed={!r.asNew} onclick={() => { r.asNew = false; confirm = null }}>{$LL.virtBakOverGuest()}</Button>
                <Button type="button" size="sm" variant={r.asNew ? 'primary' : 'secondary'} aria-pressed={r.asNew} onclick={() => { r.asNew = true; confirm = null }}>{$LL.virtBakAsNew()}</Button>
              </div>
              <div class="flex flex-wrap gap-3">
                {#if r.asNew}
                  <label class="block w-36 space-y-1 text-sm">
                    <span class="text-muted-fg">VMID</span>
                    <Input type="number" min="100" bind:value={r.vmid} placeholder={$LL.virtVmidNext()} />
                  </label>
                {/if}
                <label class="block min-w-40 flex-1 space-y-1 text-sm">
                  <span class="text-muted-fg">{$LL.virtBakRestoreStorage()}</span>
                  <Select class="w-full" bind:value={r.storage}>
                    <option value="">{$LL.virtBakRestoreStorageOwn()}</option>
                    {#each diskStorages ?? [] as p (p.id)}
                      <option value={p.name}>{p.name} · {p.type}</option>
                    {/each}
                  </Select>
                </label>
              </div>
              {#if !r.asNew}
                <p class="text-xs text-warning">{$LL.virtBakOverwrites()}</p>
                {#if !stopped}
                  <p class="text-xs text-muted-fg">{$LL.virtStopFirst()}</p>
                {/if}
              {/if}
              {#if confirm === `restore:${b.id}`}
                <p class="text-xs text-danger">{$LL.virtConfirmAgain()}</p>
              {/if}
              <div class="flex justify-end gap-2">
                {#if confirm === `restore:${b.id}`}
                  <Button variant="secondary" size="sm" onclick={() => (confirm = null)}>
                    <X class="h-4 w-4" />
                    {$LL.cancel()}
                  </Button>
                {/if}
                <Button variant={r.asNew ? 'primary' : 'danger'} size="sm" disabled={busy !== null || (!r.asNew && !stopped)} onclick={() => void restore(b)}>
                  <RotateCcw class="h-4 w-4" />
                  {confirm === `restore:${b.id}` ? $LL.virtBakConfirmRestore({ name: guest.name }) : $LL.virtBakRestore()}
                </Button>
              </div>
            </div>

            <!-- Delete. -->
            <div class="space-y-2 border-t border-line pt-3">
              {#if b.protected}
                <p class="text-xs text-muted-fg">{$LL.virtBakProtectedNoDelete()}</p>
              {/if}
              {#if confirm === `delete:${b.id}`}
                <p class="text-xs text-danger">{$LL.virtConfirmAgain()}</p>
              {/if}
              <div class="flex justify-end gap-2">
                {#if confirm === `delete:${b.id}`}
                  <Button variant="secondary" size="sm" onclick={() => (confirm = null)}>
                    <X class="h-4 w-4" />
                    {$LL.cancel()}
                  </Button>
                {/if}
                <Button variant="danger" size="sm" disabled={busy !== null || b.protected} onclick={() => void remove(b)}>
                  <Trash2 class="h-4 w-4" />
                  {confirm === `delete:${b.id}` ? $LL.virtBakConfirmDelete() : $LL.virtBakDelete()}
                </Button>
              </div>
            </div>
          </div>
        {/if}
      </div>
    {/each}
  </Card>
{/if}
