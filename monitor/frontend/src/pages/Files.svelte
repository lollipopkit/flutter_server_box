<script lang="ts">
  import {
    ArrowUp,
    Download,
    File as FileIcon,
    Folder,
    FolderPlus,
    Link2,
    Pencil,
    Shield,
    Trash2,
    Upload,
  } from '@lucide/svelte'
  import { Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import PageHeader from '../components/PageHeader.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { api } from '../lib/api'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { fmtBytes } from '../lib/format'
  import { joinPath, modeText, parentOf, parseMode, sortEntries } from '../lib/fsPath'
  import { layout } from '../lib/layout.svelte'
  import { servers } from '../lib/servers.svelte'
  import type { FsEntry } from '../types'

  /// `!== false` rather than `=== true`: an agent predating the field reports
  /// nothing, and refusing to show the page for it would be reading silence as
  /// a denial. The agent is the one that decides in the end — every request is
  /// resolved against its roots.
  const available = $derived(
    capabilitiesStore.byServer[servers.currentId]?.remote_access?.files !== false,
  )

  let roots = $state<string[]>([])
  /// Null until the roots have been read, which is what decides where the page
  /// opens: there is no `/` to fall back on, because anything outside a root is
  /// refused.
  let cwd = $state<string | null>(null)
  let entries = $state<FsEntry[]>([])
  let loading = $state(false)
  let error = $state('')
  let busy = $state('')

  /// Which agent the answer being awaited belongs to.
  ///
  /// The sidebar can be clicked while a listing is in flight, and a path means
  /// nothing on another machine: publishing what arrives late would put one
  /// agent's tree under another's name, with a `cwd` its roots may not even
  /// contain. Every write to the page's state is behind this check.
  function stale(serverId: string): boolean {
    return servers.currentId !== serverId
  }

  async function load(path: string, serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const listed = sortEntries(await api.fsList(path))
      if (stale(serverId)) return
      entries = listed
      cwd = path
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  async function start(serverId: string) {
    loading = true
    error = ''
    // Cleared rather than left showing the previous agent's tree while this
    // one is being read.
    entries = []
    cwd = null
    try {
      const res = await api.fsRoots()
      if (stale(serverId)) return
      roots = res.roots
      if (roots.length === 0) {
        loading = false
        return
      }
      await load(roots[0], serverId)
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
      loading = false
    }
  }

  $effect(() => {
    // Read into the call rather than as a bare expression: the dependency is
    // what makes this rerun when the sidebar selection changes, and the value
    // is what the run then checks itself against.
    void start(servers.currentId)
  })

  async function act(what: string, fn: () => Promise<unknown>) {
    busy = what
    error = ''
    try {
      await fn()
      if (cwd) await load(cwd)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = ''
    }
  }

  async function download(entry: FsEntry) {
    if (!cwd) return
    await act(entry.name, async () => {
      const blob = await api.fsRead(joinPath(cwd!, entry.name))
      // The token cannot ride an `<a download>`, so the bytes are fetched and
      // handed over from memory. Revoked on the next tick, once the click has
      // been dispatched.
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = entry.name
      a.click()
      setTimeout(() => URL.revokeObjectURL(url), 0)
    })
  }

  let uploadInput = $state<HTMLInputElement | undefined>(undefined)

  async function onUpload(event: Event) {
    const input = event.target as HTMLInputElement
    const file = input.files?.[0]
    // Cleared first: picking the same file twice in a row fires no `change`
    // otherwise, so a failed upload could not be retried.
    input.value = ''
    if (!file || !cwd) return
    await act($LL.filesUploading(), () => api.fsWrite(joinPath(cwd!, file.name), file))
  }

  /// The one open dialog, if any. One piece of state rather than four booleans:
  /// the dialogs are mutually exclusive and each carries the entry it is about.
  let dialog = $state<
    | { kind: 'mkdir'; value: string }
    | { kind: 'rename'; entry: FsEntry; value: string }
    | { kind: 'chmod'; entry: FsEntry; value: string }
    | { kind: 'delete'; entry: FsEntry }
    | null
  >(null)

  async function submitDialog() {
    const d = dialog
    if (!d || !cwd) return
    dialog = null
    switch (d.kind) {
      case 'mkdir':
        if (d.value.trim() === '') return
        await act(d.value, () => api.fsMkdir(joinPath(cwd!, d.value.trim())))
        return
      case 'rename':
        if (d.value.trim() === '') return
        await act(d.entry.name, () =>
          api.fsRename(joinPath(cwd!, d.entry.name), joinPath(cwd!, d.value.trim())),
        )
        return
      case 'chmod': {
        const mode = parseMode(d.value)
        if (mode === null) return
        await act(d.entry.name, () => api.fsChmod(joinPath(cwd!, d.entry.name), mode))
        return
      }
      case 'delete':
        await act(d.entry.name, () =>
          api.fsRemove(joinPath(cwd!, d.entry.name), d.entry.kind === 'dir'),
        )
        return
    }
  }

  function iconOf(entry: FsEntry) {
    if (entry.kind === 'dir') return Folder
    if (entry.kind === 'link') return Link2
    return FileIcon
  }

  function modifiedOf(entry: FsEntry): string {
    // Seconds since the epoch, as the agent reports them.
    return entry.modified === null
      ? ''
      : new Date(entry.modified * 1000).toLocaleString()
  }

  const parent = $derived(cwd === null ? null : parentOf(cwd, roots))
</script>

<PageHeader
  title={$LL.files()}
  containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  onback={() => layout.back('dashboard')}
>
  {#snippet actions()}
    {#if available && cwd}
      <IconButton label={$LL.filesNewFolder()} onclick={() => (dialog = { kind: 'mkdir', value: '' })}>
        <FolderPlus class="w-4 h-4" />
      </IconButton>
      <IconButton label={$LL.filesUpload()} onclick={() => uploadInput?.click()}>
        <Upload class="w-4 h-4" />
      </IconButton>
    {/if}
  {/snippet}
</PageHeader>

<input type="file" class="hidden" bind:this={uploadInput} onchange={onUpload} />

<main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-4">
  {#if !available}
    <Card>
      <p class="text-sm text-muted-fg">{$LL.filesUnavailable()}</p>
    </Card>
  {:else}
    {#if roots.length > 1}
      <div class="flex flex-wrap gap-2">
        <span class="text-sm text-muted-fg self-center">{$LL.filesRoots()}</span>
        {#each roots as root (root)}
          <Button
            size="sm"
            variant={cwd === root ? 'primary' : 'secondary'}
            onclick={() => load(root)}
          >
            {root}
          </Button>
        {/each}
      </div>
    {/if}

    {#if cwd}
      <div class="flex items-center gap-2">
        {#if parent}
          <IconButton label={$LL.back()} onclick={() => load(parent)}>
            <ArrowUp class="w-4 h-4" />
          </IconButton>
        {/if}
        <code class="text-sm text-muted-fg break-all">{cwd}</code>
        {#if busy}<Spinner class="w-4 h-4" />{/if}
      </div>
    {/if}

    {#if error}
      <Card class="border-danger/40 bg-danger/5">
        <p class="text-sm text-danger">{error}</p>
      </Card>
    {/if}

    {#if loading}
      <Card><Spinner class="w-5 h-5" /></Card>
    {:else if cwd && entries.length === 0}
      <Card><p class="text-sm text-muted-fg">{$LL.filesEmpty()}</p></Card>
    {:else if cwd}
      <Card class="divide-y divide-border p-0">
        {#each entries as entry (entry.name)}
          {@const Icon = iconOf(entry)}
          <div class="flex items-center gap-3 px-4 py-2">
            <Icon class="w-4 h-4 shrink-0 text-muted-fg" />
            {#if entry.kind === 'dir'}
              <button
                class="flex-1 min-w-0 text-left text-sm hover:underline truncate"
                onclick={() => load(joinPath(cwd!, entry.name))}
              >
                {entry.name}
              </button>
            {:else}
              <span class="flex-1 min-w-0 text-sm truncate" title={entry.link_target ?? undefined}>
                {entry.name}
              </span>
            {/if}
            <span class="hidden sm:block text-xs text-muted-fg shrink-0 w-20 text-right">
              {entry.kind === 'file' && entry.size !== null ? fmtBytes(entry.size) : ''}
            </span>
            <span class="hidden lg:block text-xs text-muted-fg shrink-0 w-40 text-right">
              {modifiedOf(entry)}
            </span>
            <span class="hidden sm:block text-xs text-muted-fg shrink-0 w-10 text-right font-mono">
              {modeText(entry.mode)}
            </span>
            <div class="flex shrink-0">
              {#if entry.kind !== 'dir'}
                <IconButton label={$LL.filesDownload()} onclick={() => download(entry)}>
                  <Download class="w-4 h-4" />
                </IconButton>
              {/if}
              <IconButton
                label={$LL.filesRename()}
                onclick={() => (dialog = { kind: 'rename', entry, value: entry.name })}
              >
                <Pencil class="w-4 h-4" />
              </IconButton>
              <IconButton
                label={$LL.filesPermissions()}
                onclick={() => (dialog = { kind: 'chmod', entry, value: modeText(entry.mode) })}
              >
                <Shield class="w-4 h-4" />
              </IconButton>
              <IconButton
                label={$LL.filesDelete()}
                onclick={() => (dialog = { kind: 'delete', entry })}
              >
                <Trash2 class="w-4 h-4" />
              </IconButton>
            </div>
          </div>
        {/each}
      </Card>
    {/if}
  {/if}
</main>

{#if dialog}
  <Modal
    open
    title={dialog.kind === 'mkdir'
      ? $LL.filesNewFolder()
      : dialog.kind === 'rename'
        ? $LL.filesRename()
        : dialog.kind === 'chmod'
          ? $LL.filesPermissions()
          : $LL.filesDelete()}
    onclose={() => (dialog = null)}
  >
    <div class="space-y-3">
      {#if dialog.kind === 'delete'}
        <p class="text-sm text-fg-strong break-all">{dialog.entry.name}</p>
        <p class="text-sm text-muted-fg">
          {dialog.entry.kind === 'dir' ? $LL.filesDeleteRecursive() : $LL.filesConfirmDelete()}
        </p>
      {:else if dialog.kind === 'chmod'}
        <div class="space-y-1">
          <label class="text-sm text-muted-fg" for="fs-mode">{$LL.filesPermissions()}</label>
          <Input id="fs-mode" bind:value={dialog.value} placeholder="644" />
        </div>
      {:else}
        <div class="space-y-1">
          <label class="text-sm text-muted-fg" for="fs-name">{$LL.filesName()}</label>
          <Input id="fs-name" bind:value={dialog.value} />
        </div>
      {/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (dialog = null)}>{$LL.cancel()}</Button>
        <Button
          variant={dialog.kind === 'delete' ? 'danger' : 'primary'}
          onclick={submitDialog}
        >
          {dialog.kind === 'delete' ? $LL.filesDelete() : $LL.save()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}
