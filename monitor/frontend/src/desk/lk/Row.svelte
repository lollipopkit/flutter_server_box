<script lang="ts">
  import type { Snippet } from 'svelte'
  import Icon from './Icon.svelte'

  /// One line of a `Group`: a label (and a hint under it) on the left, its
  /// control or value on the right; a hairline between rows.

  interface Props {
    label: string
    sub?: string
    /// A read-only value at the right, instead of a control.
    value?: string
    /// The value is a key, a path, an address: monospace.
    mono?: boolean
    /// Before the label (an app icon).
    leading?: Snippet
    /// The control.
    children?: Snippet
    /// The row leads to a page of its own: the whole row is the button, with
    /// a chevron at the end, as a list of things to open in System Settings.
    onclick?: () => void
    class?: string
  }

  const { label, sub, value, mono = false, leading, children, onclick, class: className = '' }: Props = $props()
</script>

{#snippet body()}
  {@render leading?.()}
  <div class="lk-setrow__text">
    <span class="lk-setrow__label">{label}</span>
    {#if sub}<span class="lk-setrow__hint">{sub}</span>{/if}
  </div>
  {#if value != null}<span class="lk-setrow__value" class:lk-mono={mono}>{value}</span>{/if}
  {@render children?.()}
{/snippet}

{#if onclick}
  <button type="button" class="lk-setrow lk-setrow--link {className}" {onclick}>
    {@render body()}
    <Icon name="chevron_right" size={17} color="var(--text-tertiary)" />
  </button>
{:else}
  <div class="lk-setrow {className}">{@render body()}</div>
{/if}

<style>
  /* To the card's edges, so the hover is the whole row. */
  .lk-setrow--link {
    width: calc(100% + 26px);
    margin: 0 -13px;
    padding-inline: 13px;
    border: 0;
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: default;
    transition: background-color var(--dur-fast);
  }
  .lk-setrow--link:hover {
    background: var(--fill-hover);
  }
  .lk-setrow--link:focus-visible {
    outline: none;
    box-shadow: inset var(--focus-ring);
  }
</style>
