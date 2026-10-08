<script lang="ts">
  import { Badge, Button, Card, Dialog, Icon, IconButton, Input, Spinner } from '@lollipopkit/desk-ui'
  import { AppToolbar, PageStack } from '../../sys'
  import DesktopForm, { desktopFormState, type DesktopFormState } from './DesktopForm.svelte'
  import RdpViewer from './RdpViewer.svelte'
  import VncViewer from '../../../components/VncViewer.svelte'
  import { api } from '../../../lib/api'
  import { DesktopSession, rdpEndpoint, type RdpEndpoint, type RelayChannel } from '../../../lib/desktop.svelte'
  import { desktopRefusalText } from '../../../lib/desktopRefusal'
  import { servers } from '../../../lib/servers.svelte'
  import { onDestroy, untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { Desktop, DesktopsView } from '../../../types'

  /// The desktop routes saved on the agent, and the session opened on one: VNC
  /// is noVNC over the `/stream/ws` relay, RDP is IronRDP through the agent's
  /// `/rdp/ws` proxy. The password is asked for when a session opens and kept
  /// nowhere.

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

  /// Closes the password dialog without connecting; what was typed goes too.
  function dismissPassword() {
    pending = null
    password = ''
  }

  const desktops = $derived(view?.desktops ?? [])

  /// Why a route cannot be opened, or `null`: an RDP session signs in, so it
  /// needs a user name.
  function blockOf(desktop: Desktop): string | null {
    return desktop.protocol === 'rdp' && !desktop.username ? $LL.desktopRdpUsername() : null
  }
</script>

<!-- The session is a page over the list. No swipe back: that would close a
     live connection, which only the chevron and Disconnect do. -->
<PageStack key={live && sessionDesktop ? 'session' : 'list'} depth={live && sessionDesktop ? 1 : 0}>
{#if live && sessionDesktop}
  <!-- The session takes the page: leaving it by the back chevron closes it,
       since a relay left open is a connection nobody is looking at. -->
  <AppToolbar title={sessionDesktop.name} back={() => endSession(null)}>
    {#snippet actions()}
      <IconButton icon="link_off" label={$LL.desktopDisconnect()} onclick={() => endSession(null)} />
    {/snippet}
  </AppToolbar>

  <!-- The session fills what the toolbar leaves of the window; the viewer
       takes its parent's height. -->
  <main class="flex min-h-72 flex-1 flex-col px-(--content-pad) pb-[21px] pt-[5px]">
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
  <AppToolbar subtitle={view ? $LL.desktopSubtitle({ count: desktops.length }) : undefined}>
    {#snippet actions()}
      <Button size="sm" variant="tinted" icon="add" onclick={() => openForm(null)}>{$LL.desktopAdd()}</Button>
      <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} disabled={loading} />
    {/snippet}
  </AppToolbar>

  <main class="space-y-[9px] px-(--content-pad) pb-[21px] pt-[5px]">
    {#if error}<Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card>{/if}
    {#if actionError}
      <Card>
        <div class="flex flex-wrap items-center justify-between gap-[9px]">
          <p class="text-[13px] text-(--color-danger) whitespace-pre-wrap break-all">{actionError}</p>
          {#if retry}<Button variant="secondary" onclick={() => (pending = retry)}>{$LL.desktopReconnect()}</Button>{/if}
        </div>
      </Card>
    {/if}
    {#if notice}<Card><p class="text-[13px] text-(--text-secondary)">{notice}</p></Card>{/if}

    {#if loading && !view}
      <Card class="grid place-items-center" padding="21px"><Spinner size={20} /></Card>
    {:else if view}
      {#if desktops.length === 0}
        <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
          <Icon name="desktop_windows" size={48} weight={300} />
          <span class="text-[13px]">{$LL.desktopsEmptyState()}</span>
        </div>
      {:else}
        <ul class="space-y-[7px]">
          {#each desktops as desktop (desktop.id)}
            <li>
              <Card padding="11px 13px" onclick={() => open(desktop)}>
                <div class="flex min-w-0 items-center gap-[13px]">
                  <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised) text-(--color-accent-text)"><Icon name="desktop_windows" size={18} /></span>
                  <div class="min-w-0 flex-1">
                    <div class="flex flex-wrap items-center gap-[7px]">
                      <span class="truncate text-[13px] font-semibold">{desktop.name}</span>
                      <Badge tone="neutral">{desktop.protocol.toUpperCase()}</Badge>
                      {#if desktop.view_only}<Badge tone="warning">{$LL.desktopViewOnly()}</Badge>{/if}
                    </div>
                    <p class="lk-mono truncate text-[12px] text-(--text-tertiary)">{desktop.host}:{desktop.port}{#if desktop.username} · {desktop.username}{/if}</p>
                  </div>
                </div>
              </Card>
            </li>
          {/each}
        </ul>
      {/if}

      <p class="text-[12px] text-(--text-tertiary)">{$LL.desktopRouteNote()}</p>
      {#if busy}<div class="flex items-center gap-[7px] text-[12px] text-(--text-tertiary)"><Spinner size="sm" /></div>{/if}
    {/if}
  </main>
{/if}
</PageStack>

{#if opened && editing === undefined && !live}
  {@const desktop = opened}
  <Dialog open wide title={desktop.name} onclose={() => (opened = null)}>
    {#snippet actions()}
      {#if removing}
        <Button variant="destructive" disabled={busy} onclick={() => void remove()}>{$LL.desktopDelete()}</Button>
        <Button variant="secondary" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
      {:else}
        <Button variant="primary" icon="desktop_windows" disabled={busy || blockOf(desktop) !== null} onclick={() => { pending = desktop; opened = null }}>{$LL.desktopConnect()}</Button>
        <Button variant="secondary" icon="edit" onclick={() => openForm(desktop)}>{$LL.desktopEdit()}</Button>
        <Button variant="destructive" icon="delete" onclick={() => (removing = true)}>{$LL.desktopDelete()}</Button>
        <Button variant="secondary" onclick={() => (opened = null)}>{$LL.close()}</Button>
      {/if}
    {/snippet}
    <div class="flex flex-wrap gap-[7px]">
      <Badge tone="neutral">{desktop.protocol.toUpperCase()}</Badge>
      {#if desktop.view_only}<Badge tone="warning">{$LL.desktopViewOnly()}</Badge>{/if}
    </div>
    {#if removing}<p class="mt-[13px] text-[13px] text-(--text-secondary)">{$LL.desktopDeleteConfirm({ name: desktop.name })}</p>{/if}
    <dl class="mt-[13px] grid grid-cols-2 gap-x-[13px] @2xl:grid-cols-3">
      <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.desktopHost()}</dt><dd class="lk-mono break-all text-right text-[12px]">{desktop.host}:{desktop.port}</dd></div>
      <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.desktopUsername()}</dt><dd class="lk-mono break-all text-right text-[12px]">{desktop.username ?? '—'}</dd></div>
      {#if desktop.domain}<div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.desktopDomain()}</dt><dd class="lk-mono text-right text-[12px]">{desktop.domain}</dd></div>{/if}
    </dl>
    {#if blockOf(opened)}<p class="mt-[9px] text-[12px] text-(--text-secondary)">{blockOf(opened)}</p>{/if}
  </Dialog>
{/if}

<!-- The password exists only in this dialog and in the viewer it is handed to. -->
{#if pending}
  {@const target = pending}
  <Dialog open wide title={$LL.desktopConnect()} onclose={dismissPassword}>
    {#snippet actions()}
      <Button variant="primary" type="submit" form="desktop-connect-form" disabled={busy}>{$LL.desktopConnect()}</Button>
      <Button variant="secondary" onclick={dismissPassword}>{$LL.cancel()}</Button>
    {/snippet}
    <form id="desktop-connect-form" onsubmit={(e) => { e.preventDefault(); void connect(target) }}>
      <p class="text-[12px] text-(--text-secondary)">{target.name} · <span class="lk-mono">{target.host}:{target.port}</span></p>
      <Input class="mt-[13px]" id="desktop-password" label={$LL.desktopPassword()} type="password" autocomplete="off" bind:value={password} hint={$LL.desktopPasswordNone()} />
    </form>
  </Dialog>
{/if}

{#if editing !== undefined}
  <Dialog open wide title={editing ? $LL.desktopEdit() : $LL.desktopAdd()} onclose={() => (editing = undefined)}>
    <DesktopForm
      desktop={editing ?? undefined}
      protocols={view?.protocols ?? []}
      fields={formState}
      onsaved={(desktop) => void submit(desktop, editing ?? null)}
      oncancel={() => (editing = undefined)}
    />
  </Dialog>
{/if}
