<script lang="ts">
  import type { Snippet } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { useWindow } from './window.svelte'
  import type { ToolbarChrome } from '../window/chrome.svelte'
  import IconButton from '@lollipopkit/desk-ui/IconButton.svelte'

  /// An app's title and tools. Inside a window they go into the window's
  /// title bar (the app's name is the bar's title already; [title] is for a
  /// view inside the app, with [back] to leave it); outside one (a test) they
  /// are drawn here. Write it first in the app's markup.

  interface Props {
    title?: string
    subtitle?: string
    /// Before the title (an OS icon, a status dot).
    leading?: Snippet
    /// Leaves a view inside the app; absent at the app's first view.
    back?: () => void
    /// At the bar's right: IconButtons, a SegmentedControl, a small Button.
    actions?: Snippet
    /// Other views of the app, under the bar.
    tabs?: Snippet
    /// Instead of the title: a path, a breadcrumb.
    heading?: Snippet
    /// A solid bar, never glass: the view starts with a `DataTable`.
    flush?: boolean
  }

  const { title, subtitle, leading, back, actions, tabs, heading, flush = false }: Props = $props()
  const chrome = useWindow().chrome

  if (chrome) {
    // One entry for this toolbar's life, kept in step with its props.
    const entry = $state<ToolbarChrome>({})
    $effect.pre(() => {
      entry.heading = heading
      entry.flush = flush
      entry.title = title
      entry.subtitle = subtitle
      entry.leading = leading
      entry.back = back
      entry.actions = actions
      entry.tabs = tabs
    })
    $effect(() => chrome.pushToolbar(entry))
  }
</script>

{#if !chrome}
  <header class="flex min-h-11 flex-wrap items-center gap-[9px] px-[17px] py-[5px]">
    {#if back}<IconButton icon="chevron_left" label={$LL.back()} onclick={back} />{/if}
    {@render leading?.()}
    {#if heading}
      {@render heading()}
    {:else if title || subtitle}
      <div class="flex min-w-0 items-baseline gap-[7px]">
        {#if title}<h1 class="lk-window__title min-w-0 shrink-[0.2]">{title}</h1>{/if}
        {#if subtitle}<p class="min-w-0 truncate text-[12px] text-(--text-tertiary)">{subtitle}</p>{/if}
      </div>
    {/if}
    <span class="flex-1"></span>
    {#if actions}<div class="flex shrink-0 items-center gap-[3px]">{@render actions()}</div>{/if}
    {#if tabs}<div class="w-full">{@render tabs()}</div>{/if}
  </header>
{/if}
