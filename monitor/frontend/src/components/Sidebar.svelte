<script lang="ts">
  import { ChevronsLeft, ChevronsRight, LogOut, Monitor, Pencil, Plus, Server, Settings } from '@lucide/svelte'
  import { IconButton, cn } from '@serverbox/webui'
  import LocaleToggle from './LocaleToggle.svelte'
  import ServerFormModal from './ServerFormModal.svelte'
  import ThemeToggle from './ThemeToggle.svelte'
  import { onDestroy, onMount } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { health } from '../lib/health.svelte'
  import { layout } from '../lib/layout.svelte'
  import { displayName, servers, type ServerEntry } from '../lib/servers.svelte'

  function selectServer(id: string) {
    layout.mobileOpen = false
    layout.view = 'dashboard'
    servers.select(id)
  }

  function openSettings() {
    layout.mobileOpen = false
    layout.view = 'settings'
  }

  let formOpen = $state(false)
  let editingEntry = $state<ServerEntry | undefined>(undefined)

  function openAdd() {
    editingEntry = undefined
    formOpen = true
  }

  function openEdit(entry: ServerEntry) {
    editingEntry = entry
    formOpen = true
  }

  // Collapse only applies to the desktop rail; the mobile drawer is always
  // full width with labels, so visibility is CSS-driven (lg:hidden), not #if
  onMount(() => health.start())
  onDestroy(() => health.stop())

  function dotCls(id: string): string {
    const h = health.status[id]
    if (h === undefined) return 'bg-faint-fg'
    return h ? 'bg-success' : 'bg-danger'
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
      <IconButton class={cn('-mr-1', labelCls)} label={$LL.addServer()} onclick={openAdd}>
        <Plus class="w-4 h-4" />
      </IconButton>
    </div>
    {#each servers.list as s (s.id)}
      {@const active = s.id === servers.currentId}
      <div
        class={cn(
          'w-full flex items-center gap-1 rounded-lg transition-colors',
          active ? 'bg-soft' : 'hover:bg-soft/60',
          centerCls,
        )}
      >
        <button
          type="button"
          class={cn(
            'min-w-0 flex-1 flex items-center gap-2.5 px-2.5 py-2 rounded-lg text-sm text-left cursor-pointer',
            active ? 'text-fg-strong font-medium' : 'text-muted-fg hover:text-fg',
          )}
          title={s.id === 'local' ? $LL.thisServer() : displayName(s)}
          onclick={() => selectServer(s.id)}
        >
          <Server class="w-4 h-4 shrink-0" />
          <span class={cn('min-w-0 flex-1', labelCls)}>
            <span class="block truncate"
              >{s.id === 'local' ? $LL.thisServer() : displayName(s)}</span
            >
            {#if s.url}
              <span class="block truncate text-xs text-faint-fg">{s.url}</span>
            {/if}
          </span>
          <span
            class={cn('w-2 h-2 rounded-full shrink-0', dotCls(s.id))}
            title={health.status[s.id] === false ? $LL.disconnected() : $LL.connected()}
          ></span>
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

  <div class={cn('border-t border-line px-2 py-3 space-y-1', centerCls)}>
    <!-- Agent-level (not per-server) settings entry -->
    <button
      type="button"
      class={cn(
        'w-full flex items-center gap-2.5 px-2.5 py-2 rounded-lg text-sm text-left cursor-pointer transition-colors',
        layout.view === 'settings'
          ? 'bg-soft text-fg-strong font-medium'
          : 'text-muted-fg hover:bg-soft/60 hover:text-fg',
        centerCls,
      )}
      title={$LL.settings()}
      onclick={openSettings}
    >
      <Settings class="w-4 h-4 shrink-0" />
      <span class={labelCls}>{$LL.settings()}</span>
    </button>
    <!-- Language + theme share one row: the select needs full width to show
         language names, so it's hidden (not shrunk) on the collapsed rail,
         leaving just the theme icon centered -->
    <div class={cn('flex items-center gap-2', layout.collapsed && 'lg:justify-center')}>
      <div class={cn('min-w-0 flex-1', labelCls)}>
        <LocaleToggle />
      </div>
      <ThemeToggle />
    </div>
    <div class={cn('flex items-center gap-2', layout.collapsed && 'lg:justify-center')}>
      <span class={cn('flex-1 min-w-0 pl-3 text-sm text-muted-fg truncate', labelCls)}>
        {servers.current?.username}
      </span>
      <IconButton label={$LL.logout()} class="hover:text-danger" onclick={() => servers.logout()}>
        <LogOut class="w-4 h-4" />
      </IconButton>
    </div>
  </div>
</aside>

<ServerFormModal open={formOpen} entry={editingEntry} onclose={() => (formOpen = false)} />
