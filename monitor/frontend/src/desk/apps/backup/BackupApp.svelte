<script lang="ts">
  import { Badge, Button, Card, Dialog, Icon, IconButton, Spinner } from '../../lk'
  import { api } from '../../../lib/api'
  import { APP_BACKUP_NAME, backupRefusalText, validBackupName } from '../../../lib/backup'
  import { fmtBytes, fmtTime } from '../../../lib/format'
  import { saveBlob } from '../../../lib/saveBlob'
  import { servers } from '../../../lib/servers.svelte'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { BackupBlob, BackupView } from '../../../types'
  import AppToolbar from '../../ui/AppToolbar.svelte'

  /// The backups the agent hosts: the app's sync file, and whatever was
  /// uploaded here. The panel moves the bytes and never opens them — they are
  /// encrypted with a password only the app knows.

  let view = $state<BackupView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let notice = $state('')
  /// The name an action is running on.
  let busy = $state('')
  /// The blob waiting for its removal to be confirmed.
  let removing = $state<BackupBlob | null>(null)
  let uploadInput = $state<HTMLInputElement | undefined>(undefined)

  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getBackups()
      if (stale(serverId)) return
      view = next
    } catch (e) {
      if (stale(serverId)) return
      error = backupRefusalText(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  /// Runs one action on `name`, after clearing what the last one said.
  async function act(name: string, run: () => Promise<string | void>) {
    busy = name
    error = ''
    notice = ''
    try {
      notice = (await run()) ?? ''
    } catch (e) {
      error = backupRefusalText(e)
    } finally {
      busy = ''
    }
  }

  function download(entry: BackupBlob) {
    void act(entry.name, async () => saveBlob(await api.downloadBackup(entry.name), entry.name))
  }

  function onUpload(event: Event) {
    const input = event.currentTarget as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (!file || !view) return
    notice = ''
    if (!validBackupName(file.name)) {
      error = $LL.backupInvalidName()
      return
    }
    if (file.size > view.max_bytes) {
      error = $LL.backupTooLarge({ size: fmtBytes(file.size), max: fmtBytes(view.max_bytes) })
      return
    }
    void act(file.name, async () => {
      await api.uploadBackup(file.name, file)
      await load()
      return $LL.backupStored({ name: file.name })
    })
  }

  function remove(entry: BackupBlob) {
    void act(entry.name, async () => {
      await api.deleteBackup(entry.name)
      removing = null
      await load()
      return $LL.backupRemoved({ name: entry.name })
    })
  }

  const blobs = $derived(view?.blobs ?? [])
  const storedBytes = $derived(blobs.reduce((total, entry) => total + entry.size, 0))
</script>

<div class="flex h-full min-h-0 flex-col">
  <AppToolbar
    subtitle={view ? $LL.backupSubtitle({ count: blobs.length, max: fmtBytes(view.max_bytes) }) : undefined}
  >
    {#snippet actions()}
      <IconButton icon="upload" label={$LL.backupUpload()} disabled={!view} onclick={() => uploadInput?.click()} />
      <IconButton icon="refresh" label={$LL.refresh()} disabled={loading} onclick={() => void load()} />
    {/snippet}
  </AppToolbar>

  <input type="file" class="hidden" bind:this={uploadInput} onchange={onUpload} />

<div class="min-h-0 flex-1 overflow-auto">
  <main class="mx-auto w-full max-w-3xl space-y-[13px] px-[17px] pb-[17px] pt-[4px]">
    {#if error}
      <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
        <Icon name="error" size={17} />
        <p>{error}</p>
      </Card>
    {/if}
    {#if notice}
      <Card class="text-[13px] text-(--text-secondary)">{notice}</Card>
    {/if}

    <Card class="space-y-[7px]">
      <div class="flex items-center gap-[7px]">
        <Icon name="info" size={17} class="shrink-0 text-(--text-secondary)" />
        <p class="text-[15px] font-semibold text-(--text-primary)">{$LL.backupHowItWorks()}</p>
      </div>
      <p class="text-[13px] leading-relaxed text-(--text-secondary)">{$LL.backupWhatItIs()}</p>
    </Card>

    {#if loading && !view}
      <Card><Spinner size={20} /></Card>
    {:else if view}
      <section class="space-y-3">
        <div class="grid grid-cols-1 gap-[9px] @2xl:grid-cols-3">
          <Card variant="raised" class="space-y-[5px]">
            <p class="text-[12px] text-(--text-secondary)">{$LL.backupStoredFiles()}</p>
            <p class="lk-num text-[21px] font-semibold text-(--text-primary)">{blobs.length}</p>
          </Card>
          <Card variant="raised" class="space-y-[5px]">
            <p class="text-[12px] text-(--text-secondary)">{$LL.backupTotalSize()}</p>
            <p class="lk-num text-[21px] font-semibold text-(--text-primary)">{fmtBytes(storedBytes)}</p>
          </Card>
          <Card variant="raised" class="space-y-[5px]">
            <p class="text-[12px] text-(--text-secondary)">{$LL.backupPerFileLimit()}</p>
            <p class="lk-num text-[21px] font-semibold text-(--text-primary)">{fmtBytes(view.max_bytes)}</p>
          </Card>
        </div>
        <div class="flex items-center justify-between gap-[7px]">
          <h3 class="text-[15px] font-semibold text-(--text-primary)">{$LL.backupStoredFiles()}</h3>
          <Badge tone="neutral">{blobs.length}</Badge>
        </div>
        {#if blobs.length === 0}
          <div class="flex min-h-48 flex-col items-center justify-center gap-[9px]">
            <Icon name="backup" size={48} weight={300} color="var(--text-tertiary)" />
            <p class="text-[13px] text-(--text-secondary)">{$LL.backupEmptyState()}</p>
          </div>
        {:else}
          <div class="overflow-hidden rounded-[13px] bg-(--surface-card)">
            {#each blobs as entry (entry.name)}
              <div class="flex min-h-11 items-center gap-[13px] border-b border-(--border-hairline) px-[13px] py-[7px] last:border-b-0 hover:bg-(--fill-hover)">
                <span class="grid h-[34px] w-[34px] shrink-0 place-items-center rounded-[9px] bg-(--surface-content) text-(--color-accent) shadow-[inset_0_0_0_.5px_var(--border-hairline)]">
                  <Icon name="inventory_2" size={18} />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-[13px] font-semibold text-(--text-primary)" title={entry.name}>
                    {entry.name}
                  </p>
                  <p class="text-[12px] text-(--text-tertiary)">
                    {fmtBytes(entry.size)} · {fmtTime(entry.updated_at, { withDate: true })}
                  </p>
                </div>
                {#if entry.name === APP_BACKUP_NAME}
                  <Badge tone="neutral">{$LL.backupAppFile()}</Badge>
                {/if}
                {#if busy === entry.name}
                  <Spinner size={16} />
                {/if}
                <div class="flex shrink-0">
                  <IconButton icon="download" label={$LL.filesDownload()} disabled={busy !== ''} onclick={() => download(entry)} />
                  <IconButton icon="delete" label={$LL.filesDelete()} disabled={busy !== ''} onclick={() => (removing = entry)} />
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </section>
    {/if}
  </main>
  </div>
</div>

{#if removing}
  {@const target = removing}
  <Dialog open title={$LL.filesDelete()} message={$LL.backupConfirmRemove({ name: target.name })} onclose={() => (removing = null)}>
    {#snippet actions()}
      <Button variant="destructive" icon="delete" disabled={busy !== ''} onclick={() => remove(target)}>{$LL.filesDelete()}</Button>
      <Button variant="secondary" onclick={() => (removing = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}
