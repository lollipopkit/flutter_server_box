<script lang="ts" generics="T extends string | number">
  import type { HTMLSelectAttributes } from 'svelte/elements'
  import Icon from './Icon.svelte'

  /// A native select in the design's frame: raised, an accent chevron box.

  interface Option {
    value: T
    label: string
    disabled?: boolean
  }

  interface Props extends Omit<HTMLSelectAttributes, 'class' | 'value'> {
    value?: T
    options: Option[]
    label?: string
    class?: string
  }

  let { value = $bindable(), options, label, disabled = false, class: className = '', ...rest }: Props = $props()
</script>

<label class="lk-field {className}">
  {#if label}<span class="lk-field__label">{label}</span>{/if}
  <span class="lk-select" class:lk-select--disabled={disabled}>
    <select bind:value {disabled} {...rest}>
      {#each options as o (o.value)}
        <option value={o.value} disabled={o.disabled}>{o.label}</option>
      {/each}
    </select>
    <span class="lk-select__chev"><Icon name="unfold_more" size={15} weight={600} /></span>
  </span>
</label>
