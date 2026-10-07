<script lang="ts">
  import Spinner from '../../lk/Spinner.svelte'
  import { Badge, Button, Card, Checkbox, Dialog, Icon, IconButton, Input } from '../../lk'
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
      <Button size="sm" variant="tinted" icon="add" onclick={openNew}>{$LL.cronAdd()}</Button>
    {/if}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} disabled={loading} />
  {/snippet}
</AppToolbar>

<main class="space-y-[9px] px-[17px] pb-[17px] pt-[4px]">
  {#if error}<Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card>{/if}

  {#if loading && !view}
    <Card class="grid place-items-center" padding="21px"><Spinner class="h-5 w-5" /></Card>
  {:else if view && !view.available}
    <Card><p class="text-[13px] text-(--text-secondary)">{reasonText(view)}</p></Card>
  {:else if view}
    {#if jobs.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
        <Icon name="schedule" size={48} weight={300} />
        <span class="text-[13px]">{$LL.cronEmptyState()}</span>
      </div>
    {:else}
      <!-- One job per card: schedule and command, with state and actions. -->
      <ul class="space-y-[7px]">
        {#each jobs as job (job.line_index)}
          <li>
            <Card padding="11px 13px">
              <div class="flex min-w-0 items-center gap-[13px]">
                <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised) text-(--color-accent-text)"><Icon name="schedule" size={18} /></span>
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-[7px]">
                    <span class="lk-mono text-[13px]">{job.schedule}</span>
                    <Badge tone={job.enabled ? 'success' : 'neutral'} dot>{job.enabled ? $LL.cronEnabled() : $LL.cronDisabled()}</Badge>
                  </div>
                  <p class="lk-mono truncate text-[12px] text-(--text-secondary)" class:line-through={!job.enabled} title={job.command}>{job.command}</p>
                  {#if metaText(job)}<p class="text-[12px] text-(--text-tertiary)">{metaText(job)}</p>{/if}
                </div>
                <div class="flex shrink-0 items-center gap-[3px]">
                  <IconButton icon={job.enabled ? 'toggle_on' : 'toggle_off'} label={job.enabled ? $LL.cronDisable() : $LL.cronEnable()} disabled={busy} onclick={() => void apply({ op: 'set_enabled', line_index: job.line_index, enabled: !job.enabled })} />
                  <IconButton icon="edit" label={$LL.cronEditJob()} disabled={busy} onclick={() => openEdit(job)} />
                  <IconButton icon="delete" label={$LL.cronRemove()} disabled={busy} onclick={() => void apply({ op: 'remove', line_index: job.line_index })} />
                </div>
              </div>
            </Card>
          </li>
        {/each}
      </ul>
    {/if}

    {#if view.preserved.length > 0}
      <section class="space-y-[7px] pt-[3px]">
        <h2 class="lk-caps px-[3px]">{$LL.cronPreserved()}</h2>
        <Card>
          <p class="text-[12px] text-(--text-secondary)">{$LL.cronPreservedHint()}</p>
          <pre class="mt-[9px] overflow-x-auto rounded-[9px] bg-(--surface-control) p-[9px] lk-mono whitespace-pre-wrap break-all text-[12px] text-(--text-secondary)">{view.preserved.join('\\n')}</pre>
        </Card>
      </section>
    {/if}

    {#if busy}<div class="flex items-center gap-[7px] px-[3px] text-[12px] text-(--text-tertiary)"><Spinner size="sm" /></div>{/if}
  {/if}
</main>

{#if editing !== undefined}
  <Dialog open wide title={editing ? $LL.cronEditJob() : $LL.cronAdd()} onclose={() => (editing = undefined)}>
    {#snippet actions()}
      <Button variant="primary" disabled={busy} onclick={() => void submit()}>{$LL.save()}</Button>
      <Button variant="secondary" onclick={() => (editing = undefined)}>{$LL.cancel()}</Button>
    {/snippet}
    {#if editError}<p class="mb-[9px] text-[13px] text-(--color-danger)">{editError}</p>{/if}
    <div class="grid gap-[13px]">
      <Input id="cron-schedule" bind:value={draft.schedule} label={$LL.cronSchedule()} hint={$LL.cronScheduleHint()} placeholder="0 3 * * *" mono />
      <Input id="cron-command" bind:value={draft.command} label={$LL.cronCommand()} hint={$LL.cronCommandHint()} placeholder="/usr/local/bin/backup.sh" mono />
      <div>
        <Checkbox bind:checked={draft.enabled} label={$LL.cronEnabled()} />
        {#if !draft.enabled}<p class="mt-[7px] text-[12px] text-(--text-secondary)">{$LL.cronDisabledHint()}</p>{/if}
      </div>
    </div>
  </Dialog>
{/if}
