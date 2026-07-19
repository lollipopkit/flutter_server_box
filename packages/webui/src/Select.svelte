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

<select
  bind:value
  class={cn(
    'px-3 py-2 rounded-lg border border-line bg-surface text-fg focus:outline-hidden focus:ring-2 focus:ring-ring focus:border-transparent',
    className,
  )}
  {...rest}
>
  {@render children()}
</select>
