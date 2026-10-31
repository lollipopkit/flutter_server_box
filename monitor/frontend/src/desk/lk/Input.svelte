<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLInputAttributes } from 'svelte/elements'
  import Icon from './Icon.svelte'

  /// A text field: an optional label above, a hint or an error under it.

  interface Props extends Omit<HTMLInputAttributes, 'class' | 'value' | 'size'> {
    value?: string | number | null
    label?: string
    hint?: string
    error?: string
    /// A glyph before the text (`search`).
    icon?: string
    /// After the text, inside the field (a unit, a button).
    trailing?: Snippet
    size?: 'md' | 'lg'
    /// Tinted, borderless (a search on glass).
    filled?: boolean
    mono?: boolean
    class?: string
    /// The input element, for focusing it.
    ref?: HTMLInputElement | null
  }

  let {
    value = $bindable(''),
    label,
    hint,
    error,
    icon,
    trailing,
    size = 'md',
    filled = false,
    mono = false,
    disabled = false,
    class: className = '',
    ref = $bindable(null),
    ...rest
  }: Props = $props()
</script>

<label class="lk-field {className}">
  {#if label}<span class="lk-field__label">{label}</span>{/if}
  <span
    class="lk-input {size === 'lg' ? 'lk-input--lg' : ''} {filled ? 'lk-input--filled' : ''} {error
      ? 'lk-input--error'
      : ''} {disabled ? 'lk-input--disabled' : ''}"
  >
    {#if icon}<Icon name={icon} size={16} />{/if}
    <input bind:this={ref} bind:value {disabled} style:font-family={mono ? 'var(--font-mono)' : undefined} {...rest} />
    {@render trailing?.()}
  </span>
  {#if error || hint}
    <span class="lk-field__hint" class:lk-field__hint--error={!!error}>{error || hint}</span>
  {/if}
</label>
