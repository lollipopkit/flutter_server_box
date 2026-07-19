<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLButtonAttributes } from 'svelte/elements'
  import { cn } from './utils.js'

  interface Props {
    label: string
    class?: string
    children: Snippet
  }

  const {
    label,
    class: className,
    children,
    ...rest
  }: Props & Omit<HTMLButtonAttributes, 'class'> = $props()
</script>

<button
  type="button"
  title={label}
  aria-label={label}
  class={cn(
    'inline-flex items-center gap-1 p-2 rounded-lg text-muted-fg cursor-pointer transition-colors hover:text-fg hover:bg-soft focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring',
    className,
  )}
  {...rest}
>
  {@render children()}
</button>
