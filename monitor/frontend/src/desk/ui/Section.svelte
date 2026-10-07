<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A titled card in an app's content (ClawBox's panels): a large radius, a
  /// hairline, a bold title with an optional count and actions at its right.

  interface Props {
    title?: string
    /// Shown in a small circle after the title.
    count?: number
    actions?: Snippet
    class?: string
    children: Snippet
  }

  const { title, count, actions, class: className = '', children }: Props = $props()
</script>

<section class="rounded-3xl border border-line p-5 @3xl:p-6 {className}">
  {#if title || actions}
    <header class="mb-4 flex items-center justify-between gap-3">
      <h2 class="min-w-0 truncate text-lg font-bold text-fg-strong">{title}</h2>
      <div class="flex shrink-0 items-center gap-2">
        {#if actions}{@render actions()}{/if}
        {#if count !== undefined}
          <span class="grid h-7 min-w-7 place-items-center rounded-full border border-line px-2 text-xs font-bold tabular-nums">
            {count}
          </span>
        {/if}
      </div>
    </header>
  {/if}
  {@render children()}
</section>
