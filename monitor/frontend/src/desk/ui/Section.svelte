<script lang="ts">
  import type { Snippet } from 'svelte'

  /// TODO: remove once every app uses `lk/Card` — a compatibility shim.

  interface Props {
    title?: string
    count?: number
    actions?: Snippet
    class?: string
    children: Snippet
  }

  const { title, count, actions, class: className = '', children }: Props = $props()
</script>

<section class="lk-card {className}">
  {#if title || actions}
    <div class="lk-card__head">
      <div class="lk-card__title">{title}</div>
      {@render actions?.()}
      {#if count !== undefined}<span class="lk-badge lk-badge--neutral">{count}</span>{/if}
    </div>
  {/if}
  {@render children()}
</section>
