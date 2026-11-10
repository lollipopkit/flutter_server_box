<script lang="ts">
  import { untrack, type Snippet } from 'svelte'
  import { useWindow } from './window.svelte'

  /// What sits at the window's foot, under the scrolling content: an `lk`
  /// `StatusBar` (counts, the selection's actions), and anything over it (a
  /// selection's detail). Outside a window (a test) it is drawn here.

  interface Props {
    children: Snippet
  }

  const { children }: Props = $props()
  const chrome = useWindow().chrome

  if (chrome) {
    // The initial value; the effect below keeps it in step.
    const entry = $state(untrack(() => ({ content: children })))
    $effect.pre(() => {
      entry.content = children
    })
    $effect(() => chrome.pushFooter(entry))
  }
</script>

{#if !chrome}{@render children()}{/if}
