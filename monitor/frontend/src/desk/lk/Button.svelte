<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLButtonAttributes } from 'svelte/elements'
  import Icon from './Icon.svelte'

  /// primary: the one main action (accent). secondary: the default, raised
  /// white. tinted: soft accent. ghost: no fill until hovered. destructive.

  interface Props extends Omit<HTMLButtonAttributes, 'class'> {
    variant?: 'primary' | 'secondary' | 'tinted' | 'ghost' | 'destructive'
    size?: 'sm' | 'md' | 'lg'
    icon?: string
    iconRight?: string
    block?: boolean
    class?: string
    children?: Snippet
  }

  const {
    variant = 'secondary',
    size = 'md',
    icon,
    iconRight,
    block = false,
    type = 'button',
    class: className = '',
    children,
    ...rest
  }: Props = $props()
  const glyph = $derived(size === 'sm' ? 14 : size === 'lg' ? 18 : 16)
</script>

<button
  {type}
  class="lk-btn lk-btn--{variant} {size !== 'md' ? `lk-btn--${size}` : ''} {block ? 'lk-btn--block' : ''} {className}"
  {...rest}
>
  {#if icon}<Icon name={icon} size={glyph} />{/if}
  {@render children?.()}
  {#if iconRight}<Icon name={iconRight} size={glyph} />{/if}
</button>
