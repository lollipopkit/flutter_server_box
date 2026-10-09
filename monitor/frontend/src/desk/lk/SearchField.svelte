<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'
  import Icon from './Icon.svelte'

  /// The pill search field of a window's title bar.

  interface Props extends Omit<HTMLInputAttributes, 'class' | 'value' | 'width'> {
    value: string
    /// In px, or any CSS width.
    width?: number | string
    /// The input, for focusing it from a menu (⌘F).
    input?: HTMLInputElement | null
    class?: string
  }

  let { value = $bindable(), width = 220, input = $bindable(null), placeholder, class: className = '', ...rest }: Props = $props()
</script>

<label class="lk-search {className}" style:width={typeof width === 'number' ? `${width}px` : width}>
  <Icon name="search" size={16} />
  <input bind:this={input} bind:value type="search" {placeholder} aria-label={placeholder} {...rest} />
</label>

<style>
  .lk-search input::-webkit-search-cancel-button {
    -webkit-appearance: none;
  }
</style>
