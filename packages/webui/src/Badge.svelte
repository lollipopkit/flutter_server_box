<script lang="ts" module>
  import { tv, type VariantProps } from 'tailwind-variants'

  export const badge = tv({
    base: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium',
    variants: {
      tone: {
        neutral: 'bg-soft text-muted-fg',
        success: 'bg-success/10 text-success',
        warning: 'bg-warning/10 text-warning',
        danger: 'bg-danger/10 text-danger',
      },
    },
    defaultVariants: { tone: 'neutral' },
  })

  export type BadgeTone = VariantProps<typeof badge>['tone']
</script>

<script lang="ts">
  import type { Snippet } from 'svelte'

  interface Props {
    tone?: BadgeTone
    class?: string
    children: Snippet
  }

  const { tone = 'neutral', class: className, children }: Props = $props()
</script>

<span class={badge({ tone, class: className })}>{@render children()}</span>
