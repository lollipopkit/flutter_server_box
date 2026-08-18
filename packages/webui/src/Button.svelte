<script lang="ts" module>
  import { tv, type VariantProps } from 'tailwind-variants'

  export const button = tv({
    base: 'inline-flex items-center justify-center font-body font-medium rounded-full no-underline cursor-pointer transition-opacity duration-200 hover:opacity-85 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring disabled:opacity-50 disabled:cursor-not-allowed',
    variants: {
      variant: {
        primary: 'bg-fg-strong text-surface',
        secondary: 'bg-soft text-fg',
        danger: 'bg-danger text-white',
        ghost: 'bg-transparent text-muted-fg hover:opacity-100 hover:text-fg hover:bg-soft',
      },
      size: {
        sm: 'px-3 py-1.5 text-sm',
        md: 'px-6 py-2.5 text-[0.95rem]',
      },
      block: {
        true: 'w-full',
      },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  })

  export type ButtonVariant = VariantProps<typeof button>['variant']
  export type ButtonSize = VariantProps<typeof button>['size']
</script>

<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLAnchorAttributes, HTMLButtonAttributes } from 'svelte/elements'

  interface Props {
    variant?: ButtonVariant
    size?: ButtonSize
    block?: boolean
    /// Renders an anchor instead of a button
    href?: string
    class?: string
    children: Snippet
  }

  const {
    variant = 'primary',
    size = 'md',
    block = false,
    href,
    class: className,
    children,
    ...rest
  }: Props & Omit<HTMLAnchorAttributes & HTMLButtonAttributes, 'class' | 'href'> = $props()

  const classes = $derived(button({ variant, size, block, class: className }))
</script>

{#if href}
  <a {href} class={classes} {...rest as HTMLAnchorAttributes}>{@render children()}</a>
{:else}
  <button class={classes} {...rest as HTMLButtonAttributes}>{@render children()}</button>
{/if}
