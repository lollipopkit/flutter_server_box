<script lang="ts">
  import { ChevronsLeft, ChevronsRight, LogOut, Monitor, Pencil, Plus, Search, Server, Settings } from '@lucide/svelte'
  import { IconButton, Input, cn } from '@serverbox/webui'
  import OsIcon from './OsIcon.svelte'
  import ServerFormModal from './ServerFormModal.svelte'
  import { onDestroy, onMount } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { health } from '../lib/health.svelte'
  import { layout } from '../lib/layout.svelte'
  import { serverNames } from '../lib/serverNames.svelte'
  import { serverMatches } from '../lib/serverSearch'
  import { displayName, servers, type ServerEntry } from '../lib/servers.svelte'

  // Fetch each authenticated server's capabilities once for its OS icon.
  $effect(() => {
    for (const s of servers.list) void capabilitiesStore.ensure(s.id)
  })

  // Refresh immediately after authentication changes instead of waiting for
  // the next 30-second name poll.
  $effect(() => {
    servers.list.map((s) => s.token).join(',')
    void serverNames.refresh()
  })

  /// Live name from the agent (`config.toml`), never a locally cached one.
  /// Falls back to a "not connected yet" placeholder for `local`, or the
  /// URL or ID for everything else, until the first successful fetch.
  function label(s: ServerEntry): string {
    const live = serverNames.byServer[s.id]
    if (live) return live
    return s.id === 'local' ? $LL.thisServer() : displayName(s)
  }

  function selectServer(id: string) {
    layout.mobileOpen = false
    layout.navigate('dashboard')
    servers.select(id)
  }

  function openPanelSettings() {
    layout.mobileOpen = false
    layout.navigate('panel')
  }

  let editingEntry = $state<ServerEntry | undefined>(undefined)

  /// The search field's text. Not persisted: it narrows the list for the
  /// moment, and a saved view is not what this is for.
  let query = $state('')

  /// The rows the query keeps. Filtering only hides rows — `servers.currentId`
  /// is left alone, so the selected server stays selected while it is hidden.
  const filtered = $derived(servers.list.filter((s) => serverMatches(query, label(s), s.url)))

  /// Only on the mobile drawer and the expanded desktop rail: a rail has no
  /// width for a field, and one server needs no search. `lg:hidden` rather
  /// than not rendering, since `layout.collapsed` is the desktop rail alone.
  const searchCls = $derived(cn(layout.collapsed && 'lg:hidden'))

  function onSearchKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      query = ''
      return
    }
    // Enter is "take the one that is left", not a submit: with several rows
    // there is no one answer, and with none there is nothing to take.
    if (e.key === 'Enter' && filtered.length === 1) selectServer(filtered[0].id)
  }

  function openAdd() {
    editingEntry = undefined
    layout.addServerOpen = true
  }

  function openEdit(entry: ServerEntry) {
    editingEntry = entry
    layout.addServerOpen = true
  }

  // Only the desktop rail collapses. CSS keeps the mobile drawer full width.
  onMount(() => {
    // Before the pollers: the list may still hold the assumed same-origin
    // entry, and on a static host there is nothing there to poll.
    void servers.confirmSameOrigin()
    health.start()
    serverNames.start()
  })
  onDestroy(() => {
    health.stop()
    serverNames.stop()
  })

  // Brighter than the shared success/danger tokens (--color-success/danger
  // are muted 600-shades meant for text/badges) — a small icon needs more
  // saturation to read as a status signal at a glance
  function statusIconCls(id: string): string {
    const h = health.status[id]
    if (h === undefined) return 'text-faint-fg'
    return h ? 'text-green-500' : 'text-red-500'
  }

  function statusTitle(id: string): string {
    return health.status[id] === false ? $LL.disconnected() : $LL.connected()
  }

  const labelCls = $derived(layout.collapsed ? 'lg:hidden' : '')
  const centerCls = $derived(layout.collapsed ? 'lg:justify-center lg:px-0' : '')
</script>

<!-- Backdrop stays mounted so open/close can fade -->
<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div
  class={cn(
    'lg:hidden fixed inset-0 z-40 bg-black/40 transition-opacity duration-300',
    layout.mobileOpen ? 'opacity-100' : 'opacity-0 pointer-events-none',
  )}
  onclick={() => (layout.mobileOpen = false)}
></div>

<aside
  class={cn(
    'fixed lg:sticky top-0 z-50 lg:z-auto h-dvh shrink-0 flex flex-col',
    'bg-surface border-r border-line will-change-transform',
    'transition-[transform,width] duration-300 ease-out',
    'w-60 -translate-x-full lg:translate-x-0',
    layout.mobileOpen && 'translate-x-0',
    layout.collapsed && 'lg:w-16',
  )}
>
  <!-- h-16 matches the content header exactly so the divider lines up -->
  <div class={cn('flex items-center gap-2 border-b border-line h-16 px-3', centerCls)}>
    <Monitor class={cn('w-7 h-7 text-accent shrink-0', layout.collapsed && 'lg:hidden')} />
    <span class={cn('font-display font-semibold text-fg-strong truncate', labelCls)}>
      ServerBox
    </span>
    <span class={cn('flex-1', labelCls)}></span>
    <IconButton
      class="hidden lg:inline-flex shrink-0"
      label={layout.collapsed ? $LL.expandSidebar() : $LL.collapseSidebar()}
      onclick={() => layout.toggleCollapsed()}
    >
      {#if layout.collapsed}
        <ChevronsRight class="w-4 h-4" />
      {:else}
        <ChevronsLeft class="w-4 h-4" />
      {/if}
    </IconButton>
  </div>

  <nav class="flex-1 overflow-y-auto px-2 py-3 space-y-1">
    <div class="flex items-center justify-between px-2 pb-1">
      <p class={cn('text-xs font-medium text-faint-fg uppercase tracking-wide', labelCls)}>
        {$LL.servers()}
      </p>
      {#if !servers.servedByAgent}
        <!-- Absent on the panel an agent serves, which holds the one server it
             is served by; there is no second one to add there. -->
        <IconButton class={cn('-mr-1', labelCls)} label={$LL.addServer()} onclick={openAdd}>
          <Plus class="w-4 h-4" />
        </IconButton>
      {/if}
    </div>
    {#if servers.list.length >= 2}
      <div class={cn('relative px-1 pb-2', searchCls)}>
        <Search class="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-faint-fg" />
        <Input
          bind:value={query}
          placeholder={$LL.serversSearch()}
          class="pl-8"
          onkeydown={onSearchKeydown}
        />
      </div>
      {#if filtered.length === 0}
        <p class={cn('px-2.5 pb-2 text-sm text-muted-fg', searchCls)}>{$LL.serversNoMatch()}</p>
      {/if}
    {/if}
    {#each filtered as s (s.id)}
      {@const active = s.id === servers.currentId}
      <div
        class={cn(
          'w-full flex items-center gap-1 rounded-lg transition-colors',
          active ? 'bg-soft' : 'hover:bg-soft/60',
        )}
      >
        <button
          type="button"
          class={cn(
            'min-w-0 flex-1 flex items-center gap-2.5 px-2.5 py-2 rounded-lg text-sm text-left cursor-pointer',
            active ? 'text-fg-strong font-medium' : 'text-muted-fg hover:text-fg',
            centerCls,
          )}
          title={label(s)}
          onclick={() => selectServer(s.id)}
        >
          {#if capabilitiesStore.byServer[s.id]?.platform}
            <OsIcon
              platform={capabilitiesStore.byServer[s.id]?.platform}
              class={cn('w-4 h-4 shrink-0', statusIconCls(s.id))}
              title={statusTitle(s.id)}
            />
          {:else}
            <Server class={cn('w-4 h-4 shrink-0', statusIconCls(s.id))} title={statusTitle(s.id)} />
          {/if}
          <span class={cn('min-w-0 flex-1 truncate', labelCls)}>{label(s)}</span>
        </button>
        {#if s.id !== 'local'}
          <IconButton
            label={$LL.editServer()}
            class={cn('shrink-0 mr-1', labelCls)}
            onclick={() => openEdit(s)}
          >
            <Pencil class="w-3.5 h-3.5" />
          </IconButton>
        {/if}
      </div>
    {/each}
  </nav>

  <div class={cn('border-t border-line p-2', centerCls)}>
    <!-- Just two buttons — a row when expanded, a column when collapsed -->
    <div class={cn('flex items-center justify-center gap-1', layout.collapsed && 'lg:flex-col')}>
      <IconButton
        label={$LL.panelSettings()}
        class={cn(
          'shrink-0',
          layout.view === 'panel' ? 'bg-soft text-fg-strong' : 'text-muted-fg',
        )}
        onclick={openPanelSettings}
      >
        <Settings class="w-4 h-4" />
      </IconButton>
      <IconButton label={$LL.logout()} class="hover:text-danger shrink-0" onclick={() => servers.logout()}>
        <LogOut class="w-4 h-4" />
      </IconButton>
    </div>
  </div>
</aside>

<ServerFormModal
  open={layout.addServerOpen}
  entry={editingEntry}
  onclose={() => (layout.addServerOpen = false)}
/>
