<script lang="ts">
  import { ChevronLeft, Menu } from '@lucide/svelte'
  import { IconButton } from '@serverbox/webui'
  import type { Snippet } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { layout } from '../lib/layout.svelte'

  interface Props {
    title: string
    subtitle?: string
    /// Rendered immediately before the title text (e.g. an OS icon).
    titleIcon?: Snippet
    /// When present, shows a back chevron instead of the mobile menu button.
    onback?: () => void
    /// Right-aligned actions such as buttons or badges.
    actions?: Snippet
    /// A row of screens reachable from this one, drawn under the title in the
    /// same bar (`FeatureTabs`). Its presence is what makes the bar taller, so
    /// a page without it keeps the plain 16-unit header.
    tabs?: Snippet
    containerClass?: string
  }

  const {
    title,
    subtitle,
    titleIcon,
    onback,
    actions,
    tabs,
    containerClass = 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full',
  }: Props = $props()
</script>

<!-- Sticky top-level bar shared by every page (Dashboard, Settings) and by
     drill-down views (DetailPanel passes onback to reuse this same bar
     instead of stacking a second header underneath it) -->
<header class="sticky top-0 z-10 bg-surface shadow-xs border-b border-line {tabs ? '' : 'h-16'} flex items-center">
  <div class={containerClass}>
    <div class="flex items-center gap-2 {tabs ? 'h-16' : ''}">
      {#if onback}
        <IconButton class="-ml-2" label={$LL.back()} onclick={onback}>
          <ChevronLeft class="w-5 h-5" />
        </IconButton>
      {:else}
        <IconButton class="lg:hidden -ml-2" label={$LL.menu()} onclick={() => (layout.mobileOpen = true)}>
          <Menu class="w-5 h-5" />
        </IconButton>
      {/if}
      <div class="min-w-0 leading-tight flex items-center gap-2">
        {#if titleIcon}{@render titleIcon()}{/if}
        <div class="min-w-0">
          <h1 class="text-base sm:text-lg font-semibold font-display text-fg-strong truncate">{title}</h1>
          {#if subtitle}
            <p class="text-xs text-muted-fg truncate">{subtitle}</p>
          {/if}
        </div>
      </div>
      <span class="flex-1"></span>
      {#if actions}{@render actions()}{/if}
    </div>
    {#if tabs}{@render tabs()}{/if}
  </div>
</header>
