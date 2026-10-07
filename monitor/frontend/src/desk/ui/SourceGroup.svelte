<script lang="ts">
  import type { Component, Snippet } from 'svelte'

  /// TODO: remove once every app uses `lk/SidebarSection` — a compatibility
  /// shim drawing the old props in the design system's sidebar style.

  interface Props {
    title?: string
    icon?: Component
    boxed?: boolean
    children: Snippet
  }

  const { title, children }: Props = $props()
</script>

<div class="lk-side__section">
  {#if title}<div class="lk-side__head">{title}</div>{/if}
  {@render children()}
</div>
