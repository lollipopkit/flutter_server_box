<script lang="ts">
  import type { HTMLButtonAttributes } from 'svelte/elements'

  /// An on/off toggle; [label] is its accessible name (the row shows the text).

  interface Props extends Omit<HTMLButtonAttributes, 'class' | 'onchange'> {
    checked?: boolean
    label: string
    size?: 'sm' | 'md'
    onchange?: (checked: boolean) => void
    class?: string
  }

  let { checked = $bindable(false), label, size = 'md', onchange, class: className = '', ...rest }: Props = $props()
</script>

<button
  type="button"
  role="switch"
  aria-checked={checked}
  aria-label={label}
  class="lk-switch {size === 'sm' ? 'lk-switch--sm' : ''} {className}"
  class:lk-switch--on={checked}
  onclick={() => {
    checked = !checked
    onchange?.(checked)
  }}
  {...rest}
>
  <span class="lk-switch__knob"></span>
</button>
