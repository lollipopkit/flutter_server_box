<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import { CircleAlert, Pencil, Plus, Power, RefreshCw, Trash2 } from '@lucide/svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import { api } from '../../../lib/api'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import type { CronEdit, CronJobView, CronView } from '../../../types'

  let view = $state<CronView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  /** The job being edited, or `null` for a new one. `undefined` means the
   * editor is closed — an appended job and a page that has not opened one are
   * both `null` otherwise. */
  let editing = $state<CronJobView | null | undefined>(undefined)
  let draft = $state({ schedule: '', command: '', enabled: true })
  let editError = $state('')

  /** A reply that arrives after the desk has switched servers belongs to
   * neither. */
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getCron()
      if (stale(serverId)) return
      view = next
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    void load()
  })

  /// Every edit answers with the schedule as it now stands, so one request both
  /// writes and refreshes — and a refusal leaves `view` alone, which is what
  /// makes a stale index a reload rather than a wrong write.
  async function apply(edit: CronEdit) {
    busy = true
    error = ''
    try {
      view = await api.editCron(edit)
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e)
      // The listing moved under this page. Reading it again is the remedy, and
      // doing it here is what makes the message true. Set after the reload,
      // which clears the banner when it starts.
      if (message === 'unknownLine') await load()
      error = validationText(message)
    } finally {
      busy = false
    }
  }

  /// A refusal arrives as the rule's own name, so the panel phrases it. A word
  /// this build does not know is shown as the agent sent it: it is a rule
  /// added since, and a sentence invented here would misdescribe it.
  function validationText(message: string): string {
    switch (message) {
      case 'scheduleEmpty':
        return $LL.cronInvalidScheduleEmpty()
      case 'commandEmpty':
        return $LL.cronInvalidCommandEmpty()
      case 'lineBreak':
        return $LL.cronInvalidLineBreak()
      case 'macro':
        return $LL.cronInvalidMacro()
      case 'fieldCount':
        return $LL.cronInvalidFieldCount()
      case 'unknownLine':
        return $LL.cronInvalidUnknownLine()
      default:
        return message
    }
  }

  /// The editor keeps its own error: a refusal in a dialog has to be read in
  /// the dialog, which the page's banner is behind.
  async function submit() {
    editError = ''
    busy = true
    try {
      view = await api.editCron({
        op: 'upsert',
        line_index: editing ? editing.line_index : null,
        schedule: draft.schedule,
        command: draft.command,
        enabled: draft.enabled,
      })
      editing = undefined
    } catch (e) {
      editError = validationText(e instanceof Error ? e.message : String(e))
    } finally {
      busy = false
    }
  }

  function openNew() {
    draft = { schedule: '', command: '', enabled: true }
    editError = ''
    editing = null
  }

  function openEdit(job: CronJobView) {
    draft = { schedule: job.schedule, command: job.command, enabled: job.enabled }
    editError = ''
    editing = job
  }

  const jobs = $derived(view?.jobs ?? [])

  /// What the schedule means and when it next runs, as the one line under a
  /// job: either part may be missing, and the separator only when both are
  /// there.
  function metaText(job: CronJobView): string {
    const next = job.enabled && job.next_run ? nextRun(job) : ''
    return [describe(job), next].filter(Boolean).join(' · ')
  }

  /// What the schedule means in words, from the fields the agent expanded.
  ///
  /// The expression is always shown beside this, never instead of it — an
  /// expansion this app got wrong would otherwise be invisible — and anything
  /// the fields do not pin down returns nothing rather than a guess. The day
  /// fields are the ones that make guessing wrong: `0 3 * * 1` restricted to
  /// Mondays is not "every day at 03:00", and it is also not a run of days this
  /// list of numbers spells out.
  function describe(job: CronJobView): string {
    if (job.is_reboot) return $LL.cronReboot()
    if (!job.parsed) return $LL.cronUnparsed()
    if (job.day_of_month_restricted || job.day_of_week_restricted) return ''
    if (job.months.length !== 12) return ''
    if (job.minutes.length === 60 && job.hours.length === 24) return $LL.cronEveryMinute()
    if (job.minutes.length === 1 && job.hours.length === 24) {
      return $LL.cronHourly({ minute: pad(job.minutes) })
    }
    if (job.minutes.length === 1 && job.hours.length === 1) {
      return $LL.cronDailyAt({ time: `${pad(job.hours)}:${pad(job.minutes)}` })
    }
    return ''
  }

  function pad(values: number[]): string {
    return values.map((v) => String(v).padStart(2, '0')).join(',')
  }

  /// The next run as the *server* placed it, shown beside how long that is
  /// from now. Both timestamps are naive wall-clock strings and both are the
  /// server's own — this browser never interprets either, which is why a job
  /// scheduled in a timezone the viewer is not in still reads correctly.
  function nextRun(job: CronJobView): string {
    if (!job.next_run || !view?.now) return ''
    const minutes = Math.round(
      (Date.parse(`${job.next_run}:00Z`) - Date.parse(`${view.now}:00Z`)) / 60_000,
    )
    if (!Number.isFinite(minutes)) return job.next_run
    const inWords =
      minutes < 60
        ? $LL.cronInMinutes({ minutes })
        : minutes < 60 * 48
          ? $LL.cronInHours({ hours: Math.round(minutes / 60) })
          : $LL.cronInDays({ days: Math.round(minutes / 1440) })
    return $LL.cronNextRun({ in: inWords })
  }

  function reasonText(reason: CronView): string {
    switch (reason.reason_kind) {
      case 'not_installed':
        return $LL.cronNotInstalled()
      case 'unsupported_platform':
        return $LL.cronUnsupportedPlatform()
      case 'unreadable':
        return $LL.cronUnreadable()
      default:
        // What the machine said, verbatim: it is the only thing that
        // distinguishes one failure from another.
        return reason.reason ?? $LL.cronUnreadable()
    }
  }
</script>

<AppToolbar subtitle={view?.user ? $LL.cronForUser({ user: view.user }) : undefined}>
  {#snippet actions()}
    {#if view?.available}
      <IconButton label={$LL.cronAdd()} onclick={openNew}>
        <Plus class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} onclick={() => void load()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</AppToolbar>

<main class="mx-auto max-w-3xl space-y-3 px-4 py-4 @3xl:px-6">
  {#if error}
    <Card class="border-danger/40 bg-danger/5 p-3">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}

  {#if loading && !view}
    <Card class="grid place-items-center p-4"><Spinner class="h-5 w-5" /></Card>
  {:else if view && !view.available}
    <Card class="p-4">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
    </Card>
  {:else if view}
    {#if jobs.length === 0}
      <Card class="p-4">
        <p class="text-sm text-muted-fg">{$LL.cronEmpty()}</p>
      </Card>
    {:else}
      <!-- One job per card: what it runs on top, how the schedule reads and
           when it next runs below, and the three things that may be done to it
           along the right. The dot carries the enabled state the badge on a
           paused job spells out. -->
      <ul class="space-y-2">
        {#each jobs as job (job.line_index)}
          <li
            class="flex items-start gap-3 rounded-xl border border-line bg-surface px-3 py-2.5 transition-colors hover:bg-soft/40"
          >
            <span class="mt-1.5 h-2 w-2 shrink-0 rounded-full {job.enabled ? 'bg-success' : 'bg-faint-fg'}"></span>
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <span class="font-mono text-[0.8rem] {job.enabled ? 'text-fg-strong' : 'text-muted-fg'}">
                  {job.schedule}
                </span>
                {#if !job.enabled}
                  <Badge tone="neutral">{$LL.cronDisabled()}</Badge>
                {/if}
              </div>
              <p
                class="mt-0.5 truncate font-mono text-xs {job.enabled
                  ? 'text-muted-fg'
                  : 'text-faint-fg line-through'}"
                title={job.command}
              >
                {job.command}
              </p>
              {#if metaText(job)}
                <p class="mt-0.5 text-[0.7rem] text-faint-fg">{metaText(job)}</p>
              {/if}
            </div>
            <div class="flex shrink-0 items-center gap-0.5">
              <IconButton
                label={job.enabled ? $LL.cronDisable() : $LL.cronEnable()}
                disabled={busy}
                onclick={() =>
                  void apply({ op: 'set_enabled', line_index: job.line_index, enabled: !job.enabled })}
              >
                <Power class="h-4 w-4" />
              </IconButton>
              <IconButton label={$LL.cronEditJob()} disabled={busy} onclick={() => openEdit(job)}>
                <Pencil class="h-4 w-4" />
              </IconButton>
              <IconButton
                label={$LL.cronRemove()}
                disabled={busy}
                onclick={() => void apply({ op: 'remove', line_index: job.line_index })}
              >
                <Trash2 class="h-4 w-4" />
              </IconButton>
            </div>
          </li>
        {/each}
      </ul>
    {/if}

    {#if view.preserved.length > 0}
      <section class="space-y-2 pt-1">
        <h2 class="px-1 text-[0.7rem] font-semibold uppercase tracking-wide text-muted-fg">
          {$LL.cronPreserved()}
        </h2>
        <Card class="space-y-2 p-3">
          <p class="text-xs text-muted-fg">{$LL.cronPreservedHint()}</p>
          <pre
            class="overflow-x-auto rounded-lg bg-soft/60 p-2 text-xs font-mono text-muted-fg whitespace-pre-wrap break-all">{view.preserved.join('\n')}</pre>
        </Card>
      </section>
    {/if}

    {#if busy}
      <div class="flex items-center gap-2 px-1 text-xs text-muted-fg">
        <Spinner size="sm" />
      </div>
    {/if}
  {/if}
</main>

{#if editing !== undefined}
  <Modal open title={editing ? $LL.cronEditJob() : $LL.cronAdd()} onclose={() => (editing = undefined)}>
    <div class="space-y-4">
      {#if editError}
        <p class="text-sm text-danger">{editError}</p>
      {/if}
      <div class="space-y-1">
        <label class="text-[0.8rem] font-medium text-fg" for="cron-schedule">{$LL.cronSchedule()}</label>
        <Input id="cron-schedule" class="font-mono" bind:value={draft.schedule} placeholder="0 3 * * *" />
        <p class="text-[0.7rem] text-muted-fg">{$LL.cronScheduleHint()}</p>
      </div>
      <div class="space-y-1">
        <label class="text-[0.8rem] font-medium text-fg" for="cron-command">{$LL.cronCommand()}</label>
        <Input id="cron-command" class="font-mono" bind:value={draft.command} placeholder="/usr/local/bin/backup.sh" />
        <p class="text-[0.7rem] text-muted-fg">{$LL.cronCommandHint()}</p>
      </div>
      <label class="flex items-center gap-2 text-[0.8rem] text-fg">
        <input type="checkbox" bind:checked={draft.enabled} />
        {$LL.cronEnabled()}
      </label>
      {#if !draft.enabled}
        <p class="inline-flex items-center gap-1 text-[0.7rem] text-muted-fg">
          <CircleAlert class="h-3.5 w-3.5 shrink-0" />
          {$LL.cronDisabledHint()}
        </p>
      {/if}
      <div class="flex justify-end gap-2 border-t border-line pt-3">
        <Button variant="secondary" onclick={() => (editing = undefined)}>{$LL.cancel()}</Button>
        <Button disabled={busy} onclick={() => void submit()}>{$LL.save()}</Button>
      </div>
    </div>
  </Modal>
{/if}
