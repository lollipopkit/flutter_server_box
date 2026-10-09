<script lang="ts">
  /// A chart series' key that turns the series on and off: its colour as a
  /// dot (a ring when off), its name and its latest value.

  interface Props {
    label: string
    value?: string
    color?: string
    on?: boolean
    onclick?: () => void
    class?: string
  }

  const { label, value, color = 'var(--color-accent)', on = true, onclick, class: className = '' }: Props = $props()
</script>

<button type="button" aria-pressed={on} class="lk-legend {className}" class:lk-legend--on={on} {onclick}>
  <span class="lk-legend__dot" style:background={on ? color : 'transparent'} style:box-shadow="inset 0 0 0 1.5px {color}"></span>
  {label}
  {#if value != null}<span class="lk-legend__val">{value}</span>{/if}
</button>

<style>
  .lk-legend:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
