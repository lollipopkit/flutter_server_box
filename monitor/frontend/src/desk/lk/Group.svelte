<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A settings group: a caps title over a flat card of `Row`s.

  interface Props {
    title?: string
    class?: string
    children: Snippet
  }

  const { title, class: className = '', children }: Props = $props()
</script>

<section class="lk-setgroup {className}">
  {#if title}<h3 class="lk-setgroup__title">{title}</h3>{/if}
  <div class="lk-setgroup__card">{@render children()}</div>
</section>
