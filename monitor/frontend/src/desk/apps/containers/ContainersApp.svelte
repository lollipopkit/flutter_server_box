<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import {
    CircleAlert,
    Container,
    Download,
    Eraser,
    Layers,
    Play,
    Plus,
    RefreshCw,
    RotateCw,
    ScrollText,
    Square,
    Terminal,
    Trash2,
    type LucideIcon,
  } from '@lucide/svelte'
  import TargetTerminal from '../../../components/TargetTerminal.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import SourceGroup from '../../ui/SourceGroup.svelte'
  import SourceItem from '../../ui/SourceItem.svelte'
  import SplitView from '../../ui/SplitView.svelte'
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
  const BUTTONS: Record<
    ContainerActionKind,
    { label: () => string; icon: LucideIcon } | null
  > = {
    start: { label: () => $LL.containerStart(), icon: Play },
    stop: { label: () => $LL.containerStop(), icon: Square },
    restart: { label: () => $LL.containerRestart(), icon: RotateCw },
    remove: { label: () => $LL.containerRemove(), icon: Trash2 },
    logs: { label: () => $LL.containerLogs(), icon: ScrollText },
    terminal: { label: () => $LL.containerOpenShell(), icon: Terminal },
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

  /// The row's state dot. The badge beside it spells the same state out; the
  /// dot is what lets a long list be read down a column.
  function statusDot(row: ContainerRow): string {
    switch (statusTone(row)) {
      case 'success':
        return 'bg-success'
      case 'danger':
        return 'bg-danger'
      case 'warning':
        return 'bg-warning'
      default:
        return 'bg-faint-fg'
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
</script>

<AppToolbar
  subtitle={view?.runtime
    ? $LL.containerRuntime({
        runtime: view.runtime.kind,
        version: view.runtime.version ?? $LL.containerUnknown(),
      })
    : undefined}
>
  {#snippet actions()}
    {#if view?.available && tab === 'containers'}
      <IconButton label={$LL.containerRun()} disabled={busy} onclick={openRun}>
        <Plus class="w-4 h-4" />
      </IconButton>
      <IconButton label={$LL.containerPruneContainers()} disabled={busy} onclick={() => (pruning = 'prune_containers')}>
        <Eraser class="w-4 h-4" />
      </IconButton>
      <IconButton label={$LL.containerPruneVolumes()} disabled={busy} onclick={() => (pruning = 'prune_volumes')}>
        <Eraser class="w-4 h-4" />
      </IconButton>
    {:else if view?.available && tab === 'images'}
      <IconButton label={$LL.containerPullImage()} disabled={busy} onclick={() => openPull()}>
        <Download class="w-4 h-4" />
      </IconButton>
      <IconButton label={$LL.containerPruneImages()} disabled={busy} onclick={openImagePrune}>
        <Eraser class="w-4 h-4" />
      </IconButton>
      <IconButton label={$LL.containerPruneSystem()} disabled={busy} onclick={() => (systemPrune = true)}>
        <Eraser class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} onclick={() => void refresh()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</AppToolbar>

<!-- The split view starts under the toolbar, as Files' does: the window body is
     `relative` and the toolbar is 3rem plus its hairline. -->
<div class="absolute inset-x-0 bottom-0 top-[calc(3rem+1px)] min-h-0">
  <SplitView width={13}>
    {#snippet sidebar()}
      <SourceGroup>
        <SourceItem
          label={$LL.containers()}
          icon={Container}
          selected={tab === 'containers'}
          onclick={() => (tab = 'containers')}
        />
        <SourceItem
          label={$LL.containerImages()}
          icon={Layers}
          selected={tab === 'images'}
          onclick={() => (tab = 'images')}
        />
      </SourceGroup>
    {/snippet}

    <div class="space-y-3 p-3">
      {#if error}
        <Card class="border-danger/40 bg-danger/5 p-3">
          <p class="text-sm text-danger">{error}</p>
        </Card>
      {/if}

      {#if actionExit === 0}
        <!-- What a successful action printed — a pull's digest, a run's id. Not a
             failure, so not in the danger tone. -->
        {#if actionOutput}
          <Card class="p-3">
            <pre class="text-xs font-mono text-muted-fg whitespace-pre-wrap break-all">{actionOutput}</pre>
          </Card>
        {/if}
      {:else}
        <!-- A failure is said even when the runtime printed nothing: the refreshed
             listing alone would look like the action went through. -->
        <Card class="space-y-2 border-danger/40 bg-danger/5 p-3">
          {#if actionExit === undefined}
            <p class="text-sm text-danger">{$LL.containerActionUnfinished()}</p>
          {:else}
            <p class="text-sm text-danger">{$LL.containerActionFailed({ code: actionExit ?? '?' })}</p>
          {/if}
          {#if actionOutput}
            <pre class="text-xs font-mono text-fg whitespace-pre-wrap break-all">{actionOutput}</pre>
          {/if}
        </Card>
      {/if}

      {#if loading && !view}
        <Card class="grid place-items-center p-8"><Spinner class="h-5 w-5" /></Card>
      {:else if view && !view.available}
        <Card class="space-y-2 p-4">
          <p class="text-sm text-muted-fg">{reasonText(view)}</p>
          {#if view.reason}
            <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.reason}</pre>
          {/if}
        </Card>
      {:else if view}
        {#if usage?.usage}
          <!-- `system df` walks the whole image store, so this is one line about
               the store rather than a list of its own. -->
          <Card class="p-3">
            <p class="text-xs text-muted-fg">
              {$LL.containerUsage({
                images: usage.usage.image_count ?? 0,
                reclaimable: fmtBytes(usage.usage.reclaimable_bytes ?? 0),
              })}
            </p>
          </Card>
        {/if}

        {#if tab === 'containers'}
          {#if rows.length === 0}
            <Card class="p-4">
              <p class="text-sm text-muted-fg">{$LL.containerEmpty()}</p>
            </Card>
          {:else}
            <!-- One container per card: the state dot and badge on the top row,
                 what it runs below, and the lifecycle actions along the right. -->
            <ul class="space-y-2">
              {#each rows as row (row.id ?? row.name)}
                <li
                  class="rounded-xl border border-line bg-surface px-3 py-2.5 transition-colors hover:bg-soft/40"
                >
                  <div class="flex items-center gap-2.5">
                    <span class="h-2 w-2 shrink-0 rounded-full {statusDot(row)}"></span>
                    <span class="min-w-0 flex-1 truncate text-[0.85rem] font-medium text-fg-strong">
                      {row.name ?? row.id ?? $LL.containerUnknown()}
                    </span>
                    <Badge tone={statusTone(row)}>{statusText(row)}</Badge>
                    {#if row.project}
                      <Badge tone="neutral">{row.project}</Badge>
                    {/if}
                    {#if !busy}
                      <div class="flex shrink-0 items-center gap-0.5">
                        {#each lifecycle(row) as kind (kind)}
                          {@const button = BUTTONS[kind]}
                          {#if button}
                            {@const ActionIcon = button.icon}
                            <IconButton label={button.label()} onclick={() => click(kind, row)}>
                              <ActionIcon class="h-4 w-4" />
                            </IconButton>
                          {/if}
                        {/each}
                      </div>
                    {/if}
                  </div>
                  <p class="mt-1 truncate pl-[1.125rem] text-xs text-muted-fg">
                    {row.image ?? $LL.containerUnknown()}
                    {#if row.ports}
                      · <span class="font-mono">{row.ports}</span>
                    {/if}
                    {#if row.raw_status}
                      · {row.raw_status}
                    {/if}
                  </p>
                  {#if row.stats}
                    <p class="mt-0.5 truncate pl-[1.125rem] text-[0.7rem] text-faint-fg">
                      {$LL.containerCpu()}: {row.stats.cpu ?? '—'}
                      {#if row.stats.cpu_avg}
                        / {row.stats.cpu_avg}
                      {/if}
                      · {$LL.containerMemory()}: {row.stats.mem ?? '—'}
                      · {$LL.containerNetwork()}: ↓ {row.stats.net_down ?? '—'} ↑ {row.stats.net_up ?? '—'}
                      · {$LL.containerDisk()}: R {row.stats.disk_read ?? '—'} W {row.stats.disk_write ?? '—'}
                    </p>
                  {/if}
                  {#if row.actions.includes('logs') && row.id}
                    <button
                      class="mt-1 ml-[1.125rem] text-xs text-accent hover:underline"
                      onclick={() => void openLogs(row)}
                    >
                      {$LL.containerLogs()}
                    </button>
                  {/if}
                </li>
              {/each}
            </ul>
          {/if}
        {:else if images.length === 0}
          <Card class="p-4">
            <p class="text-sm text-muted-fg">{$LL.containerNoImages()}</p>
          </Card>
        {:else}
          <ul class="space-y-2">
            {#each images as image (image.id ?? image.repository)}
              <li
                class="flex items-start gap-3 rounded-xl border border-line bg-surface px-3 py-2.5 transition-colors hover:bg-soft/40"
              >
                <Layers class="mt-0.5 h-4 w-4 shrink-0 text-faint-fg" />
                <div class="min-w-0 flex-1 space-y-0.5">
                  <p class="truncate text-[0.85rem] text-fg-strong">
                    {image.repository}{#if image.tag}:<span class="font-mono">{image.tag}</span>{/if}
                  </p>
                  <p class="truncate text-xs text-muted-fg">
                    {#if image.id}<span class="font-mono">{image.id.slice(0, 12)}</span> · {/if}
                    {image.size ?? $LL.containerUnknown()}
                    ·
                    {#if image.containers === null}
                      <!-- Unknown, never zero: a count this agent could not confirm
                           is not a count of none. -->
                      {$LL.containerUsageUnknown()}
                    {:else if image.containers === 0}
                      {$LL.containerUnused()}
                    {:else}
                      {$LL.containerInUse({ count: image.containers })}
                    {/if}
                    {#if image.created_at}· {image.created_at}{/if}
                  </p>
                </div>
                {#if !busy}
                  <div class="flex shrink-0 items-center gap-0.5">
                    <!-- A dangling image has no reference to pull: `docker pull
                         <none>` would be a name that is not one. -->
                    <IconButton
                      label={$LL.containerPullImage()}
                      disabled={image.dangling}
                      onclick={() => openPull(image)}
                    >
                      <Download class="h-4 w-4" />
                    </IconButton>
                    <IconButton label={$LL.containerRemove()} onclick={() => (imageConfirm = image)}>
                      <Trash2 class="h-4 w-4" />
                    </IconButton>
                  </div>
                {/if}
              </li>
            {/each}
          </ul>
          {#if view.unused_tagged !== null && view.unused_tagged > 0}
            <p class="px-1 text-xs text-muted-fg">
              {$LL.containerUnusedImages({ count: view.unused_tagged })}
            </p>
          {/if}
        {/if}

        {#if busy}
          <div class="flex items-center gap-2 px-1 text-xs text-muted-fg">
            <Spinner size="sm" />
          </div>
        {/if}
      {/if}
    </div>
  </SplitView>
</div>

<!-- Removal is the one action that is asked about: it is the only one whose
     result is not already on the screen behind the dialog, and `force` changes
     what it does to a container that is running. -->
{#if confirming !== undefined}
  <Modal open title={$LL.containerRemove()} onclose={() => (confirming = undefined)}>
    <div class="space-y-4">
      <p class="text-sm text-fg">
        {$LL.containerRemoveConfirm({
          name: confirming.name ?? confirming.id ?? $LL.containerUnknown(),
        })}
      </p>
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={force} />
        {$LL.containerRemoveForce()}
      </label>
      {#if force}
        <p class="text-xs text-muted-fg inline-flex items-center gap-1">
          <CircleAlert class="w-3.5 h-3.5 shrink-0" />
          {$LL.containerRemoveForceHint()}
        </p>
      {/if}
      <div class="flex justify-end gap-2 border-t border-line pt-3">
        <Button variant="secondary" onclick={() => (confirming = undefined)}>{$LL.cancel()}</Button>
        <Button
          disabled={busy}
          onclick={() => {
            const row = confirming
            confirming = undefined
            if (row?.id) void act({ action: 'remove', id: row.id, force })
          }}
        >
          {$LL.containerRemove()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if pruning !== undefined}
  <Modal
    open
    title={pruning === 'prune_volumes' ? $LL.containerPruneVolumes() : $LL.containerPruneContainers()}
    onclose={() => (pruning = undefined)}
  >
    <div class="space-y-4">
      <p class="text-sm text-fg">
        {pruning === 'prune_volumes' ? $LL.containerPruneVolumesConfirm() : $LL.containerPruneContainersConfirm()}
      </p>
      <div class="flex justify-end gap-2 border-t border-line pt-3">
        <Button variant="secondary" onclick={() => (pruning = undefined)}>{$LL.cancel()}</Button>
        <Button
          variant="danger"
          disabled={busy}
          onclick={() => {
            const action = pruning
            pruning = undefined
            if (action) void act({ action })
          }}
        >
          {pruning === 'prune_volumes' ? $LL.containerPruneVolumes() : $LL.containerPruneContainers()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if logsFor !== undefined}
  <Modal open title={$LL.containerLogs()} onclose={() => (logsFor = undefined)}>
    <div class="space-y-3">
      <p class="text-xs text-muted-fg">
        {$LL.containerLogsFor({
          name: logsFor.name ?? logsFor.id ?? $LL.containerUnknown(),
          lines: LOG_TAIL,
        })}
      </p>
      {#if logsError}
        <pre class="text-xs font-mono text-danger whitespace-pre-wrap break-all">{logsError}</pre>
      {:else if logs}
        <pre
          class="max-h-96 overflow-auto rounded border border-line bg-surface p-3 text-xs font-mono text-fg whitespace-pre-wrap break-all">{logs}</pre>
      {:else}
        <p class="text-sm text-muted-fg">{$LL.containerLogsEmpty()}</p>
      {/if}
      <div class="flex justify-end">
        <Button variant="secondary" onclick={() => (logsFor = undefined)}>{$LL.close()}</Button>
      </div>
    </div>
  </Modal>
{/if}

<!-- Removing an image is asked about like removing a container: it is the one
     image action whose result is not already on the screen behind the dialog. -->
{#if imageConfirm !== undefined}
  <Modal open title={$LL.containerRemove()} onclose={() => (imageConfirm = undefined)}>
    <div class="space-y-4">
      <p class="text-sm text-fg">
        {$LL.containerRemoveImageConfirm({ name: imageReference(imageConfirm) })}
      </p>
      <div class="flex justify-end gap-2 border-t border-line pt-3">
        <Button variant="secondary" onclick={() => (imageConfirm = undefined)}>{$LL.cancel()}</Button>
        <Button
          variant="danger"
          disabled={busy}
          onclick={() => {
            const image = imageConfirm
            imageConfirm = undefined
            // The tag on the row, not the id: `rmi -f <id>` removes every tag
            // the image has, and the user picked one. Only an image with no
            // name is removed by its id.
            const id = image?.dangling ? image.id : image && imageReference(image)
            if (id) void act({ action: 'remove_image', id })
          }}
        >
          {$LL.containerRemove()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

<!-- Pull: one field, prefilled when a row's Pull asked for it, so the header
     action and the row action are the same dialog. -->
{#if pullOpen}
  <Modal open title={$LL.containerPullImage()} onclose={() => (pullOpen = false)}>
    <div class="space-y-4">
      <div class="space-y-1">
        <span class="text-sm text-muted-fg">{$LL.containerRunImage()}</span>
        <Input bind:value={pullRef} placeholder="nginx:alpine" autocomplete="off" />
      </div>
      <p class="text-xs text-muted-fg">{$LL.containerPullImageHint()}</p>
      <div class="flex justify-end gap-2 border-t border-line pt-3">
        <Button variant="secondary" onclick={() => (pullOpen = false)}>{$LL.cancel()}</Button>
        <Button
          disabled={busy || pullRef.trim() === ''}
          onclick={() => {
            const reference = pullRef.trim()
            pullOpen = false
            if (reference) void act({ action: 'pull_image', reference })
          }}
        >
          {$LL.containerPullImage()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

<!-- Image prune: the counts come from the agent, and the checkbox widens the
     scope from dangling to every unused image. -->
{#if imagePrune}
  <Modal open title={$LL.containerPruneImages()} onclose={() => (imagePrune = false)}>
    <div class="space-y-4">
      <p class="text-sm text-fg">{$LL.containerPruneImagesConfirm()}</p>
      <p class="text-xs text-muted-fg">
        {$LL.containerPruneDangling()}: {danglingCount} ·
        {$LL.containerUnusedTagged()}:
        {view?.unused_tagged ?? $LL.containerUnknown()}
      </p>
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={pruneAllUnused} />
        {$LL.containerPruneAllUnused()}
      </label>
      <div class="flex justify-end gap-2 border-t border-line pt-3">
        <Button variant="secondary" onclick={() => (imagePrune = false)}>{$LL.cancel()}</Button>
        <Button
          variant="danger"
          disabled={busy}
          onclick={() => {
            const allUnused = pruneAllUnused
            imagePrune = false
            void act({ action: 'prune_images', all_unused: allUnused })
          }}
        >
          {$LL.containerPruneImages()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if systemPrune}
  <Modal open title={$LL.containerPruneSystem()} onclose={() => (systemPrune = false)}>
    <div class="space-y-4">
      <p class="text-sm text-fg">{$LL.containerPruneSystemConfirm()}</p>
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={systemAllImages} />
        {$LL.containerPruneAllUnusedImages()}
      </label>
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={systemVolumes} />
        {$LL.containerPruneVolumesOption()}
      </label>
      <div class="flex justify-end gap-2 border-t border-line pt-3">
        <Button variant="secondary" onclick={() => (systemPrune = false)}>{$LL.cancel()}</Button>
        <Button
          variant="danger"
          disabled={busy}
          onclick={() => {
            const allUnusedImages = systemAllImages
            const includeVolumes = systemVolumes
            systemPrune = false
            void act({
              action: 'prune_system',
              all_unused_images: allUnusedImages,
              include_volumes: includeVolumes,
            })
          }}
        >
          {$LL.containerPruneSystem()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

<!-- Run: image, name and the extra arguments, as the app's dialog asks for
     them. The arguments are sent as typed; the agent splits them. -->
{#if runOpen}
  <Modal open title={$LL.containerRun()} onclose={() => (runOpen = false)}>
    <div class="space-y-4">
      <div class="space-y-1">
        <span class="text-sm text-muted-fg">{$LL.containerRunImage()}</span>
        <Input bind:value={runImage} placeholder="xxx:1.1" autocomplete="off" />
      </div>
      <div class="space-y-1">
        <span class="text-sm text-muted-fg">{$LL.containerRunName()}</span>
        <Input bind:value={runName} placeholder="xxx" autocomplete="off" />
      </div>
      <div class="space-y-1">
        <span class="text-sm text-muted-fg">{$LL.containerRunArgs()}</span>
        <Input bind:value={runArgs} placeholder="-p 2222:22 -v ~/.xxx/:/xxx" autocomplete="off" />
      </div>
      <div class="flex justify-end gap-2 border-t border-line pt-3">
        <Button variant="secondary" onclick={() => (runOpen = false)}>{$LL.cancel()}</Button>
        <Button
          disabled={busy || runImage.trim() === ''}
          onclick={() => {
            const image = runImage.trim()
            const name = runName.trim()
            const args = runArgs
            runOpen = false
            void act({ action: 'run', image, name, args })
          }}
        >
          {$LL.containerRun()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

<!-- A shell inside a container. Its own component: the terminal setup is the
     terminal page's, shared through `mountTerminal`. -->
{#if shellFor !== undefined}
  <Modal
    open
    title={$LL.containerOpenShell()}
    class="max-w-3xl"
    onclose={() => (shellFor = undefined)}
  >
    <div class="space-y-3">
      <p class="text-xs text-muted-fg">
        {shellFor.name ?? shellFor.id ?? $LL.containerUnknown()}
      </p>
      {#if shellFor.id}
        <TargetTerminal target={{ kind: 'container', id: shellFor.id }} />
      {/if}
    </div>
  </Modal>
{/if}
