<script lang="ts">
  /// The Containers app's backups (`/container-backups`, admin): each one's
  /// containers, what it archived and left out, to restore or remove; and
  /// the backup or restore running, as it goes.

  import { Badge, Button, Card, Group, Icon, Row, Spinner } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import ReauthDialog from '../../../components/ReauthDialog.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import { DATE_TIME, fmtBytes, fmtDate } from '../../../lib/format'
  import { servers } from '../../../lib/servers.svelte'
  import type { ContainerBackup, ContainerMount, StackJob } from '../../../types'
  import { untrack } from 'svelte'

  interface Props {
    /// A job just started here (a backup from a container's row).
    started?: StackJob | null
  }

  const { started = null }: Props = $props()

  let backups = $state<ContainerBackup[] | null>(null)
  let job = $state<StackJob | null>(untrack(() => started))
  let error = $state('')
  /// The backup whose restore or removal asks the password.
  let asking = $state<{ backup: ContainerBackup; restore: boolean } | null>(null)

  async function load(serverId = servers.currentId) {
    try {
      const r = await api.listContainerBackups()
      if (serverId !== servers.currentId) return
      backups = r.backups
      if (r.job?.state === 'running') job = r.job
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
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
      error = code === 'busy' ? $LL.containerBackupBusy() : e instanceof Error ? e.message : String(e)
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
            sub={s.why === 'system' ? $LL.containerBackupSkippedSystem() : $LL.containerBackupSkippedFile()}
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

<ReauthDialog
  open={!!asking}
  message={asking?.restore ? $LL.containerBackupRestoreReauth({ label: asking.backup.label }) : $LL.containerBackupRemoveReauth({ label: asking?.backup.label ?? '' })}
  onconfirm={confirm}
  onclose={() => (asking = null)}
/>
