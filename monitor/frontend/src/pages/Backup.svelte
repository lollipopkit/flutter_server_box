<script module lang="ts">
  /// The name a chosen file is stored under: the file's own, unchanged.
  ///
  /// Not sanitised and not renamed. The app syncs `srvbox_bak_v3.json` and reads
  /// back what it wrote, so a store that renamed an upload would leave the app
  /// asking for a name that never appears. What the agent cannot address it
  /// refuses, and a refused name is the operator's to fix rather than this
  /// panel's to rewrite into something they did not choose.
  export function storedName(fileName: string): string {
    return fileName
  }

  /// Whether a file is larger than this agent will take, or `false` when it
  /// fits.
  ///
  /// The boundary is `>` and not `>=`: the agent's cap is a maximum, so a file
  /// exactly at it is one it accepts, and a page that refused it would be
  /// stricter than the endpoint it is guarding.
  export function tooLarge(size: number, maxBytes: number): boolean {
    return size > maxBytes
  }
</script>

<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import {
    Download,
    FileCog,
    RefreshCw,
    Trash2,
    Upload,
  } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { api } from '../lib/api'
  import { fmtBytes } from '../lib/format'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { BackupBlob, BackupListView } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let view = $state<BackupListView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let notice = $state('')
  /// The blob waiting for a confirmation. Removing one cannot be undone from
  /// here — the panel has no key for what is in it — so it is asked once.
  let removing = $state<BackupBlob | null>(null)
  let busy = $state('')
  let configBusy = $state('')

  let uploadInput = $state<HTMLInputElement | undefined>(undefined)
  let importInput = $state<HTMLInputElement | undefined>(undefined)

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId: string | null = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getBackups()
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
    // Only the machine on screen re-runs this.
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  /// Hands the browser bytes it fetched itself.
  ///
  /// The token cannot ride an `<a download>`, so the bytes come back through
  /// the API client and are handed over from memory. Revoked on the next tick,
  /// once the click has been dispatched.
  function save(blob: Blob, name: string) {
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = name
    a.click()
    setTimeout(() => URL.revokeObjectURL(url), 0)
  }

  /// Clears what the last action said, before this one says anything.
  ///
  /// Both cards render from the same block, and each action used to clear only
  /// the error — so a refused upload showed its own failure underneath the
  /// success line about the upload before it, and nothing said which belonged
  /// to what.
  function said() {
    error = ''
    notice = ''
  }

  async function download(entry: BackupBlob) {
    busy = entry.name
    said()
    try {
      save(await api.downloadBackup(entry.name), entry.name)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = ''
    }
  }

  async function onUpload(event: Event) {
    const input = event.currentTarget as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (!file) return

    if (view && tooLarge(file.size, view.max_bytes)) {
      // Said before the upload rather than after it is refused, and with both
      // numbers: the agent's cap is the one that decides.
      error = $LL.backupTooLarge({ size: fmtBytes(file.size), max: fmtBytes(view.max_bytes) })
      return
    }
    const name = storedName(file.name)
    busy = name
    said()
    try {
      await api.uploadBackup(name, file)
      notice = $LL.backupStored({ name })
      await load()
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = ''
    }
  }

  async function remove(entry: BackupBlob) {
    busy = entry.name
    said()
    try {
      await api.deleteBackup(entry.name)
      removing = null
      notice = $LL.backupRemoved({ name: entry.name })
      await load()
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = ''
    }
  }

  async function exportConfig() {
    configBusy = 'export'
    said()
    try {
      save(await api.exportAgentConfig(), 'config.toml')
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      configBusy = ''
    }
  }

  async function onImport(event: Event) {
    const input = event.currentTarget as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (!file) return

    configBusy = 'import'
    said()
    try {
      await api.importAgentConfig(file)
      // The agent answers `restart_required`, and it always is: its running
      // configuration is a snapshot taken at startup, so the operator is told
      // the one thing a browser cannot see.
      notice = $LL.backupImported()
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      configBusy = ''
    }
  }

  const blobs = $derived(view?.blobs ?? [])
  const editable = $derived(view?.editable === true)

  /// The timestamp the agent read off the file, shown as the operator's own
  /// clock. It is RFC 3339 with an offset, so the browser's parse is exact.
  function at(when: string): string {
    if (!when) return ''
    const parsed = new Date(when)
    return Number.isNaN(parsed.getTime()) ? when : parsed.toLocaleString()
  }
</script>

<PageHeader
  title={$LL.backup()}
  subtitle={view
    ? $LL.backupSubtitle({ count: blobs.length, max: fmtBytes(view.max_bytes) })
    : undefined}
  containerClass="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet tabs()}
    <FeatureTabs active="backup" />
  {/snippet}

  {#snippet actions()}
    {#if editable}
      <IconButton label={$LL.backupStore()} onclick={() => uploadInput?.click()}>
        <Upload class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} disabled={loading} onclick={() => void load()}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<input type="file" class="hidden" bind:this={uploadInput} onchange={onUpload} />
<input type="file" accept=".toml,text/plain" class="hidden" bind:this={importInput} onchange={onImport} />

<main class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
  {#if error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}
  {#if notice}
    <Card class="border-success/40 bg-success/5">
      <p class="text-sm text-success">{notice}</p>
    </Card>
  {/if}

  <Card class="space-y-2">
    <p class="text-sm text-muted-fg">{$LL.backupWhatItIs()}</p>
  </Card>

  {#if !editable}
    <Card class="space-y-1">
      <p class="text-sm text-muted-fg">{$LL.backupReadOnly()}</p>
    </Card>
  {/if}

  {#if loading && !view}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if view}
    {#if blobs.length === 0}
      <Card class="space-y-3">
        <p class="text-sm text-muted-fg">{$LL.backupEmpty()}</p>
        {#if editable}
          <Button onclick={() => uploadInput?.click()}>{$LL.backupStore()}</Button>
        {/if}
      </Card>
    {:else}
      <Card class="divide-y divide-border p-0">
        {#each blobs as entry (entry.name)}
          <div class="flex items-center gap-3 px-4 py-3">
            <div class="flex-1 min-w-0">
              <p class="truncate text-sm font-medium" title={entry.name}>{entry.name}</p>
              <p class="text-xs text-muted-fg">{fmtBytes(entry.size)} · {at(entry.updated_at)}</p>
            </div>
            {#if entry.name === 'srvbox_bak_v3.json'}
              <!-- The name the app syncs. Worth saying, because every other
                   name in here is one an operator uploaded by hand. -->
              <Badge tone="neutral">{$LL.backupAppFile()}</Badge>
            {/if}
            {#if busy === entry.name}
              <Spinner size="sm" />
            {/if}
            <div class="flex shrink-0">
              <IconButton label={$LL.filesDownload()} disabled={busy === entry.name} onclick={() => void download(entry)}>
                <Download class="w-4 h-4" />
              </IconButton>
              {#if editable}
                <IconButton label={$LL.filesDelete()} disabled={busy === entry.name} onclick={() => (removing = entry)}>
                  <Trash2 class="w-4 h-4" />
                </IconButton>
              {/if}
            </div>
          </div>
        {/each}
      </Card>
    {/if}

    <Card class="space-y-3">
      <div class="flex items-center gap-2">
        <FileCog class="h-4 w-4 shrink-0 text-muted-fg" />
        <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.backupAgentConfig()}</h2>
      </div>
      <p class="text-sm text-muted-fg">{$LL.backupAgentConfigNote()}</p>
      {#if editable}
        <div class="flex flex-wrap gap-2">
          <Button variant="secondary" size="sm" disabled={configBusy === 'export'} onclick={() => void exportConfig()}>
            {$LL.backupExport()}
          </Button>
          <Button variant="secondary" size="sm" disabled={configBusy === 'import'} onclick={() => importInput?.click()}>
            {$LL.backupImport()}
          </Button>
        </div>
      {:else}
        <p class="text-xs text-muted-fg">{$LL.backupAgentConfigNeedsGrant()}</p>
      {/if}
    </Card>
  {/if}
</main>

{#if removing}
  <Modal open title={$LL.filesDelete()} onclose={() => (removing = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.backupConfirmRemove({ name: removing.name })}</p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (removing = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy === removing.name} onclick={() => void remove(removing!)}>
          {$LL.filesDelete()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}
