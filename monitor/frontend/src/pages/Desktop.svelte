<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import { MonitorPlay, Pencil, Plus, RefreshCw, Trash2 } from '@lucide/svelte'
  import DesktopForm, {
    desktopFormState,
    type DesktopFormState,
  } from '../components/DesktopForm.svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import RdpViewer from '../components/RdpViewer.svelte'
  import VncViewer from '../components/VncViewer.svelte'
  import { api } from '../lib/api'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { DesktopSession, type DesktopChannel } from '../lib/desktop.svelte'
  import { desktopRefusalText } from '../lib/desktopRefusal'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { DesktopRoutesView, DesktopTarget } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let view = $state<DesktopRoutesView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  /// Set after a write lands and cleared by the next one. Worth saying because
  /// the set it names has been replaced under the list still on screen.
  let notice = $state('')
  /// What went wrong with a write, or why a session ended, the agent's own
  /// words where it sent any — they are the only thing that distinguishes one
  /// failure from another.
  let actionError = $state('')
  /// The route whose detail is open, the route the form is about (`undefined`
  /// for a new one), and the route waiting for a `sudo`-free password prompt.
  let opened = $state<DesktopTarget | null>(null)
  let editing = $state<DesktopTarget | null | undefined>(undefined)
  let formState = $state<DesktopFormState>(desktopFormState())
  let removing = $state(false)
  /// The route a session is being opened on, the password typed for it, and the
  /// channel once the agent has answered for it — a socket for VNC, an address
  /// for RDP.
  let pending = $state<DesktopTarget | null>(null)
  let password = $state('')
  let channel = $state<DesktopChannel | null>(null)
  /// The route the live session is on, and the password typed for it. Both
  /// exist only while a session does: the route because the viewer needs what
  /// it was opened with, the password because noVNC is handed it once at
  /// attach and there is nowhere else it could be kept.
  let sessionRoute = $state<DesktopTarget | null>(null)
  let sessionPassword = $state('')

  /// One session at a time: a second desktop on screen would be a second
  /// connection to a machine the operator is already looking at, and the page
  /// has one place to draw it.
  const session = new DesktopSession()

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getDesktopRoutes()
      if (stale(serverId)) return
      view = next
      // The open route is replaced by the fresh one of the same name, so the
      // dialog shows what the write just produced — and closes by itself where
      // the route is gone.
      if (opened) {
        opened = next.targets.find((target) => target.name === opened?.name) ?? null
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
    // Only the machine on screen re-runs this.
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  /// A write replaces the whole set, because that is what the endpoint takes:
  /// the order is part of what is stored, so there is no smaller expression for
  /// a move, and an add, a change and a removal are the same request with a
  /// different list.
  async function save(targets: DesktopTarget[], done: string) {
    busy = true
    notice = ''
    actionError = ''
    try {
      view = await api.updateDesktopRoutes(targets)
      notice = done
      return true
    } catch (e) {
      // A refusal made before the file was written, as its own code.
      actionError = desktopRefusalText(e instanceof Error ? e.message : String(e))
      return false
    } finally {
      busy = false
    }
  }

  async function submit(route: DesktopTarget, original: DesktopTarget | null) {
    const targets = view?.targets ?? []
    // Matched by name, which is a route's identity: matching by position would
    // replace whichever route a rename had pushed out of the way.
    const next = original
      ? targets.map((target) => (target.name === original.name ? route : target))
      : [...targets, route]
    // The dialog stays open on a refusal so the field that caused it is still
    // there to be corrected.
    if (await save(next, $LL.desktopDoneSaved({ name: route.name }))) editing = undefined
  }

  async function remove() {
    const route = opened
    if (!route) return
    const next = (view?.targets ?? []).filter((target) => target.name !== route.name)
    if (await save(next, $LL.desktopDoneDeleted({ name: route.name }))) {
      opened = null
      removing = false
    }
  }

  function open(target: DesktopTarget) {
    opened = target
    removing = false
    actionError = ''
  }

  function openForm(target: DesktopTarget | null) {
    formState = desktopFormState(target ?? undefined, view?.protocols ?? [])
    editing = target
    actionError = ''
  }

  /// Opens the session on a route. The password is asked for here rather than
  /// stored, and an empty answer is a real one: a desktop that wants none is
  /// entitled to get none, and one that wants a password says so itself.
  async function connect(route: DesktopTarget) {
    pending = null
    busy = true
    actionError = ''
    const answered = await session.connect(route)
    busy = false
    if (!answered) {
      // The store holds what the agent said, which is the only thing that
      // distinguishes "the relay is off" from "the desktop refused". Only a VNC
      // session can fail here: it is the one whose socket this store opens, and
      // an RDP session dials itself, so everything it can fail on — the ticket
      // included — is reported by its viewer instead.
      actionError = session.error ?? $LL.desktopUnreachable()
      password = ''
      return
    }
    opened = null
    channel = answered
    sessionRoute = route
    sessionPassword = password
    password = ''
  }

  /// Ends the session, and says why if it was not the operator's own doing.
  ///
  /// The route is kept when it ended on its own, so the same one can be tried
  /// again: a desktop that dropped a connection is usually worth a second
  /// attempt, and re-picking it from the list is a step that decides nothing.
  /// Ending it deliberately clears it, because there is nothing left to retry.
  function endSession(message: string | null, leave = false) {
    channel = null
    sessionPassword = ''
    session.close()
    if (leave) {
      sessionRoute = null
      onback()
      return
    }
    actionError = message ?? ''
    if (!message) sessionRoute = null
  }

  const routes = $derived(view?.targets ?? [])
  /// What this agent will open a session on. `remote_access.desktop` says it
  /// serves a route list, which is a different question from whether it will
  /// relay a connection — the route list is editable either way. Two flags
  /// rather than one because the two endpoints are separate: the relay carries
  /// VNC and understands nothing, while the RDP endpoint terminates the session
  /// with the desktop itself, and an agent may serve one and not the other.
  const caps = $derived(capabilitiesStore.byServer[servers.currentId]?.remote_access)
  /// Whether either is open, which is what the page's own note is about. A
  /// single route is a narrower question and is answered beside its button.
  const canRelay = $derived(caps?.stream === true || caps?.rdp === true)

  /// Why this route cannot be opened from here, or `null` when it can. A
  /// protocol the agent does not serve is the agent's answer; a missing user
  /// name is the route's own, since an RDP session signs in and this panel has
  /// nothing to sign in with.
  function blockOf(route: DesktopTarget): string | null {
    if (route.protocol === 'rdp') {
      if (caps?.rdp !== true) return $LL.desktopNoRelayProtocol({ protocol: 'RDP' })
      if (!route.username) return $LL.desktopRdpUsername()
      return null
    }
    if (caps?.stream !== true) return $LL.desktopNoRelayProtocol({ protocol: 'VNC' })
    return null
  }

  function subtitle(): string | undefined {
    return $LL.desktopSubtitle({ count: routes.length })
  }
</script>

{#if channel && sessionRoute}
  <!-- The session owns the screen while it is up: a desktop drawn beside a list
       of routes is a desktop drawn in the space left over. Leaving by the back
       chevron closes it the same way the button does — a socket left open is a
       connection to the desktop nobody is looking at. -->
  <PageHeader
    title={session.phase === 'connected' ? $LL.desktop() : $LL.desktopConnecting()}
    containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
    onback={() => endSession(null, true)}
  >
    {#snippet actions()}
      <IconButton label={$LL.desktopDisconnect()} onclick={() => endSession(null)}>
        <Trash2 class="w-4 h-4" />
      </IconButton>
    {/snippet}
  </PageHeader>

  <main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
    {#if actionError}
      <Card class="border-danger/40 bg-danger/5">
        <p class="text-sm text-danger">{actionError}</p>
      </Card>
    {/if}
    <!-- One client or the other, never both: which the agent answered with is
         the protocol the route speaks. The two are not interchangeable in
         shape either — the VNC client is handed a socket this page already
         accepted, and the RDP client is handed an address to dial. -->
    {#if channel.protocol === 'vnc'}
      <VncViewer
        socket={channel.socket}
        password={sessionPassword}
        viewOnly={sessionRoute.view_only}
        shared={sessionRoute.shared}
        onend={endSession}
      />
    {:else}
      <RdpViewer
        endpoint={channel.endpoint}
        target={sessionRoute}
        password={sessionPassword}
        onconnect={() => session.markConnected()}
        onend={endSession}
      />
    {/if}
  </main>
{:else}
  <PageHeader
    title={$LL.desktop()}
    subtitle={view ? subtitle() : undefined}
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
          <!-- Only when a session that had been open ended by itself: the route
               is still known, so trying it again is one click. -->
          {#if sessionRoute}
            <Button variant="secondary" onclick={() => (pending = sessionRoute)}>
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
      {#if !canRelay}
        <!-- The routes are this agent's and are editable without the relay; what
             is missing is the connection, which is a wider grant. -->
        <Card>
          <p class="text-sm text-muted-fg">{$LL.desktopNoRelay()}</p>
        </Card>
      {/if}

      {#if routes.length === 0}
        <Card>
          <p class="text-sm text-muted-fg">{$LL.desktopEmpty()}</p>
        </Card>
      {:else}
        <Card class="divide-y divide-border p-0">
          {#each routes as route (route.name)}
            <button
              class="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-soft/40"
              onclick={() => open(route)}
            >
              <span class="min-w-0 flex-1">
                <span class="flex flex-wrap items-baseline gap-2">
                  <span class="truncate text-sm font-medium text-fg-strong">{route.name}</span>
                  <Badge tone="neutral">{route.protocol.toUpperCase()}</Badge>
                  {#if route.view_only}
                    <Badge tone="warning">{$LL.desktopViewOnly()}</Badge>
                  {/if}
                </span>
                <span class="block truncate text-xs text-muted-fg">
                  {route.host}:{route.port}
                  {#if route.username} · {route.username}{/if}
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

<!-- One route: what the agent has saved, and the three things that may be done
     with it. Its own dialog rather than buttons on the row, so a write is always
     taken with the route on screen. -->
{#if opened && editing === undefined && !channel}
  <Modal open title={opened.name} onclose={() => (opened = null)}>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center gap-2">
        <Badge tone="neutral">{opened.protocol.toUpperCase()}</Badge>
        {#if opened.view_only}
          <Badge tone="warning">{$LL.desktopViewOnly()}</Badge>
        {/if}
      </div>

      <dl class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs sm:grid-cols-3">
        <div class="col-span-2">
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
          <!-- Disabled where the agent will not carry this protocol or the
               route cannot sign in, with the reason drawn under the buttons:
               a control that opens nothing and says nothing is worse than one
               that says why. -->
          <Button disabled={blockOf(opened) !== null || busy} onclick={() => (pending = opened!)}>
            <MonitorPlay class="w-4 h-4" />
            {$LL.desktopConnect()}
          </Button>
          <Button variant="secondary" onclick={() => openForm(opened!)}>
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

<!-- The password is asked for when a session is opened and kept nowhere: the
     agent stores no credential for a route, and this dialog is the only place
     one exists. -->
{#if pending}
  <Modal open title={$LL.desktopConnect()} onclose={() => (pending = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{pending.name} · {pending.host}:{pending.port}</p>
      <div class="space-y-1">
        <label class="text-sm text-muted-fg" for="desktop-password">{$LL.desktopPassword()}</label>
        <Input id="desktop-password" type="password" bind:value={password} />
        <p class="text-xs text-muted-fg">{$LL.desktopPasswordNone()}</p>
      </div>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (pending = null)}>{$LL.cancel()}</Button>
        <Button disabled={busy} onclick={() => void connect(pending!)}>{$LL.desktopConnect()}</Button>
      </div>
    </div>
  </Modal>
{/if}

{#if editing !== undefined}
  <Modal
    open
    title={editing ? $LL.desktopEdit() : $LL.desktopAdd()}
    onclose={() => (editing = undefined)}
  >
    <DesktopForm
      target={editing ?? undefined}
      protocols={view?.protocols ?? []}
      fields={formState}
      onsaved={(route) => void submit(route, editing ?? null)}
      oncancel={() => (editing = undefined)}
    />
  </Modal>
{/if}
