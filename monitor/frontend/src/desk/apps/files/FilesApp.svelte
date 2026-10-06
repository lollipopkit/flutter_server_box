<script lang="ts">
  import {
    ArrowLeft,
    ArrowRight,
    ArrowUp,
    ChevronRight,
    Download,
    Ellipsis,
    File as FileIcon,
    FilePenLine,
    Folder,
    FolderPlus,
    LayoutGrid,
    Link2,
    List,
    MonitorUp,
    Pencil,
    Shield,
    Trash2,
    Upload,
  } from '@lucide/svelte'
  import { Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import FileEditor from './FileEditor.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import SourceGroup from '../../ui/SourceGroup.svelte'
  import SourceItem from '../../ui/SourceItem.svelte'
  import SplitView from '../../ui/SplitView.svelte'
  import { useWindow } from '../../deskState.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { filesAccess, whyText } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import { saveBlob } from '../../../lib/saveBlob'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { fmtBytes } from '../../../lib/format'
  import { joinPath, modeText, parentOf, parseMode, sortEntries } from '../../../lib/fsPath'
  import { servers } from '../../../lib/servers.svelte'
  import type { FsEntry } from '../../../types'

  /// An agent that says nothing is not read as a refusal — see `filesAccess`.
  /// The agent decides in the end: every request is resolved against its
  /// roots, and a write against the caller's role.
  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  const access = $derived(filesAccess(caps))
  const available = $derived(access.available)
  /// Upload, new folder, rename, chmod, delete — absent for a read-only role
  /// rather than offered and refused.
  const write = $derived(access.write)

  /// 1 MiB, mirroring `Miscs.editorMaxSize` in the app
  /// (`lib/data/res/misc.dart`). Nothing in Rust holds it: the agent does not
  /// edit, so the limit is the panel's to keep.
  const EDITOR_MAX_BYTES = 1024 * 1024

  /// The desk's accent at low opacity: the fill a picked row, an active view
  /// button and the menu's hover take, as the sidebar's own rows do.
  const TINT = 'color-mix(in srgb, var(--desk-accent) 12%, transparent)'

  const win = useWindow()

  /// What this window was asked to open (Spotlight, a desk icon, another app)
  /// and how it last looked, read once: afterwards the window's own state is
  /// what it restores.
  const askedState = win.appState as { path?: unknown; view?: unknown } | null
  const asked = askedState?.path

  let roots = $state<string[]>([])
  /// Null until the roots have been read, which is what decides where the page
  /// opens: there is no `/` to fall back on, because anything outside a root is
  /// refused.
  let cwd = $state<string | null>(null)
  let entries = $state<FsEntry[]>([])
  let loading = $state(false)
  let error = $state('')
  let busy = $state('')
  /// List or grid — a per-window preference, kept beside the path.
  let view = $state<'list' | 'grid'>(askedState?.view === 'grid' ? 'grid' : 'list')
  /// The entry the pointer last landed on: the row that reads as picked.
  let selected = $state<string | null>(null)

  /// Where this window has been, as Finder keeps it: `hist[histAt]` is the
  /// directory shown, and back/forward step within it.
  let hist = $state<string[]>([])
  let histAt = $state(-1)
  const canBack = $derived(histAt > 0)
  const canForward = $derived(histAt >= 0 && histAt < hist.length - 1)

  /// The file open in the editor, with its decoded text. Set only once the
  /// read and the decode have succeeded, so the editor is never mounted over
  /// a file it could not show.
  let editing = $state<{
    entry: FsEntry
    path: string
    text: string
    /// Which machine opened it, so a save cannot land on another one.
    serverId: string
  } | null>(null)

  /// Which agent the answer being awaited belongs to.
  ///
  /// The server can be switched while a listing is in flight, and a path means
  /// nothing on another machine: publishing what arrives late would put one
  /// agent's tree under another's name, with a `cwd` its roots may not even
  /// contain. Every write to the page's state is behind this check.
  function stale(serverId: string): boolean {
    return servers.currentId !== serverId
  }

  /// [record] is false for a refresh (a write landed, back/forward moved): the
  /// history keeps the step that brought the window here rather than a copy.
  async function load(path: string, serverId = servers.currentId, record = true) {
    loading = true
    error = ''
    try {
      const listed = sortEntries(await api.fsList(path))
      if (stale(serverId)) return
      entries = listed
      cwd = path
      selected = null
      if (record) {
        hist = [...hist.slice(0, histAt + 1), path]
        histAt = hist.length - 1
      }
      win.setAppState({ path, view })
      win.setTitle(path.split('/').filter(Boolean).at(-1) ?? path)
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  function back() {
    if (!canBack) return
    histAt -= 1
    void load(hist[histAt], servers.currentId, false)
  }

  function forward() {
    if (!canForward) return
    histAt += 1
    void load(hist[histAt], servers.currentId, false)
  }

  function setView(next: 'list' | 'grid') {
    if (view === next) return
    view = next
    if (cwd) win.setAppState({ path: cwd, view })
  }

  /// Whether [path] is one of the roots or under one: anything else the agent
  /// refuses, so the window opens at the first root instead.
  function insideRoots(path: string): boolean {
    return roots.some((r) => path === r || path.startsWith(r.endsWith('/') ? r : `${r}/`))
  }

  /// A root's row in the sidebar: its last segment, which is what tells two
  /// roots apart at a glance. Two roots ending the same way (`/private/tmp`
  /// and `/var/tmp`) get enough of the parent path appended to be told apart;
  /// the row's tooltip carries the whole path either way.
  function rootLabel(root: string): string {
    const segments = root.split('/').filter(Boolean)
    const last = segments.at(-1)
    if (last === undefined) return '/'
    const twins = roots.filter((r) => r.split('/').filter(Boolean).at(-1) === last)
    if (twins.length < 2) return last
    const parents = (r: string) => r.split('/').filter(Boolean).slice(0, -1)
    for (let n = 1; n < segments.length; n++) {
      const tail = parents(root).slice(-n).join('/')
      const unique = twins.every(
        (r) => r === root || parents(r).slice(-n).join('/') !== tail,
      )
      // A root that is a single segment has no parent to show, so its whole
      // path stands in.
      if (unique) return `${last} — /${tail || segments.join('/')}`
    }
    return root
  }

  async function start(serverId: string) {
    loading = true
    error = ''
    // Cleared rather than left showing the previous agent's tree while this
    // one is being read.
    entries = []
    cwd = null
    hist = []
    histAt = -1
    try {
      const res = await api.fsRoots()
      if (stale(serverId)) return
      roots = res.roots
      if (roots.length === 0) {
        loading = false
        return
      }
      await load(typeof asked === 'string' && insideRoots(asked) ? asked : roots[0], serverId)
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
      loading = false
    }
  }

  $effect(() => {
    // Read into the call rather than as a bare expression: the dependency is
    // what makes this rerun when the selected server changes, and the value
    // is what the run then checks itself against.
    void start(servers.currentId)
  })

  async function act(what: string, fn: () => Promise<unknown>) {
    busy = what
    error = ''
    try {
      await fn()
      if (cwd) await load(cwd, servers.currentId, false)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = ''
    }
  }

  /// What a double-click does: a folder is entered, a text file opens in the
  /// editor. Links and anything else have neither, as before.
  function openEntry(entry: FsEntry) {
    if (!cwd) return
    if (entry.kind === 'dir') void load(joinPath(cwd, entry.name))
    else if (entry.kind === 'file') void edit(entry)
  }

  async function download(entry: FsEntry) {
    if (!cwd) return
    await act(entry.name, async () => {
      saveBlob(await api.fsRead(joinPath(cwd!, entry.name)), entry.name)
    })
  }

  /// Opens a file in the editor. The size the listing already carries decides
  /// whether it is worth reading at all, and the text is read and decoded here
  /// so a refusal never leaves an editor mounted over a file it cannot show.
  async function edit(entry: FsEntry) {
    if (!cwd) return
    error = ''
    if (entry.size !== null && entry.size > EDITOR_MAX_BYTES) {
      error = $LL.filesEditorTooLarge({
        file: entry.name,
        size: fmtBytes(entry.size),
        sizeMax: fmtBytes(EDITOR_MAX_BYTES),
      })
      return
    }
    const path = joinPath(cwd!, entry.name)
    const serverId = servers.currentId
    busy = entry.name
    try {
      const blob = await api.fsRead(path)
      if (stale(serverId)) return
      // The listing's size may be absent, and a file can grow between the
      // listing and this read; the limit is the panel's, so it is checked
      // against what was actually read too.
      if (blob.size > EDITOR_MAX_BYTES) {
        error = $LL.filesEditorTooLarge({
          file: entry.name,
          size: fmtBytes(blob.size),
          sizeMax: fmtBytes(EDITOR_MAX_BYTES),
        })
        return
      }
      let text: string
      try {
        text = new TextDecoder('utf-8', { fatal: true }).decode(await blob.arrayBuffer())
      } catch {
        error = $LL.filesEditorNotText()
        return
      }
      editing = { entry, path, text, serverId }
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = ''
    }
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

  function modifiedOf(entry: FsEntry): string {
    // Seconds since the epoch, as the agent reports them.
    return entry.modified === null
      ? ''
      : new Date(entry.modified * 1000).toLocaleString()
  }

  /// The root the current path sits in, deepest first: the sidebar marks it and
  /// the breadcrumb starts from it.
  const activeRoot = $derived.by(() => {
    const path = cwd
    if (!path) return null
    const within = roots.filter((r) => path === r || path.startsWith(r.endsWith('/') ? r : `${r}/`))
    return within.sort((a, b) => b.length - a.length)[0] ?? null
  })

  /// The path as steps that can be walked back up, from the root down.
  const crumbs = $derived.by(() => {
    const path = cwd
    const root = activeRoot
    if (!path || !root) return []
    const steps: { label: string; path: string }[] = [
      { label: rootLabel(root), path: root },
    ]
    let at = root === '/' ? '' : root
    for (const seg of path.slice(root === '/' ? 1 : root.length).split('/').filter(Boolean)) {
      at = at === '/' ? `/${seg}` : `${at}/${seg}`
      steps.push({ label: seg, path: at })
    }
    return steps
  })

  const parent = $derived(cwd === null ? null : parentOf(cwd, roots))

  /// The entry menu: an absolutely positioned list inside this app, not the
  /// desk's own (one per shell, shared by every window). [pane] is what the
  /// menu's coordinates are relative to — a window sits wherever it was
  /// dragged, so the screen's are not the app's.
  let pane = $state<HTMLDivElement | null>(null)
  let menuEl = $state<HTMLDivElement | null>(null)
  let menu = $state<{ entry: FsEntry; x: number; y: number } | null>(null)

  /// [screenX]/[screenY] are viewport coordinates; the pane's own corner is
  /// taken off them so the menu is placed inside the window wherever it sits.
  function showMenu(entry: FsEntry, screenX: number, screenY: number) {
    selected = entry.name
    const rect = pane?.getBoundingClientRect()
    menu = { entry, x: screenX - (rect?.left ?? 0), y: screenY - (rect?.top ?? 0) }
  }

  /// A right-click: the menu opens at the pointer.
  function openMenu(event: MouseEvent, entry: FsEntry) {
    event.preventDefault()
    event.stopPropagation()
    showMenu(entry, event.clientX, event.clientY)
  }

  /// The row's "more" button: right-click is not available on touch, and a
  /// keyboard activation has no pointer to place the menu at, so it hangs off
  /// the button's own corner instead.
  function openMenuAt(event: MouseEvent, entry: FsEntry) {
    event.preventDefault()
    event.stopPropagation()
    const rect = (event.currentTarget as HTMLElement).getBoundingClientRect()
    showMenu(entry, rect.right, rect.bottom + 2)
  }

  /// Run [fn] on the entry the menu is about, closing the menu first.
  function run(fn: (entry: FsEntry) => void) {
    const entry = menu?.entry
    menu = null
    if (entry) fn(entry)
  }

  /// Pulled back inside the pane once its size is known, as the desk's menus are.
  $effect(() => {
    if (!menu || !menuEl || !pane) return
    const x = Math.max(4, Math.min(menu.x, pane.clientWidth - menuEl.offsetWidth - 4))
    const y = Math.max(4, Math.min(menu.y, pane.clientHeight - menuEl.offsetHeight - 4))
    if (x !== menu.x || y !== menu.y) menu = { ...menu, x, y }
  })

  $effect(() => {
    if (!menu) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') menu = null
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })
</script>

{#snippet entryIcon(entry: FsEntry, big = false)}
  {@const cls = big ? 'h-8 w-8 shrink-0' : 'h-4 w-4 shrink-0'}
  {#if entry.kind === 'dir'}
    <Folder class={cls} style="color: var(--desk-accent)" />
  {:else if entry.kind === 'link'}
    <Link2 class="{cls} text-muted-fg" />
  {:else}
    <FileIcon class="{cls} text-muted-fg" />
  {/if}
{/snippet}

<AppToolbar>
  {#snippet leading()}
    {#if available}
      <div class="flex min-w-0 flex-1 items-center gap-0.5">
        <IconButton label={$LL.back()} disabled={!canBack} onclick={back}>
          <ArrowLeft class="h-4 w-4" />
        </IconButton>
        <IconButton label={$LL.filesForward()} disabled={!canForward} onclick={forward}>
          <ArrowRight class="h-4 w-4" />
        </IconButton>
        <IconButton label={$LL.filesUp()} disabled={!parent} onclick={() => parent && load(parent)}>
          <ArrowUp class="h-4 w-4" />
        </IconButton>
        <nav class="flex min-w-0 flex-1 items-center overflow-hidden" aria-label={$LL.filesRoots()}>
          {#each crumbs as crumb, i (crumb.path)}
            {#if i > 0}
              <ChevronRight class="h-3.5 w-3.5 shrink-0 text-muted-fg" />
            {/if}
            <button
              type="button"
              class="min-w-0 truncate rounded-md px-1.5 py-1 text-[0.8rem] text-muted-fg hover:bg-soft hover:text-fg"
              class:text-fg-strong={i === crumbs.length - 1}
              onclick={() => crumb.path !== cwd && void load(crumb.path)}
            >
              {crumb.label}
            </button>
          {/each}
        </nav>
        {#if busy}<Spinner class="h-4 w-4 shrink-0" />{/if}
      </div>
    {/if}
  {/snippet}

  {#snippet actions()}
    {#if available}
      <div class="flex items-center gap-0.5 rounded-lg border border-line p-0.5">
        <button
          type="button"
          class="grid h-6 w-6 place-items-center rounded-md text-muted-fg hover:text-fg"
          class:text-fg-strong={view === 'list'}
          style:background={view === 'list' ? TINT : undefined}
          aria-pressed={view === 'list'}
          aria-label={$LL.filesViewList()}
          onclick={() => setView('list')}
        >
          <List class="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          class="grid h-6 w-6 place-items-center rounded-md text-muted-fg hover:text-fg"
          class:text-fg-strong={view === 'grid'}
          style:background={view === 'grid' ? TINT : undefined}
          aria-pressed={view === 'grid'}
          aria-label={$LL.filesViewGrid()}
          onclick={() => setView('grid')}
        >
          <LayoutGrid class="h-3.5 w-3.5" />
        </button>
      </div>
    {/if}
    {#if cwd}
      <IconButton label={$LL.deskAddToDesk()} onclick={() => win.addPathIcon(cwd!, cwd!.split('/').filter(Boolean).at(-1) ?? cwd!)}>
        <MonitorUp class="h-4 w-4" />
      </IconButton>
    {/if}
    {#if available && write && cwd}
      <IconButton label={$LL.filesNewFolder()} onclick={() => (dialog = { kind: 'mkdir', value: '' })}>
        <FolderPlus class="h-4 w-4" />
      </IconButton>
      <IconButton label={$LL.filesUpload()} onclick={() => uploadInput?.click()}>
        <Upload class="h-4 w-4" />
      </IconButton>
    {/if}
  {/snippet}
</AppToolbar>

<input type="file" class="hidden" bind:this={uploadInput} onchange={onUpload} />

{#if !available}
  <main class="mx-auto max-w-3xl px-4 py-4 @3xl:px-6">
    <Card>
      <p class="text-sm text-muted-fg">
        {caps?.grants ? whyText(access.why, $LL) : $LL.filesUnavailable()}
      </p>
    </Card>
  </main>
{:else}
  <!-- The window body is `relative` and the toolbar above it is 3rem plus its
       hairline: the split view is pinned below that, so the sidebar reaches the
       bottom and the body itself never scrolls. -->
  <div class="absolute inset-x-0 bottom-0 top-[calc(3rem+1px)] min-h-0">
    <SplitView width={13}>
      {#snippet sidebar()}
        <SourceGroup title={$LL.filesRoots()}>
          {#each roots as root (root)}
            <!-- The wrapper carries the whole path: the row itself truncates. -->
            <div title={root}>
              <SourceItem
                label={rootLabel(root)}
                icon={Folder}
                selected={activeRoot === root}
                onclick={() => root !== cwd && void load(root)}
              />
            </div>
          {/each}
        </SourceGroup>
      {/snippet}

      <div bind:this={pane} class="relative flex h-full min-h-0 flex-col">
        {#if !write}
          <p class="px-3 pt-3 text-xs text-muted-fg">{$LL.filesReadOnly()}</p>
        {/if}

        {#if error}
          <div class="px-3 pt-3">
            <Card class="border-danger/40 bg-danger/5">
              <p class="text-sm text-danger break-all">{error}</p>
            </Card>
          </div>
        {/if}

        <div class="min-h-0 flex-1 overflow-auto p-3">
          {#if loading}
            <Card><Spinner class="h-5 w-5" /></Card>
          {:else if cwd && entries.length === 0}
            <Card><p class="text-sm text-muted-fg">{$LL.filesEmpty()}</p></Card>
          {:else if cwd}
            {#if view === 'list'}
              <div class="overflow-hidden rounded-xl border border-line bg-surface">
                {#each entries as entry (entry.name)}
                  <!-- The row is a button, so the "more" button is its sibling
                       rather than nested inside it (a button in a button is
                       not valid markup). -->
                  <div class="group/row relative border-b border-line last:border-b-0">
                    <button
                      type="button"
                      class="flex w-full items-center gap-3 py-2 pl-3 pr-9 text-left transition-colors hover:bg-soft"
                      style:background={selected === entry.name ? TINT : undefined}
                      onclick={() => (selected = entry.name)}
                      ondblclick={() => openEntry(entry)}
                      onkeydown={(e) => e.key === 'Enter' && openEntry(entry)}
                      oncontextmenu={(e) => openMenu(e, entry)}
                    >
                      {@render entryIcon(entry)}
                      <span class="min-w-0 flex-1 truncate text-[0.8rem]" title={entry.link_target ?? undefined}>
                        {entry.name}
                      </span>
                      <span class="hidden w-20 shrink-0 text-right text-xs text-muted-fg @2xl:block">
                        {entry.kind === 'file' && entry.size !== null ? fmtBytes(entry.size) : ''}
                      </span>
                      <span class="hidden w-40 shrink-0 text-right text-xs text-muted-fg @5xl:block">
                        {modifiedOf(entry)}
                      </span>
                      <span class="hidden w-10 shrink-0 text-right font-mono text-xs text-muted-fg @2xl:block">
                        {modeText(entry.mode)}
                      </span>
                    </button>
                    <button
                      type="button"
                      class="files-more absolute right-1.5 top-1/2 grid h-6 w-6 -translate-y-1/2 place-items-center rounded-md text-muted-fg opacity-0 transition-opacity hover:bg-soft hover:text-fg focus-visible:opacity-100 group-hover/row:opacity-100"
                      aria-label={$LL.filesMoreActions()}
                      onclick={(e) => openMenuAt(e, entry)}
                    >
                      <Ellipsis class="h-4 w-4" />
                    </button>
                  </div>
                {/each}
              </div>
            {:else}
              <div class="grid grid-cols-[repeat(auto-fill,minmax(7rem,1fr))] gap-2">
                {#each entries as entry (entry.name)}
                  <div class="group/tile relative">
                    <button
                      type="button"
                      class="flex w-full flex-col items-center gap-2 rounded-xl border border-line bg-surface px-2 py-3 text-center transition-colors hover:bg-soft"
                      style:background={selected === entry.name ? TINT : undefined}
                      onclick={() => (selected = entry.name)}
                      ondblclick={() => openEntry(entry)}
                      onkeydown={(e) => e.key === 'Enter' && openEntry(entry)}
                      oncontextmenu={(e) => openMenu(e, entry)}
                    >
                      {@render entryIcon(entry, true)}
                      <span class="line-clamp-2 w-full break-words text-xs leading-tight">{entry.name}</span>
                      {#if entry.kind === 'file' && entry.size !== null}
                        <span class="text-[0.68rem] text-muted-fg">{fmtBytes(entry.size)}</span>
                      {/if}
                    </button>
                    <button
                      type="button"
                      class="files-more absolute right-1 top-1 grid h-6 w-6 place-items-center rounded-md bg-surface/80 text-muted-fg opacity-0 transition-opacity hover:bg-soft hover:text-fg focus-visible:opacity-100 group-hover/tile:opacity-100"
                      aria-label={$LL.filesMoreActions()}
                      onclick={(e) => openMenuAt(e, entry)}
                    >
                      <Ellipsis class="h-4 w-4" />
                    </button>
                  </div>
                {/each}
              </div>
            {/if}
          {/if}
        </div>

        {#if menu}
          <button
            type="button"
            class="absolute inset-0 z-20 cursor-default"
            aria-label={$LL.cancel()}
            onclick={() => (menu = null)}
            oncontextmenu={(e) => {
              e.preventDefault()
              menu = null
            }}
          ></button>
          <div
            bind:this={menuEl}
            class="desk-pop absolute z-30 min-w-44 rounded-xl border border-line bg-surface p-1 text-[0.8rem] shadow-lg"
            style:left="{menu.x}px"
            style:top="{menu.y}px"
            role="menu"
          >
            {#if menu.entry.kind === 'file'}
              <button
                type="button"
                role="menuitem"
                class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left hover:bg-soft"
                onclick={() => run((e) => void edit(e))}
              >
                <FilePenLine class="h-3.5 w-3.5 shrink-0 text-muted-fg" />
                <span class="flex-1 truncate">{$LL.filesEdit()}</span>
              </button>
            {/if}
            {#if menu.entry.kind === 'dir'}
              {#if cwd}
                <button
                  type="button"
                  role="menuitem"
                  class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left hover:bg-soft"
                  onclick={() => run((e) => win.addPathIcon(joinPath(cwd!, e.name), e.name))}
                >
                  <MonitorUp class="h-3.5 w-3.5 shrink-0 text-muted-fg" />
                  <span class="flex-1 truncate">{$LL.deskAddToDesk()}</span>
                </button>
              {/if}
            {:else}
              <button
                type="button"
                role="menuitem"
                class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left hover:bg-soft"
                onclick={() => run((e) => void download(e))}
              >
                <Download class="h-3.5 w-3.5 shrink-0 text-muted-fg" />
                <span class="flex-1 truncate">{$LL.filesDownload()}</span>
              </button>
            {/if}
            {#if write}
              <div class="mx-2 my-1 h-px bg-line"></div>
              <button
                type="button"
                role="menuitem"
                class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left hover:bg-soft"
                onclick={() => run((e) => (dialog = { kind: 'rename', entry: e, value: e.name }))}
              >
                <Pencil class="h-3.5 w-3.5 shrink-0 text-muted-fg" />
                <span class="flex-1 truncate">{$LL.filesRename()}</span>
              </button>
              <button
                type="button"
                role="menuitem"
                class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left hover:bg-soft"
                onclick={() => run((e) => (dialog = { kind: 'chmod', entry: e, value: modeText(e.mode) }))}
              >
                <Shield class="h-3.5 w-3.5 shrink-0 text-muted-fg" />
                <span class="flex-1 truncate">{$LL.filesPermissions()}</span>
              </button>
              <button
                type="button"
                role="menuitem"
                class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left text-danger hover:bg-soft"
                onclick={() => run((e) => (dialog = { kind: 'delete', entry: e }))}
              >
                <Trash2 class="h-3.5 w-3.5 shrink-0" />
                <span class="flex-1 truncate">{$LL.filesDelete()}</span>
              </button>
            {/if}
          </div>
        {/if}
      </div>
    </SplitView>
  </div>
{/if}

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

{#if editing}
  <FileEditor
    path={editing.path}
    entry={editing.entry}
    text={editing.text}
    serverId={editing.serverId}
    canWrite={write}
    onclose={() => (editing = null)}
    onsaved={() => {
      if (cwd) void load(cwd, servers.currentId, false)
    }}
  />
{/if}

<style>
  /* A pointer that cannot hover (touch) has no way to reveal the row's "more"
     button, so there it is always visible. */
  @media (hover: none) {
    .files-more {
      opacity: 1;
    }
  }
</style>
