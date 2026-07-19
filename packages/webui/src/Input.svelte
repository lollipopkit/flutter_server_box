<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'
  import { cn } from './utils.js'

  interface Props {
    value?: string
    class?: string
  }

  let {
    value = $bindable(''),
    class: className,
    ...rest
  }: Props & Omit<HTMLInputAttributes, 'class' | 'value'> = $props()
</script>

<input
  bind:value
  class={cn(
    'w-full px-3 py-2 rounded-lg border border-line bg-surface text-fg placeholder:text-faint-fg focus:outline-hidden focus:ring-2 focus:ring-ring focus:border-transparent',
    className,
  )}
  {...rest}
/>
