<script lang="ts">
  import Spinner from '@lollipopkit/desk-ui/Spinner.svelte'
  import { AppToolbar, type MenuEntry, SplitView, systemPrefs, useMenus, WindowFooter } from '../../sys'
  import {
    Button,
    Card,
    Checkbox,
    DataTable,
    Dialog,
    Icon,
    IconButton,
    Input,
    SidebarItem,
    SidebarSection,
    StatusBar,
    type Column,
  } from '@lollipopkit/desk-ui'
  import TargetTerminal from '../../../components/TargetTerminal.svelte'
  import { machineAccess } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { imageReference, refusalText } from '../../../lib/container'
  import { fmtBytes } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import type {
    ContainerAction,
    ContainerActionKind,
    ContainerImage,
    ContainerRow,
    ContainerView,
  } from '../../../types'

  /// Two lists, one screen — the sidebar's two rows. `usage` is not a third:
  /// `system df` walks the whole image store, so it is a line at the top of
  /// whichever list is showing rather than a view of its own.
  type Tab = 'containers' | 'images'

  /// How much of a container's log a read asks for. Mirrors
  /// `sbm_parser::container::LOG_TAIL`, which is the agent's bound — this is
  /// only what the sentence above the output says.
  const LOG_TAIL = 100

  let tab = $state<Tab>('containers')
  /// The selected container's id, or image's key, in the tab on screen.
  let selected = $state<string | null>(null)

  let view = $state<ContainerView | null>(null)
  let usage = $state<ContainerView | null>(null)
  let loading = $state(true)
  let error = $state('')
  /// What the runtime printed for the last action, when it said anything, and
  /// its exit code. A command that failed answers `exit_code`/`output` in a
  /// 200, so this is where a pull that could not find the tag says so.
  /// `undefined` exit: the agent ran out of time before the command ended.
  let actionOutput = $state('')
  let actionExit = $state<number | null | undefined>(0)
  let busy = $state(false)
  /// The container whose removal is being confirmed, or `undefined` for none.
  /// Removal is the only action asked about: it is the only one that loses
  /// something, and `force` changes what it does to a running container.
  let confirming = $state<ContainerRow | undefined>(undefined)
  /// The prune being confirmed. Asked about for the reason removal is: it
  /// deletes what it does not list, and a volume's data does not come back.
  let pruning = $state<'prune_containers' | 'prune_volumes' | undefined>(undefined)
  let force = $state(false)
  let logsFor = $state<ContainerRow | undefined>(undefined)
  let logs = $state('')
  let logsError = $state('')

  /// The image whose removal is being confirmed.
  let imageConfirm = $state<ContainerImage | undefined>(undefined)
  /// The pull dialog's reference field. A row's Pull prefills it; the header
  /// action opens it empty.
  let pullRef = $state('')
  let pullOpen = $state(false)
  /// The image prune dialog and its scope.
  let imagePrune = $state(false)
  let pruneAllUnused = $state(false)
  /// The system prune dialog and its scopes.
  let systemPrune = $state(false)
  let systemAllImages = $state(false)
  let systemVolumes = $state(false)
  /// The run dialog's fields.
  let runOpen = $state(false)
  let runImage = $state('')
  let runName = $state('')
  let runArgs = $state('')
  /// The container whose shell is open in the dialog, if any.
  let shellFor = $state<ContainerRow | undefined>(undefined)

  /// A reply that arrives after the desk has switched servers belongs to
  /// neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(part: Tab = tab, serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getContainers(part)
      if (stale(serverId)) return
      view = next
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  /// The disk usage is a second request because it is a second question, and
  /// one the page can draw without. A failure here blanks the line rather than
  /// replacing the list with an error about a number nobody asked for.
  async function loadUsage(serverId = servers.currentId) {
    try {
      const next = await api.getContainers('usage')
      if (stale(serverId)) return
      usage = next
    } catch {
      if (!stale(serverId)) usage = null
    }
  }

  $effect(() => {
    // `tab` is read here, so switching tabs re-runs this; the button below only
    // sets the state. Calling `load` from both would fetch the same part twice.
    void load(tab)
    void loadUsage()
  })

  /// The listing on screen is stale if it answers for a server the sidebar has
  /// since left, so `loadUsage` is re-run beside every refresh.
  async function refresh() {
    await load()
    await loadUsage()
  }

  /// Bumped per action, so a reply that arrives after the page has moved on
  /// cannot clear a newer action's spinner.
  let actGeneration = 0

  /// Every change answers with the listing it was about — the images for an
  /// image action, the containers otherwise. When that is the tab on screen it
  /// replaces it; otherwise the tab is read again, since the answer is a
  /// listing this tab does not show.
  ///
  /// A pull may take minutes, so the answer is dropped if the sidebar has
  /// moved on: drawing it would show one server's images on another's page.
  async function act(action: ContainerAction) {
    const generation = ++actGeneration
    const serverId = servers.currentId
    busy = true
    error = ''
    actionOutput = ''
    actionExit = 0
    try {
      const answer = await api.actContainer(action)
      if (stale(serverId)) return
      actionOutput = answer.output ?? ''
      actionExit = answer.exit_code
      if (answer.part === tab) view = answer
      else void load(tab)
      void loadUsage()
    } catch (e) {
      if (stale(serverId)) return
      // A refused value is `400 invalid_input` with its issue in the body.
      error = refusalText(e)
    } finally {
      if (generation === actGeneration) busy = false
    }
  }

  /// Opens the pull dialog, prefilled when a row's Pull asked for it.
  function openPull(image?: ContainerImage) {
    pullRef = image ? imageReference(image) : ''
    pullOpen = true
  }

  function openImagePrune() {
    pruneAllUnused = false
    imagePrune = true
  }

  function openRun() {
    runImage = ''
    runName = ''
    runArgs = ''
    runOpen = true
  }

  async function openLogs(row: ContainerRow) {
    if (!row.id) return
    logsFor = row
    logs = ''
    logsError = ''
    try {
      const answer = await api.getContainers('logs', row.id)
      logs = answer.logs ?? ''
      if (!logs && answer.reason) logsError = answer.reason
    } catch (e) {
      logsError = e instanceof Error ? e.message : String(e)
    }
  }

  const rows = $derived(view?.containers ?? [])
  const images = $derived(view?.images ?? [])

  /// Images with no name to lose, for the prune dialog's count — the agent's
  /// `dangling` flag, counted. The unused *tagged* count beside it is the
  /// agent's too (`unused_tagged`): whether a tagged image is in use is a
  /// rule, and a second implementation of it would drift.
  const danglingCount = $derived(images.filter((image) => image.dangling).length)

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  /// A shell inside a container: the agent must understand the terminal
  /// `target` (`container_exec`) and the account must hold `shell`. An older
  /// agent ignores the target and would open a host shell instead.
  const canExec = $derived(machineAccess(caps, 'container_exec', 'shell'))

  /// How each action is drawn. A `Record` over every kind, so a kind added to
  /// the model without a button here is a type error rather than a container
  /// whose menu is silently short.
  const BUTTONS: Record<ContainerActionKind, { label: () => string; icon: string } | null> = {
    start: { label: () => $LL.containerStart(), icon: 'play_arrow' },
    stop: { label: () => $LL.containerStop(), icon: 'stop' },
    restart: { label: () => $LL.containerRestart(), icon: 'restart_alt' },
    remove: { label: () => $LL.containerRemove(), icon: 'delete' },
    logs: { label: () => $LL.containerLogs(), icon: 'article' },
    terminal: { label: () => $LL.containerOpenShell(), icon: 'terminal' },
  }

  /// The lifecycle buttons for one row: the model's own list, minus the ones
  /// that are not a change. A log is a view and is offered as a link below the
  /// row; a shell is drawn only where the agent and the account allow it.
  function lifecycle(row: ContainerRow): ContainerActionKind[] {
    return row.actions.filter(
      (kind) => kind !== 'logs' && (kind !== 'terminal' || canExec),
    )
  }

  function click(kind: ContainerActionKind, row: ContainerRow) {
    if (!row.id) return
    const id = row.id
    switch (kind) {
      case 'start':
        void act({ action: 'start', id })
        return
      case 'stop':
        void act({ action: 'stop', id })
        return
      case 'restart':
        void act({ action: 'restart', id })
        return
      case 'remove':
        force = false
        confirming = row
        return
      case 'terminal':
        shellFor = row
        return
      default:
        return
    }
  }

  function statusTone(row: ContainerRow): 'success' | 'danger' | 'warning' | 'neutral' {
    switch (row.status) {
      case 'running':
        return 'success'
      case 'exited':
      case 'dead':
        return 'danger'
      case 'paused':
      case 'restarting':
      case 'removing':
        return 'warning'
      default:
        return 'neutral'
    }
  }

  function statusText(row: ContainerRow): string {
    switch (row.status) {
      case 'running':
        return $LL.containerRunning()
      case 'exited':
        return $LL.containerExited()
      case 'created':
        return $LL.containerCreated()
      case 'paused':
        return $LL.containerPaused()
      case 'restarting':
        return $LL.containerRestarting()
      case 'removing':
        return $LL.containerRemoving()
      case 'dead':
        return $LL.containerDead()
      default:
        return $LL.containerUnknown()
    }
  }

  function reasonText(reason: ContainerView): string {
    switch (reason.reason_kind) {
      case 'not_installed':
        return $LL.containerNotInstalled()
      case 'unsupported_platform':
        return $LL.containerUnsupportedPlatform()
      case 'permission_denied':
        return $LL.containerPermissionDenied()
      case 'unreadable':
        return $LL.containerUnreadable()
      default:
        // What the machine said, verbatim: it is the only thing that
        // distinguishes one failure from another.
        return reason.reason ?? $LL.containerUnreadable()
    }
  }

  /// A container's dot: green running, red ended badly, amber in between, a
  /// ring when it simply is not running.
  function dotColor(row: ContainerRow): string | null {
    switch (statusTone(row)) {
      case 'success':
        return 'var(--hue-green)'
      case 'danger':
        return row.status === 'exited' ? null : 'var(--hue-red)'
      case 'warning':
        return 'var(--hue-amber)'
      default:
        return null
    }
  }

  const TONE_COLOR = { success: 'var(--color-success)', danger: 'var(--color-danger)', warning: 'var(--color-warning)', neutral: 'var(--text-tertiary)' }

  type ContainerLine = { key: string; dot: string | null; name: string; image: string; ports: string; cpu: string; mem: string; state: string; stateColor: string }
  const containerLines = $derived(
    rows.map(
      (row): ContainerLine => ({
        key: row.id ?? row.name ?? '',
        dot: dotColor(row),
        name: row.name ?? $LL.containerUnknown(),
        image: row.image ?? $LL.containerUnknown(),
        ports: row.ports ?? '',
        cpu: row.stats?.cpu ?? '—',
        // The table has room for what is used; the limit is in the detail.
        // TODO: drop the `mem` fallback once agents without `mem_used` are gone.
        mem: row.stats?.mem_used ?? row.stats?.mem ?? '—',
        state: statusText(row),
        stateColor: TONE_COLOR[statusTone(row)],
      }),
    ),
  )
  const containerColumns = $derived<Column<ContainerLine>[]>([
    { key: 'mark', label: '', width: '22px', dotKey: 'dot', sortable: false },
    { key: 'name', label: $LL.containerName(), width: 'minmax(140px,1fr)', strong: true },
    { key: 'image', label: $LL.containerImage(), width: 'minmax(0,1fr)', dim: true },
    { key: 'ports', label: $LL.containerPorts(), width: 'minmax(0,0.8fr)', dim: true, mono: true },
    { key: 'cpu', label: $LL.containerCpu(), width: '64px', align: 'end', dim: true, dimZero: true },
    { key: 'mem', label: $LL.containerMemory(), width: '76px', align: 'end', dim: true },
    { key: 'state', label: $LL.serviceStatus(), width: '84px', align: 'end', small: true, strong: true, colorKey: 'stateColor' },
  ])

  /// An image's key in the table: its reference, or its id when it has none.
  const imageKey = (image: ContainerImage) => (image.dangling ? (image.id ?? image.repository) : imageReference(image))
  type ImageLine = { key: string; reference: string; id: string; size: string; use: string; created: string }
  const imageLines = $derived(
    images.map(
      (image): ImageLine => ({
        key: imageKey(image),
        reference: image.tag ? `${image.repository}:${image.tag}` : image.repository,
        id: image.id ? image.id.replace(/^sha256:/, '').slice(0, 12) : '',
        size: image.size ?? '—',
        // Unknown, never zero: a count this agent could not confirm is not a
        // count of none.
        use: image.containers === null ? $LL.containerUsageUnknown() : image.containers === 0 ? $LL.containerUnused() : $LL.containerInUse({ count: image.containers }),
        created: image.created_at ?? '',
      }),
    ),
  )
  const imageColumns = $derived<Column<ImageLine>[]>([
    { key: 'reference', label: $LL.containerImage(), width: 'minmax(160px,1fr)', strong: true },
    { key: 'id', label: 'ID', width: '110px', dim: true, mono: true },
    { key: 'size', label: $LL.containerSize(), width: '84px', align: 'end', dim: true },
    { key: 'use', label: $LL.containerUse(), width: '110px', dim: true, small: true },
    { key: 'created', label: $LL.containerCreatedAt(), width: 'minmax(0,0.8fr)', dim: true, small: true },
  ])

  const selectedRow = $derived(tab === 'containers' && selected ? rows.find((r) => (r.id ?? r.name) === selected) : undefined)
  const selectedImage = $derived(tab === 'images' && selected ? images.find((i) => imageKey(i) === selected) : undefined)

  useMenus(() => {
    if (!view?.available) return []
    const file: MenuEntry[] =
      tab === 'containers'
        ? [
            { label: `${$LL.containerRun()}…`, icon: 'add', shortcut: '⌘N', action: openRun },
            { separator: true },
            { label: `${$LL.containerPruneContainers()}…`, icon: 'mop', action: () => (pruning = 'prune_containers') },
            { label: `${$LL.containerPruneVolumes()}…`, icon: 'delete_sweep', action: () => (pruning = 'prune_volumes') },
          ]
        : [
            { label: `${$LL.containerPullImage()}…`, icon: 'download', shortcut: '⌘N', action: () => openPull() },
            { separator: true },
            { label: `${$LL.containerPruneImages()}…`, icon: 'mop', action: openImagePrune },
            { label: `${$LL.containerPruneSystem()}…`, icon: 'delete_sweep', action: () => (systemPrune = true) },
          ]
    return [
      { label: $LL.deskMenuFile(), items: file },
      { label: $LL.deskMenuView(), items: [{ label: $LL.refresh(), icon: 'refresh', shortcut: '⌘R', action: () => void refresh() }] },
    ]
  })
</script>

<AppToolbar title={tab === 'containers' ? $LL.containers() : $LL.containerImages()} flush={!!view?.available && (tab === 'containers' ? rows.length > 0 : images.length > 0)}>
  {#snippet actions()}
    {#if view?.available && tab === 'containers'}
      <IconButton icon="mop" label={$LL.containerPruneContainers()} disabled={busy} onclick={() => (pruning = 'prune_containers')} />
      <Button size="sm" variant="primary" icon="add" disabled={busy} onclick={openRun}>{$LL.containerRun()}</Button>
    {:else if view?.available && tab === 'images'}
      <IconButton icon="mop" label={$LL.containerPruneImages()} disabled={busy} onclick={openImagePrune} />
      <Button size="sm" variant="primary" icon="download" disabled={busy} onclick={() => openPull()}>{$LL.containerPullImage()}</Button>
    {/if}
  {/snippet}
</AppToolbar>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection
      title={view?.runtime ? `${view.runtime.kind} ${view.runtime.version ?? ''}`.trim() : undefined}
    >
      <SidebarItem
        label={$LL.containers()}
        icon="deployed_code"
        active={tab === 'containers'}
        trailing={tab === 'containers' && view?.available ? rows.length : undefined}
        onclick={() => {
          tab = 'containers'
          selected = null
        }}
      />
      <SidebarItem
        label={$LL.containerImages()}
        icon="layers"
        active={tab === 'images'}
        trailing={usage?.usage?.image_count ?? (tab === 'images' && view?.available ? images.length : undefined)}
        onclick={() => {
          tab = 'images'
          selected = null
        }}
      />
    </SidebarSection>
  {/snippet}

  {#if error}
    <div class="px-(--content-pad) pb-[9px]"><Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card></div>
  {/if}

  {#if actionExit !== 0}
    <!-- A failure is said even when the runtime printed nothing: the refreshed
         listing alone would look like the action went through. -->
    <div class="px-(--content-pad) pb-[9px]">
      <Card padding="11px 15px">
        {#if actionExit === undefined}
          <p class="text-[13px] text-(--color-danger)">{$LL.containerActionUnfinished()}</p>
        {:else}
          <p class="text-[13px] text-(--color-danger)">{$LL.containerActionFailed({ code: actionExit ?? '?' })}</p>
        {/if}
        {#if actionOutput}<pre class="lk-mono mt-[7px] whitespace-pre-wrap break-all text-[12px]">{actionOutput}</pre>{/if}
      </Card>
    </div>
  {:else if actionOutput}
    <!-- What a successful action printed — a pull's digest, a run's id. Not a
         failure, so not in the danger tone. -->
    <div class="px-(--content-pad) pb-[9px]">
      <Card padding="11px 15px"><pre class="lk-mono whitespace-pre-wrap break-all text-[12px] text-(--text-secondary)">{actionOutput}</pre></Card>
    </div>
  {/if}

  {#if loading && !view}
    <div class="grid flex-1 place-items-center"><Spinner /></div>
  {:else if view && !view.available}
    <div class="px-(--content-pad) pb-[17px]">
      <Card>
        <p class="text-[13px] text-(--text-secondary)">{reasonText(view)}</p>
        {#if view.reason}<pre class="lk-mono mt-[9px] whitespace-pre-wrap break-all text-[12px] text-(--text-tertiary)">{view.reason}</pre>{/if}
      </Card>
    </div>
  {:else if view}
    {#if tab === 'containers'}
      {#if rows.length === 0}
        <div class="flex flex-1 flex-col items-center justify-center gap-[9px] pb-[52px] text-(--text-tertiary)">
          <Icon name="deployed_code" size={55} weight={300} />
          <span class="text-[15px] font-bold text-(--text-secondary)">{$LL.containersEmpty()}</span>
        </div>
      {:else}
        <DataTable
          density={systemPrefs.value.density}
          label={$LL.containers()}
          columns={containerColumns}
          rows={containerLines}
          rowKey="key"
          {selected}
          onselect={(key) => (selected = key as string | null)}
          minWidth={640}
        />
      {/if}
    {:else if images.length === 0}
      <div class="flex flex-1 flex-col items-center justify-center gap-[9px] pb-[52px] text-(--text-tertiary)">
        <Icon name="layers" size={55} weight={300} />
        <span class="text-[15px] font-bold text-(--text-secondary)">{$LL.containersNoImages()}</span>
      </div>
    {:else}
      <DataTable
        density={systemPrefs.value.density}
        label={$LL.containerImages()}
        columns={imageColumns}
        rows={imageLines}
        rowKey="key"
        {selected}
        onselect={(key) => (selected = key as string | null)}
        minWidth={560}
      />
    {/if}
  {/if}
</SplitView>

<WindowFooter>
  {#if selectedRow}
    {@const row = selectedRow}
    <!-- The selected container: what it runs, and what may be done to it. -->
    <div class="mx-[9px] mb-[7px] flex flex-col gap-[9px] rounded-[13px] bg-(--surface-card) py-[13px] pl-[17px] pr-[13px]">
      <div class="flex min-w-0 items-center gap-[9px]">
        <span
          class="h-[9px] w-[9px] shrink-0 rounded-full"
          style:background={dotColor(row) ?? 'transparent'}
          style:box-shadow={dotColor(row) ? undefined : 'inset 0 0 0 1.5px var(--text-tertiary)'}
        ></span>
        <span class="truncate text-[15px] font-bold">{row.name ?? $LL.containerUnknown()}</span>
        {#if row.id}<span class="lk-mono shrink-0 text-[12px] text-(--text-tertiary)">{row.id.slice(0, 12)}</span>{/if}
        {#if row.raw_status}<span class="min-w-0 truncate text-[12px] text-(--text-secondary)">{row.raw_status}</span>{/if}
        <span class="flex-1"></span>
        <IconButton icon="close" label={$LL.close()} size="sm" onclick={() => (selected = null)} />
      </div>
      {#if row.stats}
        <p class="lk-num truncate text-[12px] text-(--text-secondary)">
          {$LL.containerCpu()} {row.stats.cpu ?? '—'}{#if row.stats.cpu_avg} / {row.stats.cpu_avg}{/if}
          · {$LL.containerMemory()} {row.stats.mem ?? '—'}
          · {$LL.containerNetwork()} ↓ {row.stats.net_down ?? '—'} ↑ {row.stats.net_up ?? '—'}
          · {$LL.containerDisk()} R {row.stats.disk_read ?? '—'} W {row.stats.disk_write ?? '—'}
        </p>
      {/if}
      <div class="flex flex-wrap items-center gap-[7px]">
        {#each lifecycle(row) as kind (kind)}
          {@const button = BUTTONS[kind]}
          {#if button}
            <Button
              size="sm"
              variant={kind === 'start' ? 'primary' : kind === 'remove' ? 'ghost' : 'secondary'}
              class={kind === 'remove' ? '!text-(--color-danger)' : ''}
              icon={button.icon}
              disabled={busy}
              onclick={() => click(kind, row)}>{button.label()}</Button
            >
          {/if}
        {/each}
        {#if busy}<Spinner size="sm" />{/if}
        <span class="flex-1"></span>
        {#if row.actions.includes('logs') && row.id}
          <Button variant="ghost" size="sm" icon="receipt_long" onclick={() => void openLogs(row)}>{$LL.containerLogs()}</Button>
        {/if}
      </div>
    </div>
  {:else if selectedImage}
    {@const image = selectedImage}
    <div class="mx-[9px] mb-[7px] flex flex-wrap items-center gap-[9px] rounded-[13px] bg-(--surface-card) py-[11px] pl-[17px] pr-[13px]">
      <span class="min-w-0 truncate text-[15px] font-bold">{imageLines.find((l) => l.key === selected)?.reference}</span>
      <span class="flex-1"></span>
      <!-- A dangling image has no reference to pull: `docker pull <none>`
           would be a name that is not one. -->
      <Button size="sm" variant="secondary" icon="download" disabled={busy || image.dangling} onclick={() => openPull(image)}>{$LL.containerPullImage()}</Button>
      <Button size="sm" variant="ghost" class="!text-(--color-danger)" icon="delete" disabled={busy} onclick={() => (imageConfirm = image)}>{$LL.containerRemove()}</Button>
    </div>
  {/if}
  <StatusBar>
    {#if usage?.usage}
      <!-- `system df` walks the whole image store, so this is one line about
           the store rather than a list of its own. -->
      <span class="truncate">
        {$LL.containerUsage({ images: usage.usage.image_count ?? 0, reclaimable: fmtBytes(usage.usage.reclaimable_bytes ?? 0) })}
      </span>
    {/if}
    {#if tab === 'images' && view?.unused_tagged}<span class="truncate text-(--text-tertiary)">· {$LL.containerUnusedImages({ count: view.unused_tagged })}</span>{/if}
    <span class="flex-1"></span>
    {#if view?.available}
      {#if tab === 'containers'}
        <Button variant="ghost" size="sm" disabled={busy} onclick={() => (pruning = 'prune_volumes')}>{$LL.containerPruneVolumes()}</Button>
      {:else}
        <Button variant="ghost" size="sm" disabled={busy} onclick={() => (systemPrune = true)}>{$LL.containerPruneSystem()}</Button>
      {/if}
    {/if}
    <IconButton icon="refresh" size="sm" label={$LL.refresh()} onclick={() => void refresh()} disabled={loading} />
  </StatusBar>
</WindowFooter>

<!-- Removal is the one action that is asked about: it is the only one whose
     result is not already on the screen behind the dialog, and `force` changes
     what it does to a container that is running. -->
{#if confirming !== undefined}
  <Dialog open title={$LL.containerRemove()} message={$LL.containerRemoveConfirm({ name: confirming.name ?? confirming.id ?? $LL.containerUnknown() })} onclose={() => (confirming = undefined)}>
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} onclick={() => {
        const row = confirming
        confirming = undefined
        if (row?.id) void act({ action: 'remove', id: row.id, force })
      }}>{$LL.containerRemove()}</Button>
      <Button variant="secondary" block onclick={() => (confirming = undefined)}>{$LL.cancel()}</Button>
    {/snippet}
    <Checkbox bind:checked={force} label={$LL.containerRemoveForce()} />
    {#if force}<p class="mt-[7px] text-[12px] text-(--text-secondary)">{$LL.containerRemoveForceHint()}</p>{/if}
  </Dialog>
{/if}

{#if pruning !== undefined}
  <Dialog
    open
    title={pruning === 'prune_volumes' ? $LL.containerPruneVolumes() : $LL.containerPruneContainers()}
    message={pruning === 'prune_volumes' ? $LL.containerPruneVolumesConfirm() : $LL.containerPruneContainersConfirm()}
    onclose={() => (pruning = undefined)}
  >
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} onclick={() => {
        const action = pruning
        pruning = undefined
        if (action) void act({ action })
      }}>{pruning === 'prune_volumes' ? $LL.containerPruneVolumes() : $LL.containerPruneContainers()}</Button>
      <Button variant="secondary" block onclick={() => (pruning = undefined)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if logsFor !== undefined}
  <Dialog open wide title={$LL.containerLogs()} onclose={() => (logsFor = undefined)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (logsFor = undefined)}>{$LL.close()}</Button>
    {/snippet}
    <p class="text-[12px] text-(--text-tertiary)">
      {$LL.containerLogsFor({
        name: logsFor.name ?? logsFor.id ?? $LL.containerUnknown(),
        lines: LOG_TAIL,
      })}
    </p>
    {#if logsError}
      <pre class="lk-mono mt-[9px] whitespace-pre-wrap break-all text-[12px] text-(--color-danger)">{logsError}</pre>
    {:else if logs}
      <pre class="mt-[9px] max-h-96 overflow-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] lk-mono whitespace-pre-wrap break-all text-[13px]">{logs}</pre>
    {:else}
      <p class="mt-[9px] text-[13px] text-(--text-secondary)">{$LL.containerLogsEmpty()}</p>
    {/if}
  </Dialog>
{/if}

<!-- Removing an image is asked about like removing a container: it is the one
     image action whose result is not already on the screen behind the dialog. -->
{#if imageConfirm !== undefined}
  <Dialog open title={$LL.containerRemove()} message={$LL.containerRemoveImageConfirm({ name: imageReference(imageConfirm) })} onclose={() => (imageConfirm = undefined)}>
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} onclick={() => {
        const image = imageConfirm
        imageConfirm = undefined
        // The tag on the row, not the id: `rmi -f <id>` removes every tag
        // the image has, and the user picked one. Only an image with no
        // name is removed by its id.
        const id = image?.dangling ? image.id : image && imageReference(image)
        if (id) void act({ action: 'remove_image', id })
      }}>{$LL.containerRemove()}</Button>
      <Button variant="secondary" block onclick={() => (imageConfirm = undefined)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

<!-- Pull: one field, prefilled when a row's Pull asked for it, so the header
     action and the row action are the same dialog. -->
{#if pullOpen}
  <Dialog open wide title={$LL.containerPullImage()} onclose={() => (pullOpen = false)}>
    {#snippet actions()}
      <Button variant="primary" disabled={busy || pullRef.trim() === ''} onclick={() => {
        const reference = pullRef.trim()
        pullOpen = false
        if (reference) void act({ action: 'pull_image', reference })
      }}>{$LL.containerPullImage()}</Button>
      <Button variant="secondary" onclick={() => (pullOpen = false)}>{$LL.cancel()}</Button>
    {/snippet}
    <Input bind:value={pullRef} label={$LL.containerRunImage()} placeholder="nginx:alpine" autocomplete="off" />
    <p class="mt-[9px] text-[12px] text-(--text-secondary)">{$LL.containerPullImageHint()}</p>
  </Dialog>
{/if}

<!-- Image prune: the counts come from the agent, and the checkbox widens the
     scope from dangling to every unused image. -->
{#if imagePrune}
  <Dialog open title={$LL.containerPruneImages()} message={$LL.containerPruneImagesConfirm()} onclose={() => (imagePrune = false)}>
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} onclick={() => {
        const allUnused = pruneAllUnused
        imagePrune = false
        void act({ action: 'prune_images', all_unused: allUnused })
      }}>{$LL.containerPruneImages()}</Button>
      <Button variant="secondary" block onclick={() => (imagePrune = false)}>{$LL.cancel()}</Button>
    {/snippet}
    <p class="text-[12px] text-(--text-secondary)">
      {$LL.containerPruneDangling()}: <span class="lk-num">{danglingCount}</span> ·
      {$LL.containerUnusedTagged()}: <span class="lk-num">{view?.unused_tagged ?? $LL.containerUnknown()}</span>
    </p>
    <Checkbox class="mt-[9px]" bind:checked={pruneAllUnused} label={$LL.containerPruneAllUnused()} />
  </Dialog>
{/if}

{#if systemPrune}
  <Dialog open title={$LL.containerPruneSystem()} message={$LL.containerPruneSystemConfirm()} onclose={() => (systemPrune = false)}>
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} onclick={() => {
        const allUnusedImages = systemAllImages
        const includeVolumes = systemVolumes
        systemPrune = false
        void act({
          action: 'prune_system',
          all_unused_images: allUnusedImages,
          include_volumes: includeVolumes,
        })
      }}>{$LL.containerPruneSystem()}</Button>
      <Button variant="secondary" block onclick={() => (systemPrune = false)}>{$LL.cancel()}</Button>
    {/snippet}
    <div class="grid gap-[9px]">
      <Checkbox bind:checked={systemAllImages} label={$LL.containerPruneAllUnusedImages()} />
      <Checkbox bind:checked={systemVolumes} label={$LL.containerPruneVolumesOption()} />
    </div>
  </Dialog>
{/if}

<!-- Run: image, name and the extra arguments, as the app's dialog asks for
     them. The arguments are sent as typed; the agent splits them. -->
{#if runOpen}
  <Dialog open wide title={$LL.containerRun()} onclose={() => (runOpen = false)}>
    {#snippet actions()}
      <Button variant="primary" disabled={busy || runImage.trim() === ''} onclick={() => {
        const image = runImage.trim()
        const name = runName.trim()
        const args = runArgs
        runOpen = false
        void act({ action: 'run', image, name, args })
      }}>{$LL.containerRun()}</Button>
      <Button variant="secondary" onclick={() => (runOpen = false)}>{$LL.cancel()}</Button>
    {/snippet}
    <div class="grid gap-[13px]">
      <Input bind:value={runImage} label={$LL.containerRunImage()} placeholder="xxx:1.1" autocomplete="off" />
      <Input bind:value={runName} label={$LL.containerRunName()} placeholder="xxx" autocomplete="off" />
      <Input bind:value={runArgs} label={$LL.containerRunArgs()} placeholder="-p 2222:22 -v ~/.xxx/:/xxx" autocomplete="off" />
    </div>
  </Dialog>
{/if}

<!-- A shell inside a container. Its own component: the terminal setup is the
     terminal page's, shared through `mountTerminal`. -->
{#if shellFor !== undefined}
  <Dialog open wide title={$LL.containerOpenShell()} onclose={() => (shellFor = undefined)}>
    <p class="text-[12px] text-(--text-tertiary)">{shellFor.name ?? shellFor.id ?? $LL.containerUnknown()}</p>
    {#if shellFor.id}<div class="mt-[9px]"><TargetTerminal target={{ kind: 'container', id: shellFor.id }} /></div>{/if}
  </Dialog>
{/if}
