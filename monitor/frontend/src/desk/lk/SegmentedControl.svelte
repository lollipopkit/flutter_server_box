<script lang="ts" generics="T extends string">
  import Icon from './Icon.svelte'

  /// A few views or values side by side; the chosen one sits on a raised
  /// thumb that glides between them (never an inverted fill).

  interface Option {
    value: T
    label?: string
    icon?: string
    /// The accessible name when there is no visible [label].
    title?: string
    /// This one cannot be chosen.
    disabled?: boolean
  }

  interface Props {
    options: Option[]
    value: T
    onchange: (value: T) => void
    size?: 'sm' | 'md'
    block?: boolean
    /// Names the group for a screen reader.
    label?: string
    /// Shows [value] without letting it change.
    disabled?: boolean
    class?: string
  }

  const { options, value, onchange, size = 'md', block = false, label, disabled = false, class: className = '' }: Props = $props()
  const at = $derived(Math.max(0, options.findIndex((o) => o.value === value)))
</script>

<div
  role="tablist"
  aria-label={label}
  aria-disabled={disabled || undefined}
  class="lk-seg {size === 'sm' ? 'lk-seg--sm' : ''} {block ? 'lk-seg--block' : ''} {disabled ? 'lk-seg--disabled' : ''} {className}"
>
  <span
    class="lk-seg__thumb"
    style:width="calc((100% - 4px) / {options.length})"
    style:transform="translateX({at * 100}%)"
  ></span>
  {#each options as o (o.value)}
    <button
      type="button"
      role="tab"
      aria-selected={o.value === value}
      aria-label={o.label ? undefined : o.title}
      title={o.label ? undefined : o.title}
      class="lk-seg__item"
      class:lk-seg__item--on={o.value === value}
      disabled={disabled || o.disabled}
      onclick={() => onchange(o.value)}
    >
      {#if o.icon}<Icon name={o.icon} size={size === 'sm' ? 14 : 16} />{/if}{o.label ?? ''}
    </button>
  {/each}
</div>
