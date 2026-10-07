<script lang="ts">
  import { Button, Card, Dialog, Icon, IconButton, Input, Menu, SegmentedControl, SidebarItem, SidebarSection, Spinner, type MenuEntry } from '../../lk'
  import { AppToolbar, SplitView, useMenus, useWindow } from '../../sys'
  import FileEditor from './FileEditor.svelte'
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

  /// [step] is what the history does once the listing has arrived: `push` a
  /// new step, `stay` for a refresh (a write landed), or move to an index
  /// (back/forward). Only on success, so a listing that fails leaves the
  /// history where the window still is.
  async function load(path: string, serverId = servers.currentId, step: 'push' | 'stay' | number = 'push') {
    loading = true
    error = ''
    try {
      const listed = sortEntries(await api.fsList(path))
      if (stale(serverId)) return
      entries = listed
      cwd = path
      selected = null
      if (step === 'push') {
        hist = [...hist.slice(0, histAt + 1), path]
        histAt = hist.length - 1
      } else if (step !== 'stay') {
        histAt = step
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
    void load(hist[histAt - 1], servers.currentId, histAt - 1)
  }

  function forward() {
    if (!canForward) return
    void load(hist[histAt + 1], servers.currentId, histAt + 1)
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
      if (cwd) await load(cwd, servers.currentId, 'stay')
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = ''
    }
  }

  /// What a double-click does: a folder is entered, a text file opens in the
  /// editor. Links and anything else have neither, as before.
  ///
  /// A touch screen has no double tap to speak of: there a tap is the open.
  let touched = false

  function tap(entry: FsEntry) {
    selected = entry.name
    if (touched) openEntry(entry)
  }

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
  const menuItems = $derived.by((): MenuEntry[] => {
    if (!menu) return []
    const entry = menu.entry
    const items: MenuEntry[] = []
    if (entry.kind === 'file') {
      items.push({ label: $LL.filesEdit(), icon: 'edit', action: () => void edit(entry) })
    }
    if (entry.kind === 'dir') {
      if (cwd) {
        items.push({
          label: $LL.deskAddToDesk(),
          icon: 'add_to_home_screen',
          action: () => win.addPathIcon(joinPath(cwd!, entry.name), entry.name),
        })
      }
    } else {
      items.push({ label: $LL.filesDownload(), icon: 'download', action: () => void download(entry) })
    }
    if (write) {
      items.push(
        { separator: true },
        { label: $LL.filesRename(), icon: 'edit', action: () => (dialog = { kind: 'rename', entry, value: entry.name }) },
        { label: $LL.filesPermissions(), icon: 'shield_lock', action: () => (dialog = { kind: 'chmod', entry, value: modeText(entry.mode) }) },
        { label: $LL.filesDelete(), icon: 'delete', danger: true, action: () => (dialog = { kind: 'delete', entry }) },
      )
    }
    return items
  })

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

  /// Focus goes into a menu as it opens, so the keyboard reaches its actions
  /// at once rather than after every row below the one it is about.
  $effect(() => {
    if (!menuEl) return
    menuEl.querySelector<HTMLButtonElement>('button:not(:disabled)')?.focus()
  })

  /// Pulled back inside the pane once its size is known, as the desk's menus are.
  $effect(() => {
    if (!menu || !menuEl || !pane) return
    const x = Math.max(4, Math.min(menu.x, pane.clientWidth - menuEl.offsetWidth - 4))
    const y = Math.max(4, Math.min(menu.y, pane.clientHeight - menuEl.offsetHeight - 4))
    if (x !== menu.x || y !== menu.y) menu = { ...menu, x, y }
  })

  // The menubar: what the toolbar offers, with shortcuts.
  useMenus(() => {
    if (!available) return []
    const file: MenuEntry[] = []
    if (write && cwd) {
      file.push(
        { label: $LL.filesNewFolder(), icon: 'create_new_folder', shortcut: '⌥⌘N', action: () => (dialog = { kind: 'mkdir', value: '' }) },
        { label: $LL.filesUpload(), icon: 'upload', shortcut: '⌘U', action: () => uploadInput?.click() },
        { separator: true },
      )
    }
    if (cwd) {
      const at = cwd
      file.push({ label: $LL.deskAddToDesk(), icon: 'add_to_home_screen', action: () => win.addPathIcon(at, at.split('/').filter(Boolean).at(-1) ?? at) })
    }
    return [
      { label: $LL.deskMenuFile(), items: file },
      {
        label: $LL.filesView(),
        items: [
          { label: $LL.filesViewList(), checked: view === 'list', shortcut: '⌥⌘1', action: () => setView('list') },
          { label: $LL.filesViewGrid(), checked: view === 'grid', shortcut: '⌥⌘2', action: () => setView('grid') },
        ],
      },
      {
        label: $LL.deskMenuGo(),
        items: [
          { label: $LL.back(), disabled: !canBack, shortcut: '⌘[', action: back },
          { label: $LL.filesForward(), disabled: !canForward, shortcut: '⌘]', action: forward },
          { label: $LL.filesUp(), disabled: !parent, shortcut: '⌘↑', action: () => parent && void load(parent) },
        ],
      },
    ]
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

{#snippet entryIcon(entry: FsEntry, big = false, selectedEntry = false)}
  <Icon
    name={entry.kind === 'dir' ? (big ? 'folder' : 'folder_open') : entry.kind === 'link' ? 'link' : 'description'}
    size={big ? 32 : 17}
    color={selectedEntry ? 'var(--text-on-accent)' : entry.kind === 'dir' ? 'var(--color-accent)' : 'var(--text-secondary)'}
  />
{/snippet}

<AppToolbar>
  {#snippet leading()}
    {#if available}
      <div class="flex min-w-0 flex-1 items-center gap-0.5">
        <IconButton icon="arrow_back" label={$LL.back()} disabled={!canBack} onclick={back} />
        <IconButton icon="arrow_forward" label={$LL.filesForward()} disabled={!canForward} onclick={forward} />
        <IconButton icon="arrow_upward" label={$LL.filesUp()} disabled={!parent} onclick={() => parent && load(parent)} />
        <nav class="flex min-w-0 flex-1 items-center overflow-hidden" aria-label={$LL.filesRoots()}>
          {#each crumbs as crumb, i (crumb.path)}
            {#if i > 0}
              <Icon name="chevron_right" size={14} class="shrink-0 text-(--text-tertiary)" />
            {/if}
            <button
              type="button"
              class="min-w-0 truncate rounded-[7px] px-[7px] py-[5px] text-[13px] text-(--text-secondary) hover:bg-(--fill-hover) hover:text-(--text-primary)"
              class:text-(--text-primary)={i === crumbs.length - 1}
              onclick={() => crumb.path !== cwd && void load(crumb.path)}
            >
              {crumb.label}
            </button>
          {/each}
        </nav>
        {#if busy}<Spinner size={16} class="shrink-0" />{/if}
      </div>
    {/if}
  {/snippet}

  {#snippet actions()}
    {#if available}
      <SegmentedControl
        size="sm"
        label={$LL.filesView()}
        options={[
          { value: 'list', icon: 'view_list', title: $LL.filesViewList() },
          { value: 'grid', icon: 'grid_view', title: $LL.filesViewGrid() },
        ]}
        value={view}
        onchange={(value) => setView(value)}
      />
    {/if}
    {#if cwd}
      <IconButton icon="add_to_home_screen" label={$LL.deskAddToDesk()} onclick={() => win.addPathIcon(cwd!, cwd!.split('/').filter(Boolean).at(-1) ?? cwd!)} />
    {/if}
    {#if available && write && cwd}
      <IconButton icon="create_new_folder" label={$LL.filesNewFolder()} onclick={() => (dialog = { kind: 'mkdir', value: '' })} />
      <IconButton icon="upload" label={$LL.filesUpload()} onclick={() => uploadInput?.click()} />
    {/if}
  {/snippet}
</AppToolbar>

<input type="file" class="hidden" bind:this={uploadInput} onchange={onUpload} />

{#if !available}
  <main class="mx-auto max-w-3xl px-[17px] pb-[17px] pt-[4px]">
    <Card>
      <p class="text-[13px] text-(--text-secondary)">
        {caps?.grants ? whyText(access.why, $LL) : $LL.filesUnavailable()}
      </p>
    </Card>
  </main>
{:else}
  <!-- The split view takes what the toolbar leaves of the window (the body is
       a column), so the sidebar reaches the bottom and the body never scrolls. -->
  <div class="relative min-h-0 flex-1">
    <SplitView width={13}>
      {#snippet sidebar()}
        <SidebarSection title={$LL.filesRoots()}>
          {#each roots as root (root)}
            <SidebarItem
              label={rootLabel(root)}
              icon="folder"
              active={activeRoot === root}
              title={root}
              onclick={() => root !== cwd && void load(root)}
            />
          {/each}
        </SidebarSection>
      {/snippet}

      <div bind:this={pane} class="relative flex h-full min-h-0 flex-col">
        {#if !write}
          <p class="px-[13px] pt-[9px] text-[12px] text-(--text-tertiary)">{$LL.filesReadOnly()}</p>
        {/if}

        {#if error}
          <div class="px-[13px] pt-[9px]">
            <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
              <Icon name="error" size={17} />
              <p class="break-all">{error}</p>
            </Card>
          </div>
        {/if}

        <div class="min-h-0 flex-1 overflow-auto px-[17px] pb-[17px] pt-[4px]">
          {#if loading}
            <Card><Spinner size={20} /></Card>
          {:else if cwd && entries.length === 0}
            <div class="flex min-h-48 flex-col items-center justify-center gap-[9px]">
              <Icon name="folder_open" size={48} weight={300} color="var(--text-tertiary)" />
              <p class="text-[13px] text-(--text-secondary)">{$LL.filesEmptyState()}</p>
            </div>
          {:else if cwd}
            {#if view === 'list'}
              <div class="overflow-hidden rounded-[13px] bg-(--surface-card)">
                <div class="sticky top-0 z-10 grid grid-cols-[minmax(0,1fr)] gap-[9px] bg-(--surface-window) px-[13px] py-[7px] lk-caps @5xl:grid-cols-[minmax(0,1fr)_80px_160px_40px_28px] @5xl:gap-[13px]">
                  <span>{$LL.filesName()}</span>
                  <span class="hidden text-right @5xl:block">{$LL.filesSize()}</span>
                  <span class="hidden text-right @5xl:block">{$LL.filesModified()}</span>
                  <span class="hidden text-right @5xl:block">{$LL.filesPermissions()}</span>
                  <span></span>
                </div>
                {#each entries as entry, i (entry.name)}
                  <!-- The row is a button, so the "more" button is its sibling
                       rather than nested inside it (a button in a button is
                       not valid markup). -->
                  <div class="group/row relative" class:bg-(--fill-hover)={selected !== entry.name && i % 2 === 1}>
                    <button
                      type="button"
                      class="grid h-7 w-full grid-cols-[minmax(0,1fr)] items-center gap-[9px] rounded-[7px] px-[13px] text-left text-[13px] hover:bg-(--fill-hover) @5xl:grid-cols-[minmax(0,1fr)_80px_160px_40px_28px] @5xl:gap-[13px]"
                      class:bg-(--color-accent)={selected === entry.name}
                      class:text-(--text-on-accent)={selected === entry.name}
                      onpointerdown={(e) => (touched = e.pointerType === 'touch')}
                      onclick={() => tap(entry)}
                      ondblclick={() => openEntry(entry)}
                      onkeydown={(e) => e.key === 'Enter' && openEntry(entry)}
                      oncontextmenu={(e) => openMenu(e, entry)}
                    >
                      <span class="flex min-w-0 items-center gap-[9px]">
                        {@render entryIcon(entry, false, selected === entry.name)}
                        <span class="min-w-0 truncate" title={entry.link_target ?? undefined}>{entry.name}</span>
                      </span>
                      <span class="lk-num hidden text-right text-[12px] text-(--text-tertiary) @5xl:block">{entry.kind === 'file' && entry.size !== null ? fmtBytes(entry.size) : ''}</span>
                      <span class="lk-num hidden text-right text-[12px] text-(--text-tertiary) @5xl:block">{modifiedOf(entry)}</span>
                      <span class="lk-mono hidden text-right text-[12px] text-(--text-tertiary) @5xl:block">{modeText(entry.mode)}</span>
                    </button>
                    <button
                      type="button"
                      class="files-more absolute right-[5px] top-1/2 z-10 grid h-6 w-6 -translate-y-1/2 place-items-center rounded-[7px] bg-(--surface-card) text-(--text-secondary) opacity-0 transition-opacity hover:bg-(--fill-hover) hover:text-(--text-primary) focus-visible:opacity-100 group-hover/row:opacity-100"
                      aria-label={$LL.filesMoreActions()}
                      onclick={(e) => openMenuAt(e, entry)}
                    >
                      <Icon name="more_horiz" size={17} />
                    </button>
                  </div>
                {/each}
              </div>
            {:else}
              <div class="grid grid-cols-[repeat(auto-fill,minmax(112px,1fr))] gap-[9px]">
                {#each entries as entry (entry.name)}
                  <div class="group/tile relative">
                    <button
                      type="button"
                      class="flex w-full flex-col items-center gap-[9px] rounded-[13px] bg-(--surface-card) px-[9px] py-[13px] text-center text-[13px] text-(--text-primary) transition-colors hover:bg-(--fill-hover)"
                      class:bg-(--color-accent)={selected === entry.name}
                      class:text-(--text-on-accent)={selected === entry.name}
                      onpointerdown={(e) => (touched = e.pointerType === 'touch')}
                      onclick={() => tap(entry)}
                      ondblclick={() => openEntry(entry)}
                      onkeydown={(e) => e.key === 'Enter' && openEntry(entry)}
                      oncontextmenu={(e) => openMenu(e, entry)}
                    >
                      {@render entryIcon(entry, true, selected === entry.name)}
                      <span class="line-clamp-2 w-full break-words text-[13px] leading-tight">{entry.name}</span>
                      {#if entry.kind === 'file' && entry.size !== null}
                        <span class="lk-num text-[12px] text-(--text-tertiary)">{fmtBytes(entry.size)}</span>
                      {/if}
                    </button>
                    <button
                      type="button"
                      class="files-more absolute right-[5px] top-[5px] grid h-6 w-6 place-items-center rounded-[7px] bg-(--surface-card) text-(--text-secondary) opacity-0 transition-opacity hover:bg-(--fill-hover) hover:text-(--text-primary) focus-visible:opacity-100 group-hover/tile:opacity-100"
                      aria-label={$LL.filesMoreActions()}
                      onclick={(e) => openMenuAt(e, entry)}
                    >
                      <Icon name="more_horiz" size={17} />
                    </button>
                  </div>
                {/each}
              </div>
            {/if}
          {/if}
        </div>

        {#if cwd && !loading}
          <div class="files-status lk-num">
            {$LL.files()} · {entries.length}
          </div>
        {/if}

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
          <div class="absolute z-30" style:left="{menu.x}px" style:top="{menu.y}px">
            <Menu
              bind:ref={menuEl}
              items={menuItems}
              onselect={() => (menu = null)}
              onclose={() => (menu = null)}
            />
          </div>
        {/if}
      </div>
    </SplitView>
  </div>
{/if}

{#if dialog}
  <Dialog
    open
    wide={dialog.kind !== 'delete'}
    title={dialog.kind === 'mkdir'
      ? $LL.filesNewFolder()
      : dialog.kind === 'rename'
        ? $LL.filesRename()
        : dialog.kind === 'chmod'
          ? $LL.filesPermissions()
          : $LL.filesDelete()}
    message={dialog.kind === 'delete'
      ? dialog.entry.kind === 'dir'
        ? $LL.filesDeleteRecursive()
        : $LL.filesConfirmDelete()
      : undefined}
    onclose={() => (dialog = null)}
  >
    {@const currentDialog = dialog}
    {#if currentDialog.kind === 'delete'}
      <p class="break-all text-[13px] font-semibold text-(--text-primary)">{currentDialog.entry.name}</p>
    {:else if currentDialog.kind === 'chmod'}
      <Input label={$LL.filesPermissions()} id="fs-mode" bind:value={currentDialog.value} placeholder="644" mono />
    {:else}
      <Input label={$LL.filesName()} id="fs-name" bind:value={currentDialog.value} />
    {/if}
    {#snippet actions()}
      {#if currentDialog.kind === 'delete'}
        <Button variant="destructive" icon="delete" onclick={() => void submitDialog()}>{$LL.filesDelete()}</Button>
        <Button variant="secondary" onclick={() => (dialog = null)}>{$LL.cancel()}</Button>
      {:else}
        <Button variant="secondary" onclick={() => (dialog = null)}>{$LL.cancel()}</Button>
        <Button onclick={() => void submitDialog()}>{$LL.save()}</Button>
      {/if}
    {/snippet}
  </Dialog>
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
      if (cwd) void load(cwd, servers.currentId, 'stay')
    }}
  />
{/if}

<style>
  .files-status {
    display: flex;
    height: 28px;
    align-items: center;
    border-top: 0.5px solid var(--border-hairline);
    padding: 0 13px;
    color: var(--text-tertiary);
    font-size: 12px;
  }

  /* A pointer that cannot hover (touch) has no way to reveal the row's "more"
     button, so there it is always visible. */
  @media (hover: none) {
    .files-more {
      opacity: 1;
    }
  }
</style>
