<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLSelectAttributes } from 'svelte/elements'
  import { cn } from './utils.js'

  interface Props {
    value?: string
    class?: string
    children: Snippet
  }

  let {
    value = $bindable(''),
    class: className,
    children,
    ...rest
  }: Props & Omit<HTMLSelectAttributes, 'class' | 'value'> = $props()
</script>

<div class={cn('relative inline-flex', className)}>
  <!-- appearance-none + custom chevron keeps horizontal padding symmetric -->
  <select
    bind:value
    class="appearance-none w-full pl-3 pr-9 py-2 rounded-lg border border-line bg-surface text-fg truncate cursor-pointer focus:outline-hidden focus:ring-2 focus:ring-ring focus:border-transparent"
    {...rest}
  >
    {@render children()}
  </select>
  <svg
    class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-fg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path d="m6 9 6 6 6-6" />
  </svg>
</div>
