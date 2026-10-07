<script lang="ts">
  import type { Snippet } from 'svelte'

  /// One line of a `Group`: a label (and a hint under it) on the left, its
  /// control or value on the right; a hairline between rows.

  interface Props {
    label: string
    sub?: string
    /// A read-only value at the right, instead of a control.
    value?: string
    /// The value is a key, a path, an address: monospace.
    mono?: boolean
    /// Before the label (an app icon).
    leading?: Snippet
    /// The control.
    children?: Snippet
    class?: string
  }

  const { label, sub, value, mono = false, leading, children, class: className = '' }: Props = $props()
</script>

<div class="lk-setrow {className}">
  {@render leading?.()}
  <div class="lk-setrow__text">
    <span class="lk-setrow__label">{label}</span>
    {#if sub}<span class="lk-setrow__hint">{sub}</span>{/if}
  </div>
  {#if value != null}<span class="lk-setrow__value" class:lk-mono={mono}>{value}</span>{/if}
  {@render children?.()}
</div>
