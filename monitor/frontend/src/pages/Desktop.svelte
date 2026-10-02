<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import { MonitorPlay, Pencil, Plus, RefreshCw, Trash2, Unplug } from '@lucide/svelte'
  import DesktopForm, { desktopFormState, type DesktopFormState } from '../components/DesktopForm.svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import RdpViewer from '../components/RdpViewer.svelte'
  import VncViewer from '../components/VncViewer.svelte'
  import { api } from '../lib/api'
  import { DesktopSession, rdpEndpoint, type RdpEndpoint, type RelayChannel } from '../lib/desktop.svelte'
  import { desktopRefusalText } from '../lib/desktopRefusal'
  import { servers } from '../lib/servers.svelte'
  import { onDestroy, untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { Desktop, DesktopsView } from '../types'

  /// The desktop routes saved on the agent, and the session opened on one: VNC
  /// is noVNC over the `/stream/ws` relay, RDP is IronRDP through the agent's
  /// `/rdp/ws` proxy. The password is asked for when a session opens and kept
  /// nowhere.
  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let view = $state<DesktopsView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  let notice = $state('')
  /// A refused write, or why a session ended — the agent's or the desktop's
  /// own words where there are any.
  let actionError = $state('')
  let opened = $state<Desktop | null>(null)
  let editing = $state<Desktop | null | undefined>(undefined)
  let formState = $state<DesktopFormState>(desktopFormState())
  let removing = $state(false)
  /// The route waiting for its password, and what is typed there.
  let pending = $state<Desktop | null>(null)
  let password = $state('')
  /// The live session: what its client is handed (a relay channel for VNC,
  /// an endpoint for RDP), the route, and the password given to the client
  /// once.
  let live = $state<{ kind: 'vnc'; channel: RelayChannel } | { kind: 'rdp'; endpoint: RdpEndpoint } | null>(
    null,
  )
  let sessionDesktop = $state<Desktop | null>(null)
  let sessionPassword = $state('')
  /// The route of a session that ended on its own, for one-click retry.
  let retry = $state<Desktop | null>(null)

  const session = new DesktopSession()
  onDestroy(() => session.close())

  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getDesktops()
      if (stale(serverId)) return
      view = next
      if (opened) {
        opened = next.desktops.find((d) => d.id === opened?.id) ?? null
        if (!opened) removing = false
      }
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  /// A write replaces the whole set: the order is part of what is stored.
  async function save(desktops: Desktop[], done: string) {
    busy = true
    notice = ''
    actionError = ''
    try {
      view = await api.updateDesktops(desktops)
      notice = done
      return true
    } catch (e) {
      actionError = desktopRefusalText(e)
      return false
    } finally {
      busy = false
    }
  }

  async function submit(desktop: Desktop, original: Desktop | null) {
    const desktops = view?.desktops ?? []
    const next = original
      ? desktops.map((d) => (d.id === original.id ? desktop : d))
      : [...desktops, desktop]
    if (await save(next, $LL.desktopDoneSaved({ name: desktop.name }))) editing = undefined
  }

  async function remove() {
    const desktop = opened
    if (!desktop) return
    const next = (view?.desktops ?? []).filter((d) => d.id !== desktop.id)
    if (await save(next, $LL.desktopDoneDeleted({ name: desktop.name }))) {
      opened = null
      removing = false
    }
  }

  function open(desktop: Desktop) {
    opened = desktop
    removing = false
    actionError = ''
  }

  function openForm(desktop: Desktop | null) {
    formState = desktopFormState(desktop ?? undefined, view?.protocols ?? [])
    editing = desktop
    actionError = ''
  }

  /// Opens the relay, then hands it to the viewer. An empty password is a real
  /// answer: a desktop that wants one says so, and the session ends with that.
  async function connect(desktop: Desktop) {
    const serverId = servers.currentId
    pending = null
    busy = true
    actionError = ''
    retry = null
    if (desktop.protocol === 'rdp') {
      busy = false
      const endpoint = rdpEndpoint()
      if (!endpoint) {
        actionError = $LL.desktopDropped()
        password = ''
        return
      }
      opened = null
      live = { kind: 'rdp', endpoint }
      sessionDesktop = desktop
      sessionPassword = password
      password = ''
      return
    }
    const answered = await session.connect(desktop)
    busy = false
    if (stale(serverId)) {
      session.close()
      password = ''
      return
    }
    if (!answered) {
      actionError = session.error ?? $LL.desktopDropped()
      retry = desktop
      password = ''
      return
    }
    opened = null
    live = { kind: 'vnc', channel: answered }
    sessionDesktop = desktop
    sessionPassword = password
    password = ''
  }

  /// Ends the session. `message` is why, when it ended on its own; the route
  /// is then kept for a retry.
  function endSession(message: string | null) {
    retry = message ? sessionDesktop : null
    live = null
    sessionDesktop = null
    sessionPassword = ''
    session.close()
    actionError = message ?? ''
  }

  const desktops = $derived(view?.desktops ?? [])

  /// Why a route cannot be opened, or `null`: an RDP session signs in, so it
  /// needs a user name.
  function blockOf(desktop: Desktop): string | null {
    return desktop.protocol === 'rdp' && !desktop.username ? $LL.desktopRdpUsername() : null
  }
</script>

{#if live && sessionDesktop}
  <!-- The session takes the page: leaving it by the back chevron closes it,
       since a relay left open is a connection nobody is looking at. -->
  <PageHeader
    title={sessionDesktop.name}
    containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
    onback={() => endSession(null)}
  >
    {#snippet actions()}
      <IconButton label={$LL.desktopDisconnect()} onclick={() => endSession(null)}>
        <Unplug class="w-4 h-4" />
      </IconButton>
    {/snippet}
  </PageHeader>

  <main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
    {#key live}
      {#if live.kind === 'vnc'}
        <VncViewer
          channel={live.channel}
          username={sessionDesktop.username}
          password={sessionPassword}
          viewOnly={sessionDesktop.view_only}
          shared={sessionDesktop.shared}
          onend={endSession}
        />
      {:else}
        <RdpViewer
          endpoint={live.endpoint}
          target={sessionDesktop}
          password={sessionPassword}
          onend={endSession}
        />
      {/if}
    {/key}
  </main>
{:else}
  <PageHeader
    title={$LL.desktop()}
    subtitle={view ? $LL.desktopSubtitle({ count: desktops.length }) : undefined}
    containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
    {onback}
  >
    {#snippet tabs()}
      <FeatureTabs active="desktop" />
    {/snippet}

    {#snippet actions()}
      <IconButton label={$LL.desktopAdd()} onclick={() => openForm(null)}>
        <Plus class="w-4 h-4" />
      </IconButton>
      <IconButton label={$LL.refresh()} onclick={() => void load()} disabled={loading}>
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

    {#if actionError}
      <Card class="border-danger/40 bg-danger/5">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <p class="text-sm text-danger whitespace-pre-wrap break-all">{actionError}</p>
          {#if retry}
            <Button variant="secondary" onclick={() => (pending = retry)}>
              {$LL.desktopReconnect()}
            </Button>
          {/if}
        </div>
      </Card>
    {/if}

    {#if notice}
      <Card>
        <p class="text-sm text-muted-fg">{notice}</p>
      </Card>
    {/if}

    {#if loading && !view}
      <Card><Spinner class="w-5 h-5" /></Card>
    {:else if view}
      {#if desktops.length === 0}
        <Card>
          <p class="text-sm text-muted-fg">{$LL.desktopEmpty()}</p>
        </Card>
      {:else}
        <Card class="divide-y divide-line p-0">
          {#each desktops as desktop (desktop.id)}
            <button
              class="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-soft/40"
              onclick={() => open(desktop)}
            >
              <span class="min-w-0 flex-1">
                <span class="flex flex-wrap items-baseline gap-2">
                  <span class="truncate text-sm font-medium text-fg-strong">{desktop.name}</span>
                  <Badge tone="neutral">{desktop.protocol.toUpperCase()}</Badge>
                  {#if desktop.view_only}
                    <Badge tone="warning">{$LL.desktopViewOnly()}</Badge>
                  {/if}
                </span>
                <span class="block truncate text-xs text-muted-fg">
                  {desktop.host}:{desktop.port}{#if desktop.username}&nbsp;· {desktop.username}{/if}
                </span>
              </span>
            </button>
          {/each}
        </Card>
      {/if}

      <p class="text-xs text-muted-fg">{$LL.desktopRouteNote()}</p>

      {#if busy}
        <div class="flex items-center gap-2 text-xs text-muted-fg">
          <Spinner size="sm" />
        </div>
      {/if}
    {/if}
  </main>
{/if}

{#if opened && editing === undefined && !live}
  <Modal open title={opened.name} onclose={() => (opened = null)}>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center gap-2">
        <Badge tone="neutral">{opened.protocol.toUpperCase()}</Badge>
        {#if opened.view_only}
          <Badge tone="warning">{$LL.desktopViewOnly()}</Badge>
        {/if}
      </div>
      <dl class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
        <div>
          <dt class="text-faint-fg">{$LL.desktopHost()}</dt>
          <dd class="text-muted-fg break-all">{opened.host}:{opened.port}</dd>
        </div>
        <div>
          <dt class="text-faint-fg">{$LL.desktopUsername()}</dt>
          <dd class="text-muted-fg">{opened.username ?? '—'}</dd>
        </div>
        {#if opened.domain}
          <div>
            <dt class="text-faint-fg">{$LL.desktopDomain()}</dt>
            <dd class="text-muted-fg">{opened.domain}</dd>
          </div>
        {/if}
      </dl>

      {#if removing}
        <Card class="space-y-2">
          <p class="text-sm text-fg">{$LL.desktopDeleteConfirm({ name: opened.name })}</p>
          <div class="flex justify-end gap-2">
            <Button variant="secondary" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
            <Button disabled={busy} onclick={() => void remove()}>{$LL.desktopDelete()}</Button>
          </div>
        </Card>
      {:else}
        <div class="flex flex-wrap items-center gap-2">
          <Button
            disabled={busy || blockOf(opened) !== null}
            onclick={() => {
              pending = opened
              opened = null
            }}
          >
            <MonitorPlay class="w-4 h-4" />
            {$LL.desktopConnect()}
          </Button>
          <Button variant="secondary" onclick={() => openForm(opened)}>
            <Pencil class="w-4 h-4" />
            {$LL.desktopEdit()}
          </Button>
          <Button variant="secondary" onclick={() => (removing = true)}>
            <Trash2 class="w-4 h-4" />
            {$LL.desktopDelete()}
          </Button>
        </div>
        {#if blockOf(opened)}
          <p class="text-xs text-muted-fg">{blockOf(opened)}</p>
        {/if}
      {/if}
    </div>
  </Modal>
{/if}

<!-- The password exists only in this dialog and in the viewer it is handed to. -->
{#if pending}
  {@const target = pending}
  <Modal open title={$LL.desktopConnect()} onclose={() => (pending = null)}>
    <form
      class="space-y-4"
      onsubmit={(e) => {
        e.preventDefault()
        void connect(target)
      }}
    >
      <p class="text-sm text-muted-fg">{target.name} · {target.host}:{target.port}</p>
      <div class="space-y-1">
        <label class="text-sm text-muted-fg" for="desktop-password">{$LL.desktopPassword()}</label>
        <Input id="desktop-password" type="password" autocomplete="off" bind:value={password} />
        <p class="text-xs text-muted-fg">{$LL.desktopPasswordNone()}</p>
      </div>
      <div class="flex justify-end gap-2">
        <Button type="button" variant="secondary" onclick={() => (pending = null)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy}>{$LL.desktopConnect()}</Button>
      </div>
    </form>
  </Modal>
{/if}

{#if editing !== undefined}
  <Modal open title={editing ? $LL.desktopEdit() : $LL.desktopAdd()} onclose={() => (editing = undefined)}>
    <DesktopForm
      desktop={editing ?? undefined}
      protocols={view?.protocols ?? []}
      fields={formState}
      onsaved={(desktop) => void submit(desktop, editing ?? null)}
      oncancel={() => (editing = undefined)}
    />
  </Modal>
{/if}
