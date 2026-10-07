<script lang="ts">
  import type { Snippet } from 'svelte'

  /// One line of a `Group`: a label (and a smaller line under it) on the
  /// left, its control on the right; a hairline between rows.

  interface Props {
    label: string
    sub?: string
    /// The control.
    children?: Snippet
    class?: string
  }

  const { label, sub, children, class: className = '' }: Props = $props()
</script>

<div class="lk-row {className}">
  <div class="min-w-0 flex-1">
    <div class="text-[13px]">{label}</div>
    {#if sub}<div class="text-[12px] text-(--text-tertiary)">{sub}</div>{/if}
  </div>
  {@render children?.()}
</div>

<style>
  .lk-row {
    display: flex;
    align-items: center;
    gap: var(--space-13);
    min-height: 44px;
    padding: var(--space-7) 0;
    border-bottom: 0.5px solid var(--border-hairline);
  }
  .lk-row:last-child {
    border-bottom: 0;
  }
</style>
