<script lang="ts">
  import type { Component, Snippet } from 'svelte'

  /// A titled group of sidebar rows. [boxed] draws it as a card, tinted with
  /// the accent while it holds the chosen row (ClawBox's Settings); plain, it
  /// is a heading over rows (its Finder).

  interface Props {
    title?: string
    icon?: Component
    boxed?: boolean
    children: Snippet
  }

  const { title, icon: Icon, boxed = false, children }: Props = $props()
</script>

<section class="mb-3" class:source-box={boxed}>
  {#if title}
    <h3 class="flex items-center gap-1.5 px-2 pb-1.5 pt-1 text-xs font-bold text-fg-strong">
      {#if Icon}
        <span class="desk-glyph h-5 w-5 rounded-[0.45rem]"><Icon class="h-3 w-3" /></span>
      {/if}
      <span class="truncate">{title}</span>
    </h3>
  {/if}
  <div class="space-y-0.5">{@render children()}</div>
</section>

<style>
  .source-box {
    border-radius: 1rem;
    border: 1px solid hsl(var(--ink) / 0.1);
    padding: 0.3rem;
    transition:
      background-color 160ms,
      border-color 160ms;
  }
  .source-box:has(:global([aria-current='true'])) {
    border-color: color-mix(in srgb, var(--desk-accent) 26%, transparent);
    background: color-mix(in srgb, var(--desk-accent) 8%, transparent);
  }
</style>
