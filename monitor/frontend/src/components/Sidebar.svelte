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

  const showLabels = $derived(!layout.collapsed)
</script>

{#if layout.mobileOpen}
  <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
  <div
    class="lg:hidden fixed inset-0 z-40 bg-black/40"
    onclick={() => (layout.mobileOpen = false)}
  ></div>
{/if}

<aside
  class={cn(
    'fixed lg:sticky top-0 z-50 lg:z-auto h-dvh shrink-0 flex flex-col',
    'bg-surface border-r border-line transition-[width,transform] duration-200',
    'w-60 -translate-x-full lg:translate-x-0',
    layout.mobileOpen && 'translate-x-0',
    layout.collapsed && 'lg:w-16',
  )}
>
  <div class="flex items-center gap-2 px-3 py-4 border-b border-line min-h-16">
    <Monitor class="w-7 h-7 text-accent shrink-0 mx-0.5" />
    {#if showLabels}
      <span class="font-display font-semibold text-fg-strong truncate">ServerBox</span>
    {/if}
    <span class="flex-1"></span>
    <IconButton
      class="hidden lg:inline-flex"
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
    {#if showLabels}
      <p class="px-2 pb-1 text-xs font-medium text-faint-fg uppercase tracking-wide">
        {$LL.servers()}
      </p>
    {/if}
    {#each servers.list as s (s.id)}
      {@const active = s.id === servers.currentId}
      <button
        class={cn(
          'w-full flex items-center gap-2.5 px-2.5 py-2 rounded-lg text-sm text-left cursor-pointer transition-colors',
          active
            ? 'bg-soft text-fg-strong font-medium'
            : 'text-muted-fg hover:bg-soft/60 hover:text-fg',
        )}
        title={s.id === 'local' ? $LL.thisServer() : s.name}
        onclick={() => selectServer(s.id)}
      >
        <Server class="w-4 h-4 shrink-0" />
        {#if showLabels}
          <span class="min-w-0 flex-1">
            <span class="block truncate">{s.id === 'local' ? $LL.thisServer() : s.name}</span>
            {#if s.url}
              <span class="block truncate text-xs text-faint-fg">{s.url}</span>
            {/if}
          </span>
        {/if}
      </button>
    {/each}
  </nav>

  <div class="border-t border-line px-2 py-3 space-y-2">
    <div class={cn('flex items-center gap-1', layout.collapsed && 'lg:flex-col')}>
      <LocaleToggle />
      <ThemeToggle />
    </div>
    <div class={cn('flex items-center gap-2 px-1', layout.collapsed && 'lg:justify-center lg:px-0')}>
      {#if showLabels}
        <span class="flex-1 text-sm text-muted-fg truncate">{servers.current?.username}</span>
      {/if}
      <IconButton label={$LL.logout()} class="hover:text-danger" onclick={() => servers.logout()}>
        <LogOut class="w-4 h-4" />
      </IconButton>
    </div>
  </div>
</aside>
