<script lang="ts">
  /// The Containers app's backups (`/container-backups`): where they
  /// go (a backup disk's folder) and how many are kept, the schedules, each
  /// backup's containers and what it archived and left out, to restore or
  /// remove; and the backup or restore running, as it goes.

  import { Badge, Button, Card, Dialog, Group, Icon, IconButton, Input, Row, Select, Spinner } from '../../lk'
  import { errorText } from '../../../lib/errorText'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import ReauthDialog from '../../../components/ReauthDialog.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import { DATE_TIME, fmtBytes, fmtDate } from '../../../lib/format'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import type { ContainerBackup, ContainerBackupSchedule, ContainerBackupSettings, ContainerMount, StackJob } from '../../../types'
  import { untrack } from 'svelte'

  interface Props {
    /// A job just started here (a backup from a container's row).
    started?: StackJob | null
  }

  const { started = null }: Props = $props()

  let backups = $state<ContainerBackup[] | null>(null)
  let settings = $state<ContainerBackupSettings | null>(null)
  let folder = $state('')
  let freeBytes = $state<number | null>(null)
  let schedules = $state<ContainerBackupSchedule[]>([])
  /// The settings form, and the mounted filesystems it offers (Storage).
  let editing = $state(false)
  let draftDestination = $state('')
  let draftKeep = $state('7')
  let mounts = $state<{ path: string; free: number | null }[]>([])
  let settingsError = $state('')
  let job = $state<StackJob | null>(untrack(() => started))
  let error = $state('')
  /// The backup whose restore or removal asks the password.
  let asking = $state<{ backup: ContainerBackup; restore: boolean } | null>(null)

  async function load(serverId = servers.currentId) {
    try {
      const r = await api.listContainerBackups()
      if (serverId !== servers.currentId) return
      backups = r.backups
      settings = r.settings
      folder = r.folder
      freeBytes = r.free_bytes
      schedules = r.schedules
      if (r.job?.state === 'running') job = r.job
    } catch (e) {
      error = errorText(e)
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  $effect(() => {
    if (started) job = started
  })

  function mountText(m: ContainerMount): string {
    return m.kind === 'volume' ? $LL.containerBackupVolume({ name: m.name, at: m.destination }) : `${m.source} → ${m.destination}`
  }

  function jobTitle(j: StackJob): string {
    const restore = j.kind === 'restore'
    if (j.state === 'running') return restore ? $LL.containerBackupRestoring() : $LL.containerBackupRunning()
    if (j.state === 'succeeded') return restore ? $LL.containerBackupRestored() : $LL.containerBackupDone()
    return $LL.containerBackupUnfinished()
  }

  function total(b: ContainerBackup): number {
    return b.archives.reduce((sum, a) => sum + a.bytes, 0)
  }

  const { stale } = useScope()

  const storage = $derived(capabilitiesStore.byServer[servers.currentId]?.features?.includes('storage') === true)

  async function openSettings() {
    draftDestination = settings?.destination ?? ''
    draftKeep = String(settings?.keep ?? 7)
    settingsError = ''
    editing = true
    if (storage) {
      const serverId = servers.currentId
      try {
        const found = await api.containerBackupDestinations()
        if (!stale(serverId)) mounts = found
      } catch {
        mounts = []
      }
    }
  }

  async function saveSettings() {
    settingsError = ''
    try {
      settings = await api.setContainerBackupSettings({ destination: draftDestination.trim() || null, keep: Math.max(0, Number(draftKeep) || 0) })
      editing = false
      await load()
    } catch (e) {
      const code = e instanceof ApiError ? (e.body as { error?: string } | undefined)?.error : undefined
      settingsError =
        code === 'destinationMissing'
          ? $LL.containerBackupDestinationMissing()
          : code === 'destinationNotWritable'
            ? $LL.containerBackupDestinationNotWritable()
            : e instanceof Error
              ? e.message
              : String(e)
    }
  }

  async function removeSchedule(s: ContainerBackupSchedule) {
    try {
      await api.removeContainerBackupSchedule(s.id)
      await load()
    } catch (e) {
      error = errorText(e)
    }
  }

  function when(s: ContainerBackupSchedule): string {
    if (s.every === 'daily') return $LL.containerBackupDaily({ at: s.at })
    const days = [$LL.weekdayMon(), $LL.weekdayTue(), $LL.weekdayWed(), $LL.weekdayThu(), $LL.weekdayFri(), $LL.weekdaySat(), $LL.weekdaySun()]
    return $LL.containerBackupWeekly({ day: days[s.weekday ?? 0], at: s.at })
  }

  async function confirm(password: string) {
    const ask = asking
    if (!ask) return
    try {
      if (ask.restore) {
        job = await api.restoreContainerBackup(ask.backup.id, password)
      } else {
        await api.removeContainerBackup(ask.backup.id, password)
        await load()
      }
      asking = null
    } catch (e) {
      const code = e instanceof ApiError ? (e.body as { error?: string } | undefined)?.error : undefined
      if (code === 'reauth' || code === 'throttled') throw e
      error = code === 'busy' ? $LL.containerBackupBusy() : errorText(e)
      asking = null
    }
  }
</script>

<div class="space-y-[13px] px-(--content-pad) pb-[21px]">
  {#if error}
    <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
      <Icon name="error" size={17} />
      <p>{error}</p>
    </Card>
  {/if}

  {#if job}
    {#key job.id}
      <StackProgress
        {job}
        title={jobTitle(job)}
        read={(since) => api.containerBackupJob(since)}
        stop={() => api.cancelContainerBackupJob()}
        ondone={(done) => {
          job = done
          void load()
        }}
      />
    {/key}
  {/if}

  {#if settings}
    <Group title={$LL.containerBackupWhere()}>
      <Row label={$LL.containerBackupFolder()} value={folder} mono sub={freeBytes != null ? $LL.containerBackupFree({ free: fmtBytes(freeBytes) }) : undefined}>
        <Button size="sm" variant="secondary" onclick={() => void openSettings()}>{$LL.containerBackupChange()}</Button>
      </Row>
      <Row label={$LL.containerBackupKeep()} value={settings.keep ? String(settings.keep) : $LL.containerBackupKeepAll()} />
    </Group>
  {/if}
  {#if schedules.length}
    <Group title={$LL.containerBackupSchedules()}>
      {#each schedules as s (s.id)}
        <Row
          label={s.project ? $LL.containerBackUpProject({ project: s.label }) : s.label}
          value={when(s)}
          sub={s.last_error ? $LL.containerBackupLastFailed({ error: s.last_error }) : s.last_run ? $LL.containerBackupLastRun({ at: fmtDate(new Date(s.last_run), DATE_TIME) }) : undefined}
        >
          <IconButton icon="delete" size="sm" label={$LL.containerBackupRemove()} onclick={() => void removeSchedule(s)} />
        </Row>
      {/each}
    </Group>
  {/if}

  {#if !backups}
    {#if !error}<div class="flex justify-center py-12"><Spinner /></div>{/if}
  {:else if backups.length === 0}
    <div class="flex flex-col items-center gap-[9px] py-[55px] text-(--text-tertiary)">
      <Icon name="inventory_2" size={48} />
      <p class="text-[15px] font-semibold text-(--text-secondary)">{$LL.containerBackupsEmpty()}</p>
      <p class="max-w-[420px] text-center text-[13px]">{$LL.containerBackupsHint()}</p>
    </div>
  {:else}
    {#each backups as b (b.id)}
      <Group title={`${b.label} · ${fmtDate(new Date(b.created_at), DATE_TIME)}`}>
        <Row label={$LL.containerBackupContainers()} value={b.containers.map((c) => c.name).join(', ')} />
        <Row label={$LL.containerBackupSize()} value={fmtBytes(total(b))}>
          {#if b.stopped}<Badge tone="neutral">{$LL.containerBackupStopped()}</Badge>{/if}
        </Row>
        {#each b.archives as a (a.file)}
          <Row label={a.container} value={mountText(a.mount)} sub={fmtBytes(a.bytes)} />
        {/each}
        {#each b.skipped as s (s.container + s.mount.destination)}
          <Row
            label={s.container}
            value={mountText(s.mount)}
            sub={s.why === 'system' ? $LL.containerBackupSkippedSystem() : s.why === 'shared' ? $LL.containerBackupSkippedShared() : $LL.containerBackupSkippedFile()}
          />
        {/each}
        <div class="flex justify-end gap-[9px] px-[13px] py-[9px]">
          <Button size="sm" variant="ghost" disabled={job?.state === 'running'} onclick={() => (asking = { backup: b, restore: false })}>
            {$LL.containerBackupRemove()}
          </Button>
          <Button size="sm" variant="secondary" icon="settings_backup_restore" disabled={job?.state === 'running'} onclick={() => (asking = { backup: b, restore: true })}>
            {$LL.containerBackupRestore()}
          </Button>
        </div>
      </Group>
    {/each}
  {/if}
</div>

{#if editing}
  <Dialog open title={$LL.containerBackupWhere()} onclose={() => (editing = false)}>
    <div class="space-y-[9px] text-left">
      {#if mounts.length}
        <Select
          label={$LL.containerBackupDisk()}
          value={mounts.some((m) => m.path === draftDestination) ? draftDestination : ''}
          options={[{ value: '', label: $LL.containerBackupDefaultFolder() }, ...mounts.map((m) => ({ value: m.path, label: m.free != null ? `${m.path} · ${fmtBytes(m.free)}` : m.path }))]}
          onchange={(e: Event) => (draftDestination = (e.currentTarget as HTMLSelectElement).value)}
        />
      {/if}
      <Input label={$LL.containerBackupFolder()} mono value={draftDestination} placeholder={$LL.containerBackupDefaultFolder()} oninput={(e: Event) => (draftDestination = (e.currentTarget as HTMLInputElement).value)} />
      <Input label={$LL.containerBackupKeep()} type="number" value={draftKeep} oninput={(e: Event) => (draftKeep = (e.currentTarget as HTMLInputElement).value)} />
      <p class="text-[12px] text-(--text-tertiary)">{$LL.containerBackupWhereHint()}</p>
      {#if settingsError}<p class="text-[13px] text-(--color-danger)">{settingsError}</p>{/if}
    </div>
    {#snippet actions()}
      <Button block onclick={() => void saveSettings()}>{$LL.save()}</Button>
      <Button variant="secondary" block onclick={() => (editing = false)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

<ReauthDialog
  open={!!asking}
  message={asking?.restore ? $LL.containerBackupRestoreReauth({ label: asking.backup.label }) : $LL.containerBackupRemoveReauth({ label: asking?.backup.label ?? '' })}
  onconfirm={confirm}
  onclose={() => (asking = null)}
/>
