<script lang="ts">
  import { Badge, Button, Card, Spinner } from '@serverbox/webui'
  import { ChevronDown, Pencil, Play, Plus, Trash2, X } from '@lucide/svelte'
  import VirtBackupJobForm from './VirtBackupJobForm.svelte'
  import { api } from '../../../lib/api'
  import { jobDraft, jobEdit, modeText, pruneText, selectionText, storageNames, virtErrorText, virtRequestText, type JobDraft } from '../../../lib/virt'
  import { onMount } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { VirtBackupJob, VirtBackupJobEdit, VirtBackupJobs, VirtError, VirtHostView } from '../../../types'

  /// The datacenter's backup jobs (PVE `/cluster/backup`): each, run now,
  /// edited, removed, and a new one. Whether the host takes a job is the
  /// agent's answer (`sbm_virt::backup::job_issue`), said after it is sent.
  interface Props {
    view: VirtHostView
  }

  const { view }: Props = $props()

  let data = $state<VirtBackupJobs | null>(null)
  let readError = $state('')
  let error = $state('')
  let notice = $state('')
  /// What is running; every button waits for it.
  let busy = $state<string | null>(null)
  /// Which two-click action is armed: `run:<id>`, `remove:<id>`.
  let confirm = $state<string | null>(null)
  let open = $state<Record<string, boolean>>({})
  /// The editor's draft (a new job or one by id); null while closed.
  let editing = $state<JobDraft | null>(null)

  const jobs = $derived(data?.jobs ?? [])
  const storages = $derived(data?.storages ?? [])
  const nodes = $derived(view.host.nodes.map((n) => n.name))

  onMount(() => void load())

  async function load() {
    try {
      const next = await api.backupJobs()
      readError = next.error ? virtErrorText(next.error) : ''
      data = next
    } catch (e) {
      readError = virtRequestText(e)
    }
  }

  async function run(kind: string, send: () => Promise<{ error: VirtError | null }>, done: string): Promise<boolean> {
    busy = kind
    error = ''
    notice = ''
    try {
      const { error: err } = await send()
      if (err) {
        error = virtErrorText(err)
        return false
      }
      notice = done
      return true
    } catch (e) {
      error = virtRequestText(e)
      return false
    } finally {
      busy = null
      await load()
    }
  }

  async function save(edit: VirtBackupJobEdit) {
    if (await run('save', () => api.editBackupJob(edit), $LL.virtBakPlanSaved())) editing = null
  }

  async function runNow(job: VirtBackupJob) {
    const key = `run:${job.id}`
    if (confirm !== key) {
      confirm = key
      return
    }
    // What is asked, before the confirmation that asked it goes.
    const id = job.id
    confirm = null
    await run(key, () => api.runBackupJob(id), $LL.virtBakJobRan({ id }))
  }

  async function remove(job: VirtBackupJob) {
    const key = `remove:${job.id}`
    if (confirm !== key) {
      confirm = key
      return
    }
    const edit = jobEdit(jobDraft(job))
    confirm = null
    await run(key, () => api.editBackupJob(edit, true), $LL.virtBakPlanRemoved())
  }

  function summary(job: VirtBackupJob): string {
    return [job.storage, selectionText(job), job.node ?? $LL.virtBakAnyNode()].filter(Boolean).join(' · ')
  }
</script>

{#snippet twice(key: string, label: string, confirmLabel: string, danger: boolean, act: () => void, Icon: typeof Play)}
  {#if confirm === key}
    <Button variant="secondary" size="sm" onclick={() => (confirm = null)}>
      <X class="h-4 w-4" />
      {$LL.cancel()}
    </Button>
  {/if}
  <Button variant={danger ? 'danger' : 'secondary'} size="sm" disabled={busy !== null} onclick={act}>
    <Icon class="h-4 w-4" />
    {confirm === key ? confirmLabel : label}
  </Button>
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
  {#if editing}
    {@const d = editing}
    <Card class="space-y-3">
      <h3 class="text-sm font-medium text-fg-strong">{d.isNew ? $LL.virtBakNewJob() : $LL.virtBakEditJob({ id: d.id })}</h3>
      {#key d}
        <VirtBackupJobForm draft={d} {storages} {nodes} full busy={busy !== null} onsave={(e) => void save(e)} oncancel={() => (editing = null)} />
      {/key}
    </Card>
  {/if}

  <Card class="space-y-2">
    <div class="flex items-center gap-2">
      <h3 class="text-sm font-medium text-fg-strong">{$LL.virtSectionBackupJobs()}</h3>
      <span class="text-xs text-faint-fg">{jobs.length || ''}</span>
      <Button class="ml-auto" size="sm" variant="secondary" disabled={busy !== null} onclick={() => { confirm = null; editing = jobDraft(null, storageNames(storages, '')[0] ?? '') }}>
        <Plus class="h-4 w-4" />
        {$LL.virtBakNewJob()}
      </Button>
    </div>

    {#if busy?.startsWith('run:')}
      <div class="flex items-center gap-2 rounded-lg bg-muted px-3 py-2 text-sm text-muted-fg">
        <Spinner size="sm" />
        {$LL.virtBakJobRunning({ id: busy.slice(4) })}
      </div>
    {/if}

    {#if jobs.length === 0}
      <p class="text-sm text-muted-fg">{$LL.virtBakNoJobs()}</p>
    {/if}
    {#each jobs as job (job.id)}
      <div class="rounded-lg border border-line">
        <button type="button" class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left transition-colors hover:bg-muted" aria-expanded={!!open[job.id]} onclick={() => (open[job.id] = !open[job.id])}>
          <span class="font-mono text-sm text-fg-strong">{job.schedule ?? '—'}</span>
          <span class="min-w-0 flex-1 truncate text-xs text-muted-fg">{summary(job)}</span>
          {#if !job.enabled}<Badge>{$LL.virtBakDisabled()}</Badge>{/if}
          <ChevronDown class="h-4 w-4 shrink-0 text-faint-fg transition-transform {open[job.id] ? 'rotate-180' : ''}" />
        </button>
        {#if open[job.id]}
          <div class="space-y-3 border-t border-line p-3">
            <dl class="grid grid-cols-2 gap-x-4 gap-y-2 text-xs @2xl:grid-cols-3">
              {#each [['ID', job.id], [$LL.virtBakSelection(), selectionText(job)], [$LL.virtNode(), job.node ?? $LL.virtBakAnyNode()], [$LL.virtBakMode(), modeText(job.mode, job.compress)], [$LL.virtBakRetention(), pruneText(job.prune)], [$LL.virtBakNotesTemplate(), job.notes_template], [$LL.virtBakComment(), job.comment], [$LL.virtBakMail(), job.mail_notification === 'always' ? $LL.virtBakMailAlways() : job.mail_notification === 'failure' ? $LL.virtBakMailFailure() : null]] as [label, value] (label)}
                {#if value}
                  <div class="min-w-0">
                    <dt class="text-faint-fg">{label}</dt>
                    <dd class="break-all text-muted-fg">{value}</dd>
                  </div>
                {/if}
              {/each}
            </dl>
            {#if confirm === `run:${job.id}`}
              <p class="text-xs text-warning">{$LL.virtBakRunNote()}</p>
            {:else if confirm === `remove:${job.id}`}
              <p class="text-xs text-danger">{$LL.virtConfirmAgain()}</p>
            {/if}
            <div class="flex flex-wrap justify-end gap-2">
              {@render twice(`remove:${job.id}`, $LL.virtHwRemove(), $LL.virtBakConfirmRemovePlan({ id: job.id }), true, () => void remove(job), Trash2)}
              {@render twice(`run:${job.id}`, $LL.virtBakRunNow(), $LL.virtBakConfirmRun({ id: job.id }), false, () => void runNow(job), Play)}
              <Button size="sm" disabled={busy !== null} onclick={() => { confirm = null; editing = jobDraft(job) }}>
                <Pencil class="h-4 w-4" />
                {$LL.virtBakEditPlan()}
              </Button>
            </div>
          </div>
        {/if}
      </div>
    {/each}
  </Card>
{/if}
