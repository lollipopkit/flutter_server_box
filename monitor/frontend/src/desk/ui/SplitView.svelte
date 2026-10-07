<script lang="ts">
  import { untrack, type Snippet } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { useWindow } from '../deskState.svelte'

  /// An app's two columns: the sidebar (places, sections, items — built from
  /// `lk` SidebarSection/SidebarItem) goes into the window's floating inset
  /// sidebar, which folds behind a title-bar button in a narrow window; the
  /// content is drawn here and scrolls on its own. Outside a window (a test)
  /// both are drawn here side by side.

  interface Props {
    sidebar: Snippet
    children: Snippet
    /// The sidebar's width in rem.
    width?: number
  }

  const { sidebar, children, width = 12.5 }: Props = $props()
  const chrome = useWindow().chrome

  if (chrome) {
    // The initial values; the effect below keeps them in step.
    const entry = $state(untrack(() => ({ content: sidebar, width: width * 16 })))
    $effect.pre(() => {
      entry.content = sidebar
      entry.width = width * 16
    })
    $effect(() => chrome.pushSidebar(entry))
  }
</script>

{#if chrome}
  <div class="min-h-0 flex-1 overflow-auto">{@render children()}</div>
{:else}
  <div class="flex h-full min-h-0">
    <aside class="shrink-0 overflow-y-auto px-[7px] pb-[9px]" style:width="{width}rem" aria-label={$LL.deskSidebar()}>
      {@render sidebar()}
    </aside>
    <div class="min-h-0 min-w-0 flex-1 overflow-auto">{@render children()}</div>
  </div>
{/if}
