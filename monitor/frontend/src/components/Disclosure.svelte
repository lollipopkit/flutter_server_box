<script lang="ts">
  import type { Snippet } from 'svelte'
  import Icon from '../desk/lk/Icon.svelte'

  interface Props {
    summary: string
    children: Snippet
    /// Collapsed by default — these are reference notes, not primary content
    open?: boolean
  }

  let { summary, children, open = false }: Props = $props()
</script>

<details bind:open class="disclosure">
  <summary>
    <Icon name="chevron_right" size={16} class="disclosure-chevron" />
    {summary}
  </summary>
  <div class="mt-[7px]">
    {@render children()}
  </div>
</details>

<style>
  summary {
    display: flex;
    align-items: center;
    gap: var(--space-5);
    width: fit-content;
    border-radius: var(--radius-xs);
    font-size: var(--text-12);
    font-weight: var(--weight-medium);
    color: var(--text-tertiary);
    cursor: default;
    user-select: none;
    list-style: none;
    transition: color var(--dur-fast);
  }
  summary::-webkit-details-marker {
    display: none;
  }
  summary:hover {
    color: var(--text-secondary);
  }
  summary:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
  summary :global(.disclosure-chevron) {
    transition: transform var(--dur-slow) var(--ease-spring);
  }
  .disclosure[open] summary :global(.disclosure-chevron) {
    transform: rotate(90deg);
  }
</style>
