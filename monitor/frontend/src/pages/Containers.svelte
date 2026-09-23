<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import {
    CircleAlert,
    Eraser,
    Play,
    RefreshCw,
    RotateCw,
    ScrollText,
    Square,
    Trash2,
    type Icon as LucideIcon,
  } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { api } from '../lib/api'
  import { fmtBytes } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'
  import type { ContainerAction, ContainerActionKind, ContainerRow, ContainerView } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  /// Two lists, one screen. `usage` is not a third: `system df` walks the whole
  /// image store, so it is a line under the header rather than a tab someone
  /// keeps open.
  type Tab = 'containers' | 'images'
  const TABS: Tab[] = ['containers', 'images']

  /// How much of a container's log a read asks for. Mirrors
  /// `sbm_parser::container::LOG_TAIL`, which is the agent's bound — this is
  /// only what the sentence above the output says.
  const LOG_TAIL = 100

  let tab = $state<Tab>('containers')

  let view = $state<ContainerView | null>(null)
  let usage = $state<ContainerView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  /// The container whose removal is being confirmed, or `undefined` for none.
  /// Removal is the only action asked about: it is the only one that loses
  /// something, and `force` changes what it does to a running container.
  let confirming = $state<ContainerRow | undefined>(undefined)
  let force = $state(false)
  let logsFor = $state<ContainerRow | undefined>(undefined)
  let logs = $state('')
  let logsError = $state('')

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
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

  /// Every change answers with the listing as it now stands, so one request
  /// both writes and refreshes.
  async function act(action: ContainerAction) {
    busy = true
    error = ''
    try {
      view = await api.actContainer(action)
      void loadUsage()
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
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

  const editable = $derived(view?.editable === true)
  const rows = $derived(view?.containers ?? [])
  const images = $derived(view?.images ?? [])

  /// Images no container uses and that would be reclaimed by a prune. A count
  /// this agent could not confirm is *not* counted: `containers === null` means
  /// unknown, and treating it as zero is how an image still in use gets
  /// removed.
  const unusedImages = $derived(
    images.filter((image) => image.containers === 0 || image.repository === '<none>').length,
  )

  /// How each action is drawn. A `Record` over every kind, so a kind added to
  /// the model without a button here is a type error rather than a container
  /// whose menu is silently short.
  ///
  /// `terminal` is deliberately `null` — the panel's terminal is an SSH shell
  /// with no way to be handed a command to start with, so a shell *inside* a
  /// container cannot be opened from here. TODO: give the terminal an initial
  /// command and the app's `docker exec -it` comes with it.
  const BUTTONS: Record<
    ContainerActionKind,
    { label: () => string; icon: typeof LucideIcon } | null
  > = {
    start: { label: () => $LL.containerStart(), icon: Play },
    stop: { label: () => $LL.containerStop(), icon: Square },
    restart: { label: () => $LL.containerRestart(), icon: RotateCw },
    remove: { label: () => $LL.containerRemove(), icon: Trash2 },
    logs: { label: () => $LL.containerLogs(), icon: ScrollText },
    terminal: null,
  }

  /// The lifecycle buttons for one row: the model's own list, minus the two
  /// that are not a change. A log is a view and is offered as a link below the
  /// row; a terminal is not drawn at all.
  function lifecycle(row: ContainerRow): ContainerActionKind[] {
    return row.actions.filter((kind) => kind !== 'logs' && kind !== 'terminal')
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

<PageHeader
  title={$LL.containers()}
  subtitle={view?.runtime
    ? $LL.containerRuntime({
        runtime: view.runtime.kind,
        version: view.runtime.version ?? $LL.containerUnknown(),
      })
    : undefined}
  containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet tabs()}
    <FeatureTabs active="containers" />
  {/snippet}

  {#snippet actions()}
    {#if editable && view?.available}
      <IconButton
        label={$LL.containerPruneContainers()}
        disabled={busy}
        onclick={() => void act({ action: 'prune_containers' })}
      >
        <Eraser class="w-4 h-4" />
      </IconButton>
      <IconButton
        label={$LL.containerPruneVolumes()}
        disabled={busy}
        onclick={() => void act({ action: 'prune_volumes' })}
      >
        <Eraser class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} onclick={() => void refresh()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
  {#if error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}

  {#if loading && !view}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if view && !view.available}
    <Card class="space-y-2">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
      {#if view.reason}
        <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.reason}</pre>
      {/if}
    </Card>
  {:else if view}
    {#if !editable}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.containerReadOnly()}</p>
      </Card>
    {/if}

    {#if usage?.usage}
      <Card>
        <p class="text-sm text-muted-fg">
          {$LL.containerUsage({
            images: usage.usage.image_count ?? 0,
            reclaimable: fmtBytes(usage.usage.reclaimable_bytes ?? 0),
          })}
        </p>
      </Card>
    {/if}

    <div class="flex gap-1 border-b border-border">
      {#each TABS as name (name)}
        <button
          class="border-b-2 px-3 py-1.5 text-sm transition-colors {tab === name
            ? 'border-primary text-fg-strong'
            : 'border-transparent text-muted-fg hover:text-fg'}"
          aria-current={tab === name ? 'page' : undefined}
          onclick={() => (tab = name)}
        >
          {name === 'containers' ? $LL.containers() : $LL.containerImages()}
        </button>
      {/each}
    </div>

    {#if tab === 'containers'}
      {#if rows.length === 0}
        <Card>
          <p class="text-sm text-muted-fg">{$LL.containerEmpty()}</p>
        </Card>
      {:else}
        <Card class="divide-y divide-border p-0">
          {#each rows as row (row.id ?? row.name)}
            <div class="px-4 py-3 space-y-1">
              <div class="flex items-center gap-3">
                <span class="text-sm font-medium text-fg-strong truncate">
                  {row.name ?? row.id ?? $LL.containerUnknown()}
                </span>
                <Badge tone={statusTone(row)}>{statusText(row)}</Badge>
                {#if row.project}
                  <Badge tone="neutral">{row.project}</Badge>
                {/if}
                <span class="flex-1"></span>
                {#if editable && !busy}
                  <div class="flex shrink-0">
                    {#each lifecycle(row) as kind (kind)}
                      {@const button = BUTTONS[kind]}
                      {#if button}
                        {@const ActionIcon = button.icon}
                        <IconButton label={button.label()} onclick={() => click(kind, row)}>
                          <ActionIcon class="w-4 h-4" />
                        </IconButton>
                      {/if}
                    {/each}
                  </div>
                {/if}
              </div>
              <p class="text-xs text-muted-fg truncate">
                {row.image ?? $LL.containerUnknown()}
                {#if row.ports}
                  · <span class="font-mono">{row.ports}</span>
                {/if}
                {#if row.raw_status}
                  · {row.raw_status}
                {/if}
              </p>
              {#if row.stats}
                <p class="text-xs text-faint-fg">
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
                <button class="text-xs text-primary hover:underline" onclick={() => void openLogs(row)}>
                  {$LL.containerLogs()}
                </button>
              {/if}
            </div>
          {/each}
        </Card>
      {/if}
    {:else if images.length === 0}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.containerNoImages()}</p>
      </Card>
    {:else}
      <Card class="divide-y divide-border p-0">
        {#each images as image (image.id ?? image.repository)}
          <div class="px-4 py-3 space-y-1">
            <p class="text-sm text-fg-strong truncate">
              {image.repository}{#if image.tag}:<span class="font-mono">{image.tag}</span>{/if}
            </p>
            <p class="text-xs text-muted-fg truncate">
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
        {/each}
      </Card>
      {#if unusedImages > 0}
        <p class="text-xs text-muted-fg">{$LL.containerUnusedImages({ count: unusedImages })}</p>
      {/if}
    {/if}

    {#if busy}
      <div class="flex items-center gap-2 text-xs text-muted-fg">
        <Spinner size="sm" />
      </div>
    {/if}
  {/if}
</main>

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
      <div class="flex justify-end gap-2">
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
          class="max-h-96 overflow-auto rounded border border-border bg-surface p-3 text-xs font-mono text-fg whitespace-pre-wrap break-all">{logs}</pre>
      {:else}
        <p class="text-sm text-muted-fg">{$LL.containerLogsEmpty()}</p>
      {/if}
      <div class="flex justify-end">
        <Button variant="secondary" onclick={() => (logsFor = undefined)}>{$LL.close()}</Button>
      </div>
    </div>
  </Modal>
{/if}
