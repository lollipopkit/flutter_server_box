<script lang="ts">
  import Spinner from '../../lk/Spinner.svelte'
  import { Badge, Button, Card, Checkbox, Dialog, Icon, IconButton, Input, SidebarItem, SidebarSection } from '../../lk'
  import TargetTerminal from '../../../components/TargetTerminal.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
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
      <Button size="sm" variant="tinted" icon="add" disabled={busy} onclick={openRun}>{$LL.containerRun()}</Button>
      <IconButton icon="delete_sweep" label={$LL.containerPruneContainers()} disabled={busy} onclick={() => (pruning = 'prune_containers')} />
      <IconButton icon="delete_sweep" label={$LL.containerPruneVolumes()} disabled={busy} onclick={() => (pruning = 'prune_volumes')} />
    {:else if view?.available && tab === 'images'}
      <IconButton icon="download" label={$LL.containerPullImage()} disabled={busy} onclick={() => openPull()} />
      <IconButton icon="delete_sweep" label={$LL.containerPruneImages()} disabled={busy} onclick={openImagePrune} />
      <IconButton icon="delete_sweep" label={$LL.containerPruneSystem()} disabled={busy} onclick={() => (systemPrune = true)} />
    {/if}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void refresh()} disabled={loading} />
  {/snippet}
</AppToolbar>

<SplitView width={13}>
  {#snippet sidebar()}
    <SidebarSection>
      <SidebarItem
        label={$LL.containers()}
        icon="deployed_code"
        active={tab === 'containers'}
        onclick={() => (tab = 'containers')}
      />
      <SidebarItem
        label={$LL.containerImages()}
        icon="inventory_2"
        active={tab === 'images'}
        onclick={() => (tab = 'images')}
      />
    </SidebarSection>
  {/snippet}

  <div class="space-y-[9px] px-[17px] pb-[17px] pt-[4px]">
    {#if error}
      <Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card>
    {/if}

    {#if actionExit === 0}
      <!-- What a successful action printed — a pull's digest, a run's id. Not a
           failure, so not in the danger tone. -->
      {#if actionOutput}
        <Card padding="11px 15px">
          <pre class="lk-mono whitespace-pre-wrap break-all text-[12px] text-(--text-secondary)">{actionOutput}</pre>
        </Card>
      {/if}
    {:else}
      <!-- A failure is said even when the runtime printed nothing: the refreshed
           listing alone would look like the action went through. -->
      <Card padding="11px 15px">
        {#if actionExit === undefined}
          <p class="text-[13px] text-(--color-danger)">{$LL.containerActionUnfinished()}</p>
        {:else}
          <p class="text-[13px] text-(--color-danger)">{$LL.containerActionFailed({ code: actionExit ?? '?' })}</p>
        {/if}
        {#if actionOutput}
          <pre class="lk-mono mt-[7px] whitespace-pre-wrap break-all text-[12px]">{actionOutput}</pre>
        {/if}
      </Card>
    {/if}

    {#if loading && !view}
      <Card class="grid place-items-center" padding="21px"><Spinner class="h-5 w-5" /></Card>
    {:else if view && !view.available}
      <Card>
        <p class="text-[13px] text-(--text-secondary)">{reasonText(view)}</p>
        {#if view.reason}
          <pre class="lk-mono mt-[9px] whitespace-pre-wrap break-all text-[12px] text-(--text-tertiary)">{view.reason}</pre>
        {/if}
      </Card>
    {:else if view}
      {#if usage?.usage}
        <!-- `system df` walks the whole image store, so this is one line about
             the store rather than a list of its own. -->
        <Card padding="11px 15px">
          <p class="text-[12px] text-(--text-secondary)">
            {$LL.containerUsage({
              images: usage.usage.image_count ?? 0,
              reclaimable: fmtBytes(usage.usage.reclaimable_bytes ?? 0),
            })}
          </p>
        </Card>
      {/if}

      {#if tab === 'containers'}
        {#if rows.length === 0}
          <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
            <Icon name="deployed_code" size={48} weight={300} />
            <span class="text-[13px]">{$LL.containersEmpty()}</span>
          </div>
        {:else}
          <!-- One container per card: state and lifecycle actions are at the
               right, with image, ports and usage beneath the name. -->
          <ul class="space-y-[7px]">
            {#each rows as row (row.id ?? row.name)}
              <li>
                <Card padding="11px 13px">
                  <div class="flex min-w-0 items-center gap-[13px]">
                    <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised) text-(--color-accent-text)">
                      <Icon name="deployed_code" size={18} />
                    </span>
                    <div class="min-w-0 flex-1">
                      <div class="flex min-w-0 items-center gap-[7px]">
                        <span class="truncate text-[13px] font-semibold">{row.name ?? $LL.containerUnknown()}</span>
                        {#if row.id}<span class="lk-mono shrink-0 text-[12px] text-(--text-tertiary)">#{row.id.slice(0, 12)}</span>{/if}
                      </div>
                      <p class="truncate text-[12px] text-(--text-tertiary)">
                        {row.image ?? $LL.containerUnknown()}
                        {#if row.ports} · <span class="lk-mono">{row.ports}</span>{/if}
                        {#if row.raw_status} · {row.raw_status}{/if}
                      </p>
                    </div>
                    <Badge tone={statusTone(row)} dot>{statusText(row)}</Badge>
                    {#if row.project}<Badge tone="neutral">{row.project}</Badge>{/if}
                    {#if !busy}
                      <div class="flex shrink-0 items-center gap-[3px]">
                        {#each lifecycle(row) as kind (kind)}
                          {@const button = BUTTONS[kind]}
                          {#if button}
                            <IconButton icon={button.icon} label={button.label()} onclick={() => click(kind, row)} />
                          {/if}
                        {/each}
                      </div>
                    {/if}
                  </div>
                  {#if row.stats}
                    <p class="lk-num mt-[7px] truncate pl-[47px] text-[12px] text-(--text-tertiary)">
                      {$LL.containerCpu()}: {row.stats.cpu ?? '—'}
                      {#if row.stats.cpu_avg} / {row.stats.cpu_avg}{/if}
                      · {$LL.containerMemory()}: {row.stats.mem ?? '—'}
                      · {$LL.containerNetwork()}: ↓ {row.stats.net_down ?? '—'} ↑ {row.stats.net_up ?? '—'}
                      · {$LL.containerDisk()}: R {row.stats.disk_read ?? '—'} W {row.stats.disk_write ?? '—'}
                    </p>
                  {/if}
                  {#if row.actions.includes('logs') && row.id}
                    <button class="ml-[47px] mt-[7px] text-[12px] text-(--color-accent-text)" onclick={() => void openLogs(row)}>
                      {$LL.containerLogs()}
                    </button>
                  {/if}
                </Card>
              </li>
            {/each}
          </ul>
        {/if}
      {:else if images.length === 0}
        <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
          <Icon name="inventory_2" size={48} weight={300} />
          <span class="text-[13px]">{$LL.containersNoImages()}</span>
          <p class="max-w-md text-center text-[12px]">{$LL.containerNoImages()}</p>
        </div>
      {:else}
        <ul class="space-y-[7px]">
          {#each images as image (image.id ?? image.repository)}
            <li>
              <Card padding="11px 13px">
                <div class="flex min-w-0 items-center gap-[13px]">
                  <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised) text-(--color-accent-text)">
                    <Icon name="inventory_2" size={18} />
                  </span>
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-[13px] font-semibold">
                      {image.repository}{#if image.tag}:<span class="lk-mono">{image.tag}</span>{/if}
                    </p>
                    <p class="truncate text-[12px] text-(--text-tertiary)">
                      {#if image.id}<span class="lk-mono">{image.id.slice(0, 12)}</span> · {/if}
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
                      {#if image.created_at} · {image.created_at}{/if}
                    </p>
                  </div>
                  {#if !busy}
                    <div class="flex shrink-0 items-center gap-[3px]">
                      <!-- A dangling image has no reference to pull: `docker pull
                           <none>` would be a name that is not one. -->
                      <IconButton icon="download" label={$LL.containerPullImage()} disabled={image.dangling} onclick={() => openPull(image)} />
                      <IconButton icon="delete" label={$LL.containerRemove()} onclick={() => (imageConfirm = image)} />
                    </div>
                  {/if}
                </div>
              </Card>
            </li>
          {/each}
        </ul>
        {#if view.unused_tagged !== null && view.unused_tagged > 0}
          <p class="px-[3px] text-[12px] text-(--text-tertiary)">
            {$LL.containerUnusedImages({ count: view.unused_tagged })}
          </p>
        {/if}
      {/if}

      {#if busy}
        <div class="flex items-center gap-[7px] px-[3px] text-[12px] text-(--text-tertiary)">
          <Spinner size="sm" />
        </div>
      {/if}
    {/if}
  </div>
</SplitView>

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
