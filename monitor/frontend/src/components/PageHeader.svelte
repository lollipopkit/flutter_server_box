<script lang="ts">
  import { ChevronLeft, Menu } from '@lucide/svelte'
  import { IconButton } from '@serverbox/webui'
  import type { Snippet } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { layout } from '../lib/layout.svelte'

  interface Props {
    title: string
    subtitle?: string
    /// Rendered immediately before the title text (e.g. an OS icon)
    titleIcon?: Snippet
    /// Present => shows a back chevron instead of the mobile menu button
    onback?: () => void
    /// Right-aligned slot (buttons, badges, ...)
    actions?: Snippet
    /// 'page' = full-bleed top-level bar (Dashboard/Settings); 'section' =
    /// lighter in-content sticky bar that stacks below a 'page' header
    /// (DetailPanel drill-down) — no edge-to-edge background, no menu button
    variant?: 'page' | 'section'
    containerClass?: string
  }

  const {
    title,
    subtitle,
    titleIcon,
    onback,
    actions,
    variant = 'page',
    containerClass = 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full',
  }: Props = $props()
</script>

{#snippet inner()}
  <div class="flex items-center gap-2">
    {#if onback}
      <IconButton class="-ml-2" label={$LL.back()} onclick={onback}>
        <ChevronLeft class="w-5 h-5" />
      </IconButton>
    {:else if variant === 'page'}
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
{/snippet}

{#if variant === 'page'}
  <header class="sticky top-0 z-10 bg-surface shadow-xs border-b border-line h-16 flex items-center">
    <div class={containerClass}>
      {@render inner()}
    </div>
  </header>
{:else}
  <div class="sticky top-16 z-10 -mx-4 sm:-mx-6 lg:-mx-8 px-4 sm:px-6 lg:px-8 py-3 bg-surface/95 backdrop-blur border-b border-line">
    {@render inner()}
  </div>
{/if}
