<script lang="ts">
  import Icon from './Icon.svelte'

  /// One reading at a glance: a label with its glyph, the figure, a line
  /// under it and a thin bar for a share. With [onclick] it leads somewhere
  /// (a chevron says so).

  interface Props {
    label: string
    value: string
    icon?: string
    sub?: string
    /// 0–100; no bar when absent.
    percent?: number
    /// The glyph's and the bar's colour.
    color?: string
    /// Where it leads, as a tooltip.
    title?: string
    onclick?: () => void
    class?: string
  }

  const { label, value, icon, sub, percent, color = 'var(--color-accent)', title, onclick, class: className = '' }: Props = $props()
  const width = $derived(percent == null ? 0 : percent > 0 ? Math.max(1, Math.min(100, percent)) : 0)
</script>

{#snippet body()}
  <span class="lk-stat__head">
    {#if icon}<Icon name={icon} size={15} {color} />{/if}{label}<span class="lk-stat__spacer"></span>
    {#if onclick}<Icon name="chevron_right" size={15} color="var(--text-tertiary)" />{/if}
  </span>
  <span class="lk-stat__value lk-num">{value}</span>
  {#if sub}<span class="lk-stat__sub">{sub}</span>{/if}
  {#if percent != null}
    <span class="lk-stat__track"><span class="lk-stat__fill" style:width="{width}%" style:background={color}></span></span>
  {/if}
{/snippet}

{#if onclick}
  <button type="button" class="lk-stat lk-stat--interactive {className}" {title} {onclick}>{@render body()}</button>
{:else}
  <div class="lk-stat {className}" {title}>{@render body()}</div>
{/if}

<style>
  .lk-stat {
    font: inherit;
    color: inherit;
  }
  .lk-stat:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
