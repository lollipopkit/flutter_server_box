<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A settings-style group: a caps title over a flat card of `Row`s.

  interface Props {
    title?: string
    class?: string
    children: Snippet
  }

  const { title, class: className = '', children }: Props = $props()
</script>

<section class="mb-[17px] {className}">
  {#if title}<h3 class="lk-caps mb-[7px] ml-[3px]">{title}</h3>{/if}
  <div class="lk-card" style:padding="0 17px">{@render children()}</div>
</section>
