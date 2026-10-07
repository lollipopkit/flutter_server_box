<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLInputAttributes } from 'svelte/elements'
  import Icon from './Icon.svelte'

  interface Props extends Omit<HTMLInputAttributes, 'class' | 'type' | 'checked'> {
    checked?: boolean
    label?: string
    /// Instead of [label], for richer text.
    children?: Snippet
    class?: string
  }

  let { checked = $bindable(false), label, children, disabled = false, class: className = '', ...rest }: Props = $props()
</script>

<label class="lk-check {className}" class:lk-check--on={checked} class:lk-check--disabled={disabled}>
  <input type="checkbox" bind:checked {disabled} {...rest} />
  <span class="lk-check__box"><Icon name="check" size={14} weight={700} class="lk-check__mark" /></span>
  {#if children}<span>{@render children()}</span>{:else if label}<span>{label}</span>{/if}
</label>
