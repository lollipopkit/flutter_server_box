<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import { Archive, Download, Info, RefreshCw, Trash2, Upload } from '@lucide/svelte'
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
      <IconButton label={$LL.backupUpload()} disabled={!view} onclick={() => uploadInput?.click()}>
        <Upload class="w-4 h-4" />
      </IconButton>
      <IconButton label={$LL.refresh()} disabled={loading} onclick={() => void load()}>
        <RefreshCw class="w-4 h-4" />
      </IconButton>
    {/snippet}
  </AppToolbar>

  <input type="file" class="hidden" bind:this={uploadInput} onchange={onUpload} />

<div class="min-h-0 flex-1 overflow-auto">
  <main class="mx-auto w-full max-w-3xl space-y-4 px-4 py-4 @3xl:px-6">
    {#if error}
      <Card class="border-danger/40 bg-danger/5">
        <p class="text-sm text-danger">{error}</p>
      </Card>
    {/if}
    {#if notice}
      <Card>
        <p class="text-sm text-muted-fg">{notice}</p>
      </Card>
    {/if}

    <Card class="space-y-2">
      <div class="flex items-center gap-2">
        <Info class="h-4 w-4 shrink-0 text-muted-fg" />
        <p class="text-[0.95rem] font-semibold text-fg-strong">{$LL.backupHowItWorks()}</p>
      </div>
      <p class="text-xs leading-relaxed text-muted-fg">{$LL.backupWhatItIs()}</p>
    </Card>

    {#if loading && !view}
      <Card><Spinner class="w-5 h-5" /></Card>
    {:else if view}
      <section class="space-y-3">
        <div class="grid grid-cols-1 gap-2 @2xl:grid-cols-3">
          <Card class="space-y-1 rounded-xl border border-line bg-surface p-3">
            <p class="text-xs text-muted-fg">{$LL.backupStoredFiles()}</p>
            <p class="text-xl font-semibold tabular-nums text-fg-strong">{blobs.length}</p>
          </Card>
          <Card class="space-y-1 rounded-xl border border-line bg-surface p-3">
            <p class="text-xs text-muted-fg">{$LL.backupTotalSize()}</p>
            <p class="text-xl font-semibold tabular-nums text-fg-strong">{fmtBytes(storedBytes)}</p>
          </Card>
          <Card class="space-y-1 rounded-xl border border-line bg-surface p-3">
            <p class="text-xs text-muted-fg">{$LL.backupPerFileLimit()}</p>
            <p class="text-xl font-semibold tabular-nums text-fg-strong">{fmtBytes(view.max_bytes)}</p>
          </Card>
        </div>
        <div class="flex items-center justify-between gap-2 px-1">
          <h3 class="text-[0.95rem] font-semibold text-fg-strong">{$LL.backupStoredFiles()}</h3>
          <Badge tone="neutral">{blobs.length}</Badge>
        </div>
        {#if blobs.length === 0}
          <Card>
            <p class="text-sm text-muted-fg">{$LL.backupEmpty()}</p>
          </Card>
        {:else}
          <div class="overflow-hidden rounded-xl border border-line bg-surface">
            {#each blobs as entry (entry.name)}
              <div class="flex items-center gap-3 border-b border-line px-3 py-2.5 last:border-b-0 hover:bg-soft">
                <span class="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-soft text-muted-fg">
                  <Archive class="h-4 w-4" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-[0.8rem] font-medium text-fg-strong" title={entry.name}>
                    {entry.name}
                  </p>
                  <p class="text-xs text-muted-fg">
                    {fmtBytes(entry.size)} · {fmtTime(entry.updated_at, { withDate: true })}
                  </p>
                </div>
                {#if entry.name === APP_BACKUP_NAME}
                  <Badge tone="neutral">{$LL.backupAppFile()}</Badge>
                {/if}
                {#if busy === entry.name}
                  <Spinner size="sm" />
                {/if}
                <div class="flex shrink-0">
                  <IconButton label={$LL.filesDownload()} disabled={busy !== ''} onclick={() => download(entry)}>
                    <Download class="w-4 h-4" />
                  </IconButton>
                  <IconButton label={$LL.filesDelete()} disabled={busy !== ''} onclick={() => (removing = entry)}>
                    <Trash2 class="w-4 h-4" />
                  </IconButton>
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
  <Modal open title={$LL.filesDelete()} onclose={() => (removing = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.backupConfirmRemove({ name: target.name })}</p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (removing = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy !== ''} onclick={() => remove(target)}>
          {$LL.filesDelete()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}
