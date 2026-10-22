<script lang="ts">
  import type { Snippet } from 'svelte'

  interface Props {
    label: string
    placement?: 'top' | 'bottom'
    /// Shown now, without hovering.
    show?: boolean
    class?: string
    children: Snippet
  }

  const { label, placement = 'top', show = false, class: className = '', children }: Props = $props()
</script>

<span class="lk-tipwrap {className}">
  {@render children()}
  <span role="tooltip" class="lk-tip lk-tip--{placement}" class:lk-tip--show={show}>{label}</span>
</span>
