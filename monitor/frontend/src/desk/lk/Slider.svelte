<script lang="ts">
  import Icon from './Icon.svelte'

  interface Props {
    value?: number
    min?: number
    max?: number
    step?: number
    label: string
    iconStart?: string
    iconEnd?: string
    /// The tall Control Center track.
    thick?: boolean
    onchange?: (value: number) => void
    class?: string
  }

  let {
    value = $bindable(50),
    min = 0,
    max = 100,
    step = 1,
    label,
    iconStart,
    iconEnd,
    thick = false,
    onchange,
    class: className = '',
  }: Props = $props()
  const pct = $derived(((value - min) / (max - min)) * 100)
</script>

<div class="lk-slider {thick ? 'lk-slider--thick' : ''} {className}">
  {#if iconStart}<Icon name={iconStart} size={16} />{/if}
  <input
    type="range"
    aria-label={label}
    {min}
    {max}
    {step}
    bind:value
    style:--v="{pct}%"
    oninput={() => onchange?.(value)}
  />
  {#if iconEnd}<Icon name={iconEnd} size={16} />{/if}
</div>
