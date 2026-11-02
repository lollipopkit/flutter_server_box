<script lang="ts" generics="T extends string | number">
  import type { HTMLInputAttributes } from 'svelte/elements'

  /// One choice of a group sharing [group] (bound) and [name].

  interface Props extends Omit<HTMLInputAttributes, 'class' | 'type' | 'value'> {
    group?: T
    value: T
    label?: string
    class?: string
  }

  let { group = $bindable(), value, label, disabled = false, class: className = '', ...rest }: Props = $props()
</script>

<label
  class="lk-check lk-check--radio {className}"
  class:lk-check--on={group === value}
  class:lk-check--disabled={disabled}
>
  <input type="radio" bind:group {value} {disabled} {...rest} />
  <span class="lk-check__box"><span class="lk-check__mark lk-check__dot"></span></span>
  {#if label}<span>{label}</span>{/if}
</label>
