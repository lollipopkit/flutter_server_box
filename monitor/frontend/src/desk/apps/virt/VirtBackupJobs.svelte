<script lang="ts">
  import { Badge, Button, Card, Icon, Spinner } from '../../lk'
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

{#snippet twice(key: string, label: string, confirmLabel: string, danger: boolean, act: () => void, icon: string)}
  {#if confirm === key}
    <Button variant="secondary" size="sm" onclick={() => (confirm = null)} icon="close">{$LL.cancel()}</Button>
  {/if}
  <Button variant={danger ? 'destructive' : 'secondary'} size="sm" disabled={busy !== null} onclick={act} {icon}>
    {confirm === key ? confirmLabel : label}
  </Button>
{/snippet}

{#if error}
  <Card><p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p></Card>
{/if}
{#if notice}
  <Card><p class="whitespace-pre-wrap text-[13px] text-(--text-secondary)">{notice}</p></Card>
{/if}

{#if readError}
  <Card><p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{readError}</p></Card>
{:else if !data}
  <Card><Spinner class="h-5 w-5" /></Card>
{:else}
  {#if editing}
    {@const d = editing}
    <Card class="space-y-[13px]">
      <h3 class="text-[15px] font-semibold">{d.isNew ? $LL.virtBakNewJob() : $LL.virtBakEditJob({ id: d.id })}</h3>
      {#key d}
        <VirtBackupJobForm draft={d} {storages} {nodes} full busy={busy !== null} onsave={(e) => void save(e)} oncancel={() => (editing = null)} />
      {/key}
    </Card>
  {/if}

  <Card class="space-y-[9px]">
    <div class="flex items-center gap-[9px]">
      <h3 class="text-[15px] font-semibold">{$LL.virtSectionBackupJobs()}</h3>
      <Badge tone="neutral">{jobs.length}</Badge>
      <Button class="ml-auto" size="sm" variant="tinted" icon="add" disabled={busy !== null} onclick={() => { confirm = null; editing = jobDraft(null, storageNames(storages, '')[0] ?? '') }}>
        {$LL.virtBakNewJob()}
      </Button>
    </div>

    {#if busy?.startsWith('run:')}
      <Card padding="11px 13px" class="flex items-center gap-[9px] text-[13px] text-(--text-secondary)">
        <Spinner size="sm" />
        {$LL.virtBakJobRunning({ id: busy.slice(4) })}
      </Card>
    {/if}

    {#if jobs.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-[27px] text-(--text-tertiary)">
        <Icon name="backup" size={48} weight={300} />
        <p class="text-[13px]">{$LL.virtEmptyBackupJobs()}</p>
      </div>
    {/if}
    {#each jobs as job (job.id)}
      <Card variant="raised" padding="0">
        <button type="button" class="flex w-full items-center gap-[9px] rounded-[13px] px-[13px] py-[9px] text-left" aria-expanded={!!open[job.id]} onclick={() => (open[job.id] = !open[job.id])}>
          <span class="lk-mono text-[13px] font-semibold text-(--text-primary)">{job.schedule ?? '—'}</span>
          <span class="min-w-0 flex-1 truncate text-[12px] text-(--text-secondary)">{summary(job)}</span>
          {#if !job.enabled}<Badge>{$LL.virtBakDisabled()}</Badge>{/if}
          <Icon name={open[job.id] ? 'expand_less' : 'expand_more'} size={18} />
        </button>
        {#if open[job.id]}
          <div class="space-y-[13px] border-t border-(--border-hairline) p-[13px]">
            <dl class="grid grid-cols-2 gap-x-[13px] gap-y-[9px] text-[12px] @2xl:grid-cols-3">
              {#each [['ID', job.id], [$LL.virtBakSelection(), selectionText(job)], [$LL.virtNode(), job.node ?? $LL.virtBakAnyNode()], [$LL.virtBakMode(), modeText(job.mode, job.compress)], [$LL.virtBakRetention(), pruneText(job.prune)], [$LL.virtBakNotesTemplate(), job.notes_template], [$LL.virtBakComment(), job.comment], [$LL.virtBakMail(), job.mail_notification === 'always' ? $LL.virtBakMailAlways() : job.mail_notification === 'failure' ? $LL.virtBakMailFailure() : null]] as [label, value] (label)}
                {#if value}
                  <div class="min-w-0">
                    <dt class="text-(--text-tertiary)">{label}</dt>
                    <dd class="break-all text-(--text-secondary)">{value}</dd>
                  </div>
                {/if}
              {/each}
            </dl>
            {#if confirm === `run:${job.id}`}
              <p class="text-[12px] text-(--color-warning)">{$LL.virtBakRunNote()}</p>
            {:else if confirm === `remove:${job.id}`}
              <p class="text-[12px] text-(--color-danger)">{$LL.virtConfirmAgain()}</p>
            {/if}
            <div class="flex flex-wrap justify-end gap-[5px]">
              {@render twice(`remove:${job.id}`, $LL.virtHwRemove(), $LL.virtBakConfirmRemovePlan({ id: job.id }), true, () => void remove(job), 'delete')}
              {@render twice(`run:${job.id}`, $LL.virtBakRunNow(), $LL.virtBakConfirmRun({ id: job.id }), false, () => void runNow(job), 'play_arrow')}
              <Button size="sm" disabled={busy !== null} onclick={() => { confirm = null; editing = jobDraft(job) }} icon="edit">
                {$LL.virtBakEditPlan()}
              </Button>
            </div>
          </div>
        {/if}
      </Card>
    {/each}
  </Card>
{/if}
