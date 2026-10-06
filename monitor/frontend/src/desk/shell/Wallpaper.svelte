<script lang="ts">
  import type { WallpaperPreset } from '../prefs.svelte'

  interface Props {
    preset: WallpaperPreset | null
    /// The custom image, when [preset] is null.
    url: string | null
    fit: 'cover' | 'contain' | 'fill'
  }

  const { preset, url, fit }: Props = $props()

  /// Layered gradients rather than images: no request, crisp at any size,
  /// and a light and a dark version of each.
  const PRESETS: Record<WallpaperPreset, { light: string; dark: string }> = {
    bloom: {
      light:
        'radial-gradient(at 12% 18%, #f9a8d4 0, transparent 42%), radial-gradient(at 88% 12%, #93c5fd 0, transparent 40%), radial-gradient(at 72% 88%, #c4b5fd 0, transparent 48%), radial-gradient(at 18% 92%, #fde68a 0, transparent 42%), linear-gradient(135deg, #fdf2f8, #eef2ff)',
      dark:
        'radial-gradient(at 12% 18%, #831843 0, transparent 45%), radial-gradient(at 88% 12%, #1e3a8a 0, transparent 42%), radial-gradient(at 72% 88%, #4c1d95 0, transparent 50%), radial-gradient(at 18% 92%, #78350f 0, transparent 40%), linear-gradient(135deg, #0b0b14, #0f172a)',
    },
    dusk: {
      light:
        'radial-gradient(at 20% 15%, #fdba74 0, transparent 45%), radial-gradient(at 80% 25%, #f0abfc 0, transparent 42%), radial-gradient(at 50% 95%, #a78bfa 0, transparent 55%), linear-gradient(180deg, #fff7ed, #f5f3ff)',
      dark:
        'radial-gradient(at 20% 15%, #9a3412 0, transparent 45%), radial-gradient(at 80% 25%, #86198f 0, transparent 42%), radial-gradient(at 50% 95%, #3b0764 0, transparent 55%), linear-gradient(180deg, #1c0f0a, #0c0618)',
    },
    nightfall: {
      light:
        'radial-gradient(at 15% 80%, #5eead4 0, transparent 45%), radial-gradient(at 85% 20%, #7dd3fc 0, transparent 45%), radial-gradient(at 50% 40%, #a5b4fc 0, transparent 50%), linear-gradient(160deg, #ecfeff, #eef2ff)',
      dark:
        'radial-gradient(at 15% 80%, #134e4a 0, transparent 45%), radial-gradient(at 85% 20%, #0c4a6e 0, transparent 45%), radial-gradient(at 50% 40%, #1e1b4b 0, transparent 55%), linear-gradient(160deg, #020617, #0a0f1e)',
    },
    graphite: {
      light:
        'radial-gradient(at 25% 25%, #e5e7eb 0, transparent 50%), radial-gradient(at 75% 75%, #d4d4d8 0, transparent 50%), linear-gradient(135deg, #f5f5f5, #e4e4e7)',
      dark:
        'radial-gradient(at 25% 25%, #27272a 0, transparent 50%), radial-gradient(at 75% 75%, #3f3f46 0, transparent 55%), linear-gradient(135deg, #09090b, #18181b)',
    },
  }

  const size = $derived(fit === 'fill' ? '100% 100%' : fit)
</script>

{#if preset}
  {#key preset}
    <div class="desk-wall-light absolute inset-0" style:background={PRESETS[preset].light}></div>
    <div class="desk-wall-dark absolute inset-0" style:background={PRESETS[preset].dark}></div>
  {/key}
{:else if url}
  <div
    class="absolute inset-0 bg-center bg-no-repeat"
    style:background-image="url({url})"
    style:background-size={size}
    style:background-color="#111"
  ></div>
{:else}
  <div class="absolute inset-0" style:background={PRESETS.bloom.light}></div>
{/if}
