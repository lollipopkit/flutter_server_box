<script lang="ts">
  import Icon from './Icon.svelte'

  /// Close, minimise, zoom — macOS order and meaning. Grey while the window
  /// is not in front, until hovered. A missing handler leaves its light out.

  interface Props {
    inactive?: boolean
    onclose?: () => void
    onminimize?: () => void
    onzoom?: () => void
    labels: { close: string; minimize: string; zoom: string }
    class?: string
  }

  const { inactive = false, onclose, onminimize, onzoom, labels, class: className = '' }: Props = $props()
</script>

{#snippet light(kind: string, glyph: string, label: string, run: () => void)}
  <button
    type="button"
    aria-label={label}
    title={label}
    class="lk-lights__b lk-lights__b--{kind}"
    onpointerdown={(e) => e.stopPropagation()}
    onclick={(e) => {
      e.stopPropagation()
      run()
    }}
  >
    <Icon name={glyph} size={10} weight={700} />
  </button>
{/snippet}

<div class="lk-lights {className}" class:lk-lights--inactive={inactive}>
  {#if onclose}{@render light('close', 'close', labels.close, onclose)}{/if}
  {#if onminimize}{@render light('min', 'remove', labels.minimize, onminimize)}{/if}
  {#if onzoom}{@render light('zoom', 'open_in_full', labels.zoom, onzoom)}{/if}
</div>
