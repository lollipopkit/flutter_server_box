<script lang="ts">
  import { PanelLeft } from '@lucide/svelte'
  import type { Snippet } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'

  /// An app's two columns: a translucent sidebar (places, sections, items)
  /// and the content beside it, as Finder and Settings have. Below `@3xl`
  /// the sidebar folds away behind a toolbar button.

  interface Props {
    sidebar: Snippet
    children: Snippet
    /// The sidebar's width in rem when shown beside the content.
    width?: number
  }

  const { sidebar, children, width = 15 }: Props = $props()
  let open = $state(false)
  /// The container's width, which decides whether the sidebar folds (`@3xl`
  /// is 48rem); folded and closed, it is `inert` so the keyboard does not
  /// reach rows nobody can see.
  let folded = $state(false)
  let root = $state<HTMLDivElement | null>(null)
  $effect(() => {
    // Absent outside a browser (tests), where nothing folds.
    if (!root || typeof ResizeObserver === 'undefined') return
    const observer = new ResizeObserver(([e]) => (folded = e.contentRect.width < 768))
    observer.observe(root)
    return () => observer.disconnect()
  })
</script>

<div class="relative flex h-full min-h-0" bind:this={root}>
  <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
  <aside
    class="desk-app-sidebar absolute inset-y-0 left-0 z-20 overflow-y-auto px-2.5 py-3 transition-transform @3xl:static @3xl:translate-x-0"
    class:-translate-x-full={!open}
    style:width="{width}rem"
    aria-label={$LL.deskSidebar()}
    inert={folded && !open}
    onclick={(e) => {
      // A choice made in the folded sidebar is a reason to fold it again.
      if (folded && (e.target as HTMLElement).closest('button')) open = false
    }}
  >
    {@render sidebar()}
  </aside>
  {#if open}
    <button class="absolute inset-0 z-10 bg-black/10 @3xl:hidden" aria-label={$LL.deskSidebar()} onclick={() => (open = false)}></button>
  {/if}
  <!-- A column: the fold button keeps its line, the content scrolls on its
       own below it, so a full-height content never scrolls twice. -->
  <div class="flex min-w-0 flex-1 flex-col">
    <button
      class="m-2 mb-0 grid h-8 w-8 shrink-0 place-items-center rounded-lg text-muted-fg inset-ring inset-ring-line hover:bg-soft @3xl:hidden"
      aria-label={$LL.deskSidebar()}
      aria-expanded={open}
      onclick={() => (open = !open)}
    >
      <PanelLeft class="h-4 w-4" />
    </button>
    <div class="min-h-0 flex-1 overflow-auto">
      {@render children()}
    </div>
  </div>
</div>
