<script lang="ts">
  import { ChevronLeft } from '@lucide/svelte'
  import { IconButton } from '@serverbox/webui'
  import type { Snippet } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'

  /// An app's toolbar, the first thing in its window under the title bar:
  /// what this view is about and what can be done to it. The app's name is
  /// the window's title already; [title] is for a view inside the app (a
  /// guest, a service), with [back] to leave it.

  interface Props {
    title?: string
    subtitle?: string
    /// Before the title (an OS icon, a status dot).
    leading?: Snippet
    /// Leaves a view inside the app; absent at the app's first view.
    back?: () => void
    /// Right-aligned: buttons, badges.
    actions?: Snippet
    /// Other views of the app, under the title row.
    tabs?: Snippet
  }

  const { title, subtitle, leading, back, actions, tabs }: Props = $props()
</script>

<header class="app-toolbar sticky top-0 z-10 border-b border-line bg-surface/90 backdrop-blur">
  <div class="flex min-h-13 items-center gap-2 px-3.5 py-2">
    {#if back}
      <IconButton class="-ml-1" label={$LL.back()} onclick={back}>
        <ChevronLeft class="h-5 w-5" />
      </IconButton>
    {/if}
    {#if leading}{@render leading()}{/if}
    {#if title || subtitle}
      <div class="min-w-0 leading-tight">
        {#if title}<h1 class="truncate font-display text-[0.95rem] font-bold text-fg-strong">{title}</h1>{/if}
        {#if subtitle}<p class="truncate text-xs text-muted-fg">{subtitle}</p>{/if}
      </div>
    {/if}
    <span class="flex-1"></span>
    {#if actions}
      <div class="flex shrink-0 items-center gap-1.5">{@render actions()}</div>
    {/if}
  </div>
  {#if tabs}
    <div class="px-3">{@render tabs()}</div>
  {/if}
</header>

<style>
  /* Nothing in it (an app whose actions all depend on a state it is not in):
     no strip under the title bar. */
  .app-toolbar:not(:has(:global(:is(h1, p, button, a, input, select, svg, img)))) {
    display: none;
  }
</style>
