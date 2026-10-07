<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A window's footer line: counts and state on the left, the selection's
  /// actions on the right. Give it to `sys.WindowFooter`.

  interface Props {
    left?: string
    right?: string
    /// After [left]; a `<span class="flex-1">` pushes the rest right.
    children?: Snippet
    class?: string
  }

  const { left, right, children, class: className = '' }: Props = $props()
</script>

<div class="lk-statusbar {className}">
  {#if left}<span class="truncate">{left}</span>{/if}
  {@render children?.()}
  {#if right}<span class="lk-statusbar__spacer"></span><span class="truncate">{right}</span>{/if}
</div>
