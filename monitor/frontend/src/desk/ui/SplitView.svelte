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

  const { sidebar, children, width = 14 }: Props = $props()
  let open = $state(false)
</script>

<div class="relative flex h-full min-h-0">
  <aside
    class="desk-app-sidebar absolute inset-y-0 left-0 z-20 overflow-y-auto p-2 transition-transform @3xl:static @3xl:translate-x-0"
    class:-translate-x-full={!open}
    style:width="{width}rem"
    aria-label={$LL.deskSidebar()}
  >
    {@render sidebar()}
  </aside>
  {#if open}
    <button class="absolute inset-0 z-10 bg-black/10 @3xl:hidden" aria-label={$LL.deskSidebar()} onclick={() => (open = false)}></button>
  {/if}
  <div class="min-w-0 flex-1 overflow-auto">
    <button
      class="m-2 mb-0 grid h-7 w-7 place-items-center rounded-md text-muted-fg hover:bg-soft @3xl:hidden"
      aria-label={$LL.deskSidebar()}
      aria-expanded={open}
      onclick={() => (open = !open)}
    >
      <PanelLeft class="h-4 w-4" />
    </button>
    {@render children()}
  </div>
</div>
