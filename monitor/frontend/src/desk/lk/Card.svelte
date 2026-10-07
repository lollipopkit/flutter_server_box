<script lang="ts">
  import type { Snippet } from 'svelte'
  import Icon from './Icon.svelte'

  /// Flat: a tinted ground, no border, no shadow. raised: white with a
  /// hairline, for a card on a tinted ground or inside a card. glass: on the
  /// wallpaper. With [onclick] it is a button that springs on press.

  interface Props {
    variant?: 'flat' | 'raised' | 'glass'
    title?: string
    /// A glyph before the title, in the accent.
    icon?: string
    /// At the title's right.
    action?: Snippet
    selected?: boolean
    onclick?: (e: MouseEvent) => void
    /// Overrides the default 13px 17px.
    padding?: string
    class?: string
    children?: Snippet
  }

  const {
    variant = 'flat',
    title,
    icon,
    action,
    selected = false,
    onclick,
    padding,
    class: className = '',
    children,
  }: Props = $props()
  const classes = $derived(
    `lk-card ${variant !== 'flat' ? `lk-card--${variant}` : ''} ${onclick ? 'lk-card--interactive' : ''} ${selected ? 'lk-card--selected' : ''} ${className}`,
  )
</script>

{#snippet body()}
  {#if title || icon || action}
    <div class="lk-card__head">
      {#if icon}<Icon name={icon} size={18} color="var(--color-accent-text)" />{/if}
      {#if title}<div class="lk-card__title">{title}</div>{/if}
      {@render action?.()}
    </div>
  {/if}
  {@render children?.()}
{/snippet}

{#if onclick}
  <button type="button" class="{classes} block w-full text-left" style:padding aria-pressed={selected} {onclick}>
    {@render body()}
  </button>
{:else}
  <div class={classes} style:padding>{@render body()}</div>
{/if}
