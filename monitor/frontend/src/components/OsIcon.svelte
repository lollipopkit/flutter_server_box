<script lang="ts">
  import { Apple, Grid2x2, Terminal, type IconProps } from '@lucide/svelte'
  import type { Platform } from '../types'

  interface Props extends IconProps {
    platform: Platform | undefined
  }

  // No trademarked-logo icons in lucide; these are generic stand-ins per OS
  // family — Bsd covers macOS, the only Bsd target this monitor ships on
  const ICONS = { linux: Terminal, bsd: Apple, windows: Grid2x2 }

  const { platform, ...rest }: Props = $props()
  const Icon = $derived(platform ? ICONS[platform] : undefined)
</script>

{#if Icon}
  <Icon {...rest} />
{/if}
