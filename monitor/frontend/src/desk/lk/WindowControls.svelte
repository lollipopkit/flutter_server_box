<script lang="ts">
  import Icon from './Icon.svelte'

  /// Close, minimise, zoom — macOS order and meaning, in three berry tones
  /// from deep to light (never red, yellow, green); grey while the window is
  /// not in front, until hovered; glyphs on hover. Zoom shows whether the
  /// window is zoomed. A missing handler leaves its button out.

  interface Props {
    inactive?: boolean
    zoomed?: boolean
    onclose?: () => void
    onminimize?: () => void
    onzoom?: () => void
    labels: { close: string; minimize: string; zoom: string; restore: string }
    class?: string
  }

  const { inactive = false, zoomed = false, onclose, onminimize, onzoom, labels, class: className = '' }: Props = $props()
</script>

{#snippet button(kind: string, glyph: string, label: string, run: () => void)}
  <button
    type="button"
    aria-label={label}
    title={label}
    class="lk-winctl__b lk-winctl__b--{kind}"
    onpointerdown={(e) => e.stopPropagation()}
    ondblclick={(e) => e.stopPropagation()}
    onclick={(e) => {
      e.stopPropagation()
      run()
    }}
  >
    <Icon name={glyph} size={kind === 'zoom' ? 9 : 10} weight={700} />
  </button>
{/snippet}

<div class="lk-winctl {className}" class:lk-winctl--inactive={inactive}>
  {#if onclose}{@render button('close', 'close', labels.close, onclose)}{/if}
  {#if onminimize}{@render button('min', 'remove', labels.minimize, onminimize)}{/if}
  {#if onzoom}{@render button('zoom', zoomed ? 'fullscreen_exit' : 'fullscreen', zoomed ? labels.restore : labels.zoom, onzoom)}{/if}
</div>
