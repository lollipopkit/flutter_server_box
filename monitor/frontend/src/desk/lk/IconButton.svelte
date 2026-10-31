<script lang="ts">
  import type { HTMLButtonAttributes } from 'svelte/elements'
  import Icon from './Icon.svelte'

  /// A glyph-only button; [label] is its accessible name and tooltip.

  interface Props extends Omit<HTMLButtonAttributes, 'class'> {
    icon: string
    label: string
    size?: 'sm' | 'md' | 'lg'
    variant?: 'plain' | 'filled' | 'glass'
    /// On (a toggle that is on, the current view): soft accent, filled glyph.
    active?: boolean
    /// Fills the glyph regardless of [active].
    iconFill?: boolean
    class?: string
  }

  const {
    icon,
    label,
    size = 'md',
    variant = 'plain',
    active = false,
    iconFill,
    class: className = '',
    ...rest
  }: Props = $props()
  const glyph = $derived(size === 'sm' ? 16 : size === 'lg' ? 20 : 18)
</script>

<button
  type="button"
  aria-label={label}
  title={label}
  aria-pressed={active || undefined}
  class="lk-iconbtn {size !== 'md' ? `lk-iconbtn--${size}` : ''} {variant !== 'plain' ? `lk-iconbtn--${variant}` : ''} {active
    ? 'lk-iconbtn--active'
    : ''} {className}"
  {...rest}
>
  <Icon name={icon} size={glyph} fill={iconFill ?? active} />
</button>
