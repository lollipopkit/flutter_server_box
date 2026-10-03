<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import { Download, RefreshCw, Trash2, Upload } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { api } from '../lib/api'
  import { APP_BACKUP_NAME, backupRefusalText, validBackupName } from '../lib/backup'
  import { fmtBytes, fmtTime } from '../lib/format'
  import { saveBlob } from '../lib/saveBlob'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { BackupBlob, BackupView } from '../types'

  /// The backups the agent hosts: the app's sync file, and whatever was
  /// uploaded here. The panel moves the bytes and never opens them — they are
  /// encrypted with a password only the app knows.
  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

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
</script>

<PageHeader
  title={$LL.backup()}
  subtitle={view ? $LL.backupSubtitle({ count: blobs.length, max: fmtBytes(view.max_bytes) }) : undefined}
  containerClass="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet tabs()}
    <FeatureTabs active="backup" />
  {/snippet}

  {#snippet actions()}
    <IconButton label={$LL.backupUpload()} disabled={!view} onclick={() => uploadInput?.click()}>
      <Upload class="w-4 h-4" />
    </IconButton>
    <IconButton label={$LL.refresh()} disabled={loading} onclick={() => void load()}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<input type="file" class="hidden" bind:this={uploadInput} onchange={onUpload} />

<main class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
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

  <p class="text-sm text-muted-fg">{$LL.backupWhatItIs()}</p>

  {#if loading && !view}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if view}
    {#if blobs.length === 0}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.backupEmpty()}</p>
      </Card>
    {:else}
      <Card class="divide-y divide-line p-0">
        {#each blobs as entry (entry.name)}
          <div class="flex items-center gap-3 px-4 py-3">
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-medium text-fg-strong" title={entry.name}>{entry.name}</p>
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
      </Card>
    {/if}
  {/if}
</main>

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
