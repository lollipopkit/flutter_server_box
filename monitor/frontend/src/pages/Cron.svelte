<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import { CircleAlert, Pencil, Plus, Power, RefreshCw, Trash2 } from '@lucide/svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { api } from '../lib/api'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'
  import type { CronEdit, CronJobView, CronView } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

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

  /** The page follows the sidebar, so a reply that arrives after the user has
   * switched servers belongs to neither. */
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
      error = validationText(message)
      // The listing moved under this page. Reading it again is the remedy, and
      // doing it here is what makes the message true.
      if (message === 'unknownLine') void load()
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

  const editable = $derived(view?.editable === true)
  const jobs = $derived(view?.jobs ?? [])

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

<PageHeader
  title={$LL.cron()}
  subtitle={view?.user ? $LL.cronForUser({ user: view.user }) : undefined}
  containerClass="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet actions()}
    {#if editable && view?.available}
      <IconButton label={$LL.cronAdd()} onclick={openNew}>
        <Plus class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} onclick={() => void load()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
  {#if error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}

  {#if loading && !view}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if view && !view.available}
    <Card class="space-y-2">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
    </Card>
  {:else if view}
    {#if !editable}
      <Card class="space-y-2">
        <p class="text-sm text-muted-fg">{$LL.cronReadOnly()}</p>
      </Card>
    {/if}

    {#if jobs.length === 0}
      <Card class="space-y-2">
        <p class="text-sm text-muted-fg">{$LL.cronEmpty()}</p>
      </Card>
    {:else}
      <Card class="divide-y divide-border p-0">
        {#each jobs as job (job.line_index)}
          <div class="flex items-start gap-3 px-4 py-3">
            <span class="text-sm font-mono shrink-0 pt-0.5 {job.enabled ? 'text-fg-strong' : 'text-faint-fg'}">
              {job.schedule}
            </span>
            <div class="flex-1 min-w-0">
              <p
                class="text-sm truncate {job.enabled
                  ? 'text-fg-strong'
                  : 'text-faint-fg line-through'}"
                title={job.command}
              >
                {job.command}
              </p>
              <p class="text-xs text-muted-fg">
                {describe(job)}
                {#if job.enabled && job.next_run}
                  {describe(job) ? '·' : ''}
                  {nextRun(job)}
                {/if}
              </p>
            </div>
            {#if !job.enabled}
              <Badge tone="neutral">{$LL.cronDisabled()}</Badge>
            {/if}
            {#if editable}
              <div class="flex shrink-0">
                <IconButton
                  label={job.enabled ? $LL.cronDisable() : $LL.cronEnable()}
                  disabled={busy}
                  onclick={() =>
                    void apply({ op: 'set_enabled', line_index: job.line_index, enabled: !job.enabled })}
                >
                  <Power class="w-4 h-4" />
                </IconButton>
                <IconButton label={$LL.cronEditJob()} disabled={busy} onclick={() => openEdit(job)}>
                  <Pencil class="w-4 h-4" />
                </IconButton>
                <IconButton
                  label={$LL.cronRemove()}
                  disabled={busy}
                  onclick={() => void apply({ op: 'remove', line_index: job.line_index })}
                >
                  <Trash2 class="w-4 h-4" />
                </IconButton>
              </div>
            {/if}
          </div>
        {/each}
      </Card>
    {/if}

    {#if view.preserved.length > 0}
      <Card class="space-y-2">
        <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.cronPreserved()}</h2>
        <p class="text-xs text-muted-fg">{$LL.cronPreservedHint()}</p>
        <pre class="text-xs font-mono text-muted-fg whitespace-pre-wrap break-all">{view.preserved.join('\n')}</pre>
      </Card>
    {/if}

    {#if busy}
      <div class="flex items-center gap-2 text-xs text-muted-fg">
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
        <label class="text-sm text-muted-fg" for="cron-schedule">{$LL.cronSchedule()}</label>
        <Input id="cron-schedule" bind:value={draft.schedule} placeholder="0 3 * * *" />
        <p class="text-xs text-muted-fg">{$LL.cronScheduleHint()}</p>
      </div>
      <div class="space-y-1">
        <label class="text-sm text-muted-fg" for="cron-command">{$LL.cronCommand()}</label>
        <Input id="cron-command" bind:value={draft.command} placeholder="/usr/local/bin/backup.sh" />
        <p class="text-xs text-muted-fg">{$LL.cronCommandHint()}</p>
      </div>
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={draft.enabled} />
        {$LL.cronEnabled()}
      </label>
      {#if !draft.enabled}
        <p class="text-xs text-muted-fg inline-flex items-center gap-1">
          <CircleAlert class="w-3.5 h-3.5 shrink-0" />
          {$LL.cronDisabledHint()}
        </p>
      {/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (editing = undefined)}>{$LL.cancel()}</Button>
        <Button disabled={busy} onclick={() => void submit()}>{$LL.save()}</Button>
      </div>
    </div>
  </Modal>
{/if}
