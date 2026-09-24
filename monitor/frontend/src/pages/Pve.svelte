<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import {
    CircleStop,
    Play,
    Power,
    RefreshCw,
    RotateCw,
    Settings2,
    type LucideIcon,
  } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import PveSettingsForm, {
    pveSettingsState,
    type PveSettingsState,
  } from '../components/PveSettingsForm.svelte'
  import { api } from '../lib/api'
  import { fmtBytes, fmtPercent, fmtUptime } from '../lib/format'
  import { pveRefusalDetail } from '../lib/pveRefusal'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { PveAction, PveResource, PveResourcesView } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let view = $state<PveResourcesView | null>(null)
  /// Set when the cluster refused the listing with `notConfigured`, which is a
  /// state of this agent rather than a failure: there is nothing to retry until
  /// an address is saved, so the page says so and offers the form instead of an
  /// error with a refresh button.
  let unconfigured = $state(false)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  let notice = $state('')
  let actionError = $state('')
  /// The guest whose detail is open, and the action waiting for a confirmation
  /// inside it. The confirmation replaces the detail rather than opening beside
  /// it — one modal, one thing to answer.
  let opened = $state<PveResource | null>(null)
  let confirming = $state<PveAction | null>(null)
  let settingsOpen = $state(false)
  let settingsState = $state<PveSettingsState | null>(null)
  /// Whether this caller may save. The read is allowed either way, so the
  /// dialog is told apart from a form that would be refused on every save.
  let settingsEditable = $state(false)
  /// Why the dialog's own read failed. Shown inside the dialog rather than on
  /// the page, which is behind it.
  let settingsError = $state('')

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  /// Reads the cluster. `editable` is what this caller may do rather than what
  /// the cluster allows, so a read-only panel still draws the whole listing.
  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getPveResources()
      if (stale(serverId)) return
      unconfigured = false
      view = next
      // The open guest is replaced by the fresh row of the same id, so the
      // dialog shows what the action produced — and closes by itself where the
      // guest is gone.
      if (opened) {
        opened = next.resources.find((resource) => resource.id === opened?.id) ?? null
        if (!opened) confirming = null
      }
    } catch (e) {
      if (stale(serverId)) return
      const code = e instanceof Error ? e.message : String(e)
      if (code === 'notConfigured') {
        unconfigured = true
        view = null
      } else {
        error = pveRefusalDetail(e)
      }
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    // Only the machine on screen re-runs this.
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  /// The dialog's fields come from the agent on every open rather than from a
  /// copy taken at load: what is stored is the agent's own configuration, and a
  /// panel that seeded itself from a page load would save a section it read
  /// before another tab changed it.
  async function openSettings() {
    settingsOpen = true
    settingsState = null
    settingsEditable = false
    settingsError = ''
    try {
      const next = await api.getPveSettings()
      settingsEditable = next.editable
      settingsState = pveSettingsState(next)
    } catch (e) {
      settingsError = pveRefusalDetail(e)
    }
  }

  function closeSettings() {
    settingsOpen = false
    settingsState = null
    settingsError = ''
  }

  async function saveSettings(section: Parameters<typeof api.updatePveSettings>[0]) {
    busy = true
    settingsError = ''
    try {
      const next = await api.updatePveSettings(section)
      settingsEditable = next.editable
      settingsState = pveSettingsState(next)
      settingsOpen = false
      notice = $LL.settingsSaved()
      // The listing depends on what was just stored: an address that changed
      // may point at a different cluster, and one that was cleared leaves
      // nothing to draw.
      await load()
    } catch (e) {
      // The dialog stays open, so the field that caused the refusal is still
      // there to be corrected.
      settingsError = pveRefusalDetail(e)
    } finally {
      busy = false
    }
  }

  /// Asks an action of one guest, and reads the listing again to draw what it
  /// did — the task id PVE answers is not a state, and the guest's own status
  /// is.
  async function act(resource: PveResource, action: PveAction) {
    if (resource.vmid === undefined || (resource.type !== 'qemu' && resource.type !== 'lxc')) {
      return
    }
    const name = label(resource)
    busy = true
    actionError = ''
    try {
      await api.controlPveGuest({
        node: resource.node,
        kind: resource.type,
        vmid: resource.vmid,
        action,
      })
      notice = $LL.pveActionSent({ action: actionLabel(action), name })
      confirming = null
      await load()
    } catch (e) {
      actionError = pveRefusalDetail(e)
    } finally {
      busy = false
    }
  }

  function actionLabel(action: PveAction): string {
    switch (action) {
      case 'start':
        return $LL.pveStart()
      case 'stop':
        return $LL.pveStop()
      case 'shutdown':
        return $LL.powerShutdown()
      case 'reboot':
        return $LL.powerReboot()
    }
  }

  function actionIcon(action: PveAction): LucideIcon {
    switch (action) {
      case 'start':
        return Play
      case 'stop':
        return CircleStop
      case 'shutdown':
        return Power
      case 'reboot':
        return RotateCw
    }
  }

  function label(resource: PveResource): string {
    if (resource.type === 'qemu' || resource.type === 'lxc') {
      // PVE leaves a guest that was never named with an empty name, and the
      // vmid is the other thing an operator knows it by.
      return resource.name || String(resource.vmid ?? resource.id)
    }
    if (resource.type === 'storage') return resource.storage || resource.id
    if (resource.type === 'sdn') return resource.sdn || resource.id
    return resource.node || resource.id
  }

  /// A guest is the only resource anything can be asked of, and only by a
  /// caller the agent grants actions to.
  function actionable(resource: PveResource): boolean {
    return (
      view?.editable === true &&
      resource.vmid !== undefined &&
      (resource.type === 'qemu' || resource.type === 'lxc')
    )
  }

  /// What may be asked of this guest, by its own state. A stopped guest can be
  /// started and nothing else; a running one can be asked to stop three ways.
  function actionsOf(resource: PveResource): PveAction[] {
    if (resource.status === 'running') return ['shutdown', 'stop', 'reboot']
    if (resource.status === 'stopped') return ['start']
    return []
  }

  /// The actions that lose state that was not written anywhere, so they are
  /// asked twice: shutting down is the guest's own OS stopping, which is what
  /// an operator usually means.
  function needsConfirm(action: PveAction): boolean {
    return action === 'stop' || action === 'reboot'
  }

  function confirmText(resource: PveResource, action: PveAction): string {
    return action === 'stop'
      ? $LL.pveStopConfirm({ name: label(resource) })
      : $LL.pveRebootConfirm({ name: label(resource) })
  }

  /// A fraction as a percentage: PVE reports `cpu` as 0.0–1.0, of the node for
  /// a node and of one core for a guest.
  function pct(value: number | undefined): string | null {
    return value === undefined ? null : fmtPercent(value * 100)
  }

  function ratio(used: number | undefined, total: number | undefined): string | null {
    if (used === undefined || total === undefined || total <= 0) return null
    return `${fmtBytes(used)} / ${fmtBytes(total)}`
  }

  const resources = $derived(view?.resources ?? [])
  const groups = $derived([
    {
      id: 'nodes',
      label: $LL.pveNodes(),
      rows: resources.filter((resource) => resource.type === 'node'),
    },
    {
      id: 'guests',
      label: $LL.pveGuests(),
      rows: resources.filter(
        (resource) => resource.type === 'qemu' || resource.type === 'lxc',
      ),
    },
    {
      id: 'storage',
      label: $LL.pveStorage(),
      rows: resources.filter((resource) => resource.type === 'storage'),
    },
    {
      id: 'sdn',
      label: $LL.pveSdn(),
      rows: resources.filter((resource) => resource.type === 'sdn'),
    },
  ])

  function subtitle(): string | undefined {
    if (unconfigured) return undefined
    const count = $LL.pveSubtitle({ count: resources.length })
    return view?.release ? `${view.release} · ${count}` : count
  }
</script>

<PageHeader
  title={$LL.pve()}
  subtitle={view ? subtitle() : undefined}
  containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet tabs()}
    <FeatureTabs active="pve" />
  {/snippet}

  {#snippet actions()}
    <IconButton label={$LL.pveSettings()} onclick={() => void openSettings()}>
      <Settings2 class="w-4 h-4" />
    </IconButton>
    <IconButton
      label={$LL.refresh()}
      onclick={() => void load()}
      disabled={loading || unconfigured}
    >
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
  {#if error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
    </Card>
  {/if}

  {#if actionError}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger whitespace-pre-wrap break-all">{actionError}</p>
    </Card>
  {/if}

  {#if notice}
    <Card>
      <p class="text-sm text-muted-fg">{notice}</p>
    </Card>
  {/if}

  {#if loading && !view && !unconfigured}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if unconfigured}
    <Card>
      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="text-sm text-muted-fg">{$LL.pveNotConfigured()}</p>
        <Button onclick={() => void openSettings()}>{$LL.pveSettings()}</Button>
      </div>
    </Card>
  {:else if view}
    {#if !view.editable}
      <!-- The listing is read either way; what is missing is the grant the
           actions need, which is the same one a save needs. -->
      <Card>
        <p class="text-sm text-muted-fg">{$LL.pveReadOnly()}</p>
      </Card>
    {/if}

    {#if resources.length === 0}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.pveEmpty()}</p>
      </Card>
    {/if}

    {#snippet rowBody(resource: PveResource)}
      <div class="min-w-0 flex-1">
        <div class="flex items-center gap-2">
          <span class="truncate text-sm font-medium text-fg-strong">{label(resource)}</span>
          <Badge tone={resource.status === 'running' || resource.status === 'online'
            ? 'success'
            : 'neutral'}>
            {resource.status}
          </Badge>
        </div>
        <div class="truncate text-xs text-muted-fg">
          {#if resource.type === 'qemu' || resource.type === 'lxc'}
            {resource.type.toUpperCase()} {resource.vmid} · {resource.node}
          {:else if resource.type === 'storage'}
            {resource.plugintype ?? ''} · {resource.node}{resource.content
              ? ` · ${resource.content}`
              : ''}
          {:else if resource.type === 'sdn'}
            {resource.node}
          {:else}
            {resource.node}
          {/if}
        </div>
      </div>
      <div class="flex shrink-0 items-center gap-3 text-xs text-muted-fg">
        {#if resource.cpu !== undefined}
          <span class="hidden w-16 text-right sm:inline">
            {$LL.pveCpu()} {pct(resource.cpu)}
          </span>
        {/if}
        {#if ratio(resource.mem, resource.maxmem)}
          <span class="hidden w-36 text-right sm:inline">{ratio(resource.mem, resource.maxmem)}</span>
        {/if}
        {#if ratio(resource.disk, resource.maxdisk)}
          <span class="hidden w-36 text-right md:inline">
            {ratio(resource.disk, resource.maxdisk)}
          </span>
        {/if}
        {#if resource.uptime !== undefined}
          <span class="w-10 text-right">{fmtUptime(resource.uptime)}</span>
        {/if}
      </div>
    {/snippet}

    {#each groups as group (group.id)}
      {#if group.rows.length > 0}
        <Card class="p-0">
          <div class="flex items-center gap-2 border-b border-line px-4 py-2">
            <h2 class="text-sm font-medium text-fg-strong">{group.label}</h2>
            <span class="text-xs text-muted-fg">{group.rows.length}</span>
          </div>
          <div class="divide-y divide-line">
            {#each group.rows as resource (resource.id)}
              {#if actionable(resource)}
                <button
                  class="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-soft/40"
                  onclick={() => {
                    opened = resource
                    confirming = null
                    actionError = ''
                  }}
                >
                  {@render rowBody(resource)}
                </button>
              {:else}
                <div class="flex w-full items-center gap-3 px-4 py-3">
                  {@render rowBody(resource)}
                </div>
              {/if}
            {/each}
          </div>
        </Card>
      {/if}
    {/each}
  {/if}
</main>

{#if opened}
  <Modal open title={label(opened)} onclose={() => (opened = null)}>
    <div class="space-y-4">
      {#if confirming}
        <p class="whitespace-pre-wrap text-sm text-fg">{confirmText(opened, confirming)}</p>
        <div class="flex justify-end gap-2">
          <Button variant="secondary" onclick={() => (confirming = null)} disabled={busy}>
            {$LL.cancel()}
          </Button>
          <Button onclick={() => void act(opened!, confirming!)} disabled={busy}>
            {actionLabel(confirming)}
          </Button>
        </div>
      {:else}
        <div class="flex flex-wrap items-center gap-2 text-sm text-muted-fg">
          <Badge tone={opened.status === 'running' ? 'success' : 'neutral'}>{opened.status}</Badge>
          <span>{opened.type.toUpperCase()} {opened.vmid}</span>
          <span>{opened.node}</span>
        </div>

        <dl class="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
          <div>
            <dt class="text-xs text-muted-fg">{$LL.pveCpu()}</dt>
            <dd class="text-fg">{pct(opened.cpu) ?? '—'}</dd>
          </div>
          <div>
            <dt class="text-xs text-muted-fg">{$LL.pveMemory()}</dt>
            <dd class="text-fg">{ratio(opened.mem, opened.maxmem) ?? '—'}</dd>
          </div>
          <div>
            <dt class="text-xs text-muted-fg">{$LL.pveDisk()}</dt>
            <dd class="text-fg">{ratio(opened.disk, opened.maxdisk) ?? '—'}</dd>
          </div>
          <div>
            <dt class="text-xs text-muted-fg">{$LL.pveUptime()}</dt>
            <dd class="text-fg">
              {opened.uptime === undefined ? '—' : fmtUptime(opened.uptime)}
            </dd>
          </div>
        </dl>

        {#if actionsOf(opened).length > 0}
          <div class="flex flex-wrap justify-end gap-2">
            {#each actionsOf(opened) as action (action)}
              {@const Icon = actionIcon(action)}
              <Button
                variant={action === 'start' ? 'primary' : 'secondary'}
                onclick={() => (needsConfirm(action) ? (confirming = action) : void act(opened!, action))}
                disabled={busy}
              >
                <Icon class="w-4 h-4" />
                {actionLabel(action)}
              </Button>
            {/each}
          </div>
        {:else}
          <p class="text-sm text-muted-fg">{$LL.pveNoAction()}</p>
        {/if}
      {/if}
    </div>
  </Modal>
{/if}

{#if settingsOpen}
  <Modal open title={$LL.pveSettings()} onclose={closeSettings}>
    {#if settingsState && !settingsEditable}
      <div class="space-y-4">
        <p class="text-sm text-muted-fg">{$LL.pveReadOnly()}</p>
        <div class="flex justify-end">
          <Button variant="secondary" onclick={closeSettings}>{$LL.cancel()}</Button>
        </div>
      </div>
    {:else if settingsState}
      <div class="space-y-4">
        <p class="text-sm text-muted-fg">{$LL.pveSettingsNote()}</p>
        {#if settingsError}
          <p class="whitespace-pre-wrap text-sm text-danger">{settingsError}</p>
        {/if}
        <PveSettingsForm
          fields={settingsState}
          onsaved={(section) => void saveSettings(section)}
          oncancel={closeSettings}
        />
      </div>
    {:else if settingsError}
      <div class="space-y-4">
        <p class="whitespace-pre-wrap text-sm text-danger">{settingsError}</p>
        <div class="flex justify-end">
          <Button variant="secondary" onclick={closeSettings}>{$LL.cancel()}</Button>
        </div>
      </div>
    {:else}
      <Spinner class="w-5 h-5" />
    {/if}
  </Modal>
{/if}
