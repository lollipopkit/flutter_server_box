<script lang="ts">
  import { ChevronsLeft, ChevronsRight, LogOut, Monitor, Server } from '@lucide/svelte'
  import { IconButton, cn } from '@serverbox/webui'
  import LocaleToggle from './LocaleToggle.svelte'
  import ThemeToggle from './ThemeToggle.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { layout } from '../lib/layout.svelte'
  import { servers } from '../lib/servers.svelte'

  function selectServer(id: string) {
    layout.mobileOpen = false
    servers.select(id)
  }

  // Collapse only applies to the desktop rail; the mobile drawer is always
  // full width with labels, so visibility is CSS-driven (lg:hidden), not #if
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
    <p class={cn('px-2 pb-1 text-xs font-medium text-faint-fg uppercase tracking-wide', labelCls)}>
      {$LL.servers()}
    </p>
    {#each servers.list as s (s.id)}
      {@const active = s.id === servers.currentId}
      <button
        class={cn(
          'w-full flex items-center gap-2.5 px-2.5 py-2 rounded-lg text-sm text-left cursor-pointer transition-colors',
          active
            ? 'bg-soft text-fg-strong font-medium'
            : 'text-muted-fg hover:bg-soft/60 hover:text-fg',
          centerCls,
        )}
        title={s.id === 'local' ? $LL.thisServer() : s.name}
        onclick={() => selectServer(s.id)}
      >
        <Server class="w-4 h-4 shrink-0" />
        <span class={cn('min-w-0 flex-1', labelCls)}>
          <span class="block truncate">{s.id === 'local' ? $LL.thisServer() : s.name}</span>
          {#if s.url}
            <span class="block truncate text-xs text-faint-fg">{s.url}</span>
          {/if}
        </span>
      </button>
    {/each}
  </nav>

  <div class="border-t border-line px-2 py-3 space-y-2">
    <div class={cn('flex items-center gap-1', layout.collapsed && 'lg:flex-col lg:items-center')}>
      <LocaleToggle />
      <ThemeToggle />
    </div>
    <div class={cn('flex items-center gap-2 px-1', layout.collapsed && 'lg:justify-center lg:px-0')}>
      <span class={cn('flex-1 text-sm text-muted-fg truncate', labelCls)}>
        {servers.current?.username}
      </span>
      <IconButton label={$LL.logout()} class="hover:text-danger" onclick={() => servers.logout()}>
        <LogOut class="w-4 h-4" />
      </IconButton>
    </div>
  </div>
</aside>
