<script lang="ts">
  import Icon from '@lollipopkit/desk-ui/Icon.svelte'
  import type { Platform } from '../types'

  interface Props {
    platform: Platform | undefined
    /// In px.
    size?: number
    /// Read out; absent, the icon is decoration.
    title?: string
    class?: string
  }

  // No trademarked logos: a neutral glyph per OS family. Bsd covers macOS,
  // the only Bsd target this monitor ships on.
  const GLYPHS: Record<Platform, string> = { linux: 'terminal', bsd: 'laptop_mac', windows: 'grid_view' }

  const { platform, size = 20, title, class: className }: Props = $props()
</script>

{#if platform}
  <Icon name={GLYPHS[platform]} {size} {title} fill class={className} />
{/if}
