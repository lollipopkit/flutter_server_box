<script lang="ts" module>
  import type { WallpaperPreset } from '../prefs.svelte'

  /// Calm single-hue fields, as the design system's placeholder wallpapers
  /// are; never a rainbow. `bloom` is the design system's own pair (berry by
  /// day, dusk by night); the others are the same blend in other hues.
  const PRESETS: Record<WallpaperPreset, { light: string; dark: string }> = {
    bloom: { light: 'var(--wallpaper-berry)', dark: 'var(--wallpaper-dusk)' },
    dusk: {
      light:
        'radial-gradient(120% 90% at 15% 10%, #ffe6d6 0%, transparent 55%), radial-gradient(90% 80% at 90% 20%, #f6d2c0 0%, transparent 60%), radial-gradient(110% 90% at 60% 110%, #c8693f 0%, transparent 60%), linear-gradient(160deg, #f9ebe2 0%, #ecc3ad 55%, #9a4a25 120%)',
      dark: 'radial-gradient(120% 90% at 20% 0%, #5c2a12 0%, transparent 55%), radial-gradient(90% 90% at 100% 100%, #7a3a17 0%, transparent 60%), linear-gradient(160deg, #211b18 0%, #2a1106 100%)',
    },
    nightfall: {
      light:
        'radial-gradient(120% 90% at 15% 10%, #dde7ff 0%, transparent 55%), radial-gradient(90% 80% at 90% 20%, #c9d6f2 0%, transparent 60%), radial-gradient(110% 90% at 60% 110%, #3d5fa8 0%, transparent 60%), linear-gradient(160deg, #e6ecf7 0%, #b8c8e6 55%, #233f80 120%)',
      dark: 'radial-gradient(120% 90% at 20% 0%, #102a5c 0%, transparent 55%), radial-gradient(90% 90% at 100% 100%, #17357a 0%, transparent 60%), linear-gradient(160deg, #1a1c21 0%, #060f2a 100%)',
    },
    graphite: {
      light:
        'radial-gradient(120% 90% at 15% 10%, #f3eef0 0%, transparent 55%), radial-gradient(90% 80% at 90% 20%, #e2d9dc 0%, transparent 60%), radial-gradient(110% 90% at 60% 110%, #7b7074 0%, transparent 60%), linear-gradient(160deg, #efe7ea 0%, #c8bec1 55%, #4a4144 120%)',
      dark: 'radial-gradient(120% 90% at 20% 0%, #362f31 0%, transparent 55%), radial-gradient(90% 90% at 100% 100%, #2b2527 0%, transparent 60%), linear-gradient(160deg, #1c1719 0%, #0e0a0c 100%)',
    },
  }
</script>

<script lang="ts">
  import type { ThemeWallpaper } from '../themeStyle'

  interface Props {
    preset: WallpaperPreset | null
    /// The custom image, when [preset] is null.
    url: string | null
    fit: 'cover' | 'contain' | 'fill'
    /// A theme's background, which wins over both (`themeStyle`).
    theme?: ThemeWallpaper | null
  }

  const { preset, url, fit, theme = null }: Props = $props()
  const size = $derived(fit === 'fill' ? '100% 100%' : fit)
</script>

{#if theme}
  <!-- As the app draws a theme's background: its ground, and the image over
       it, faint, blurred, repeated from the top left or cover-fitted. -->
  <div class="absolute inset-0" style:background={theme.ground}></div>
  {#if theme.image}
    <div
      class="absolute inset-0"
      style:background-image="url({theme.image.url})"
      style:background-repeat={theme.image.tile > 0 ? 'repeat' : 'no-repeat'}
      style:background-size={theme.image.tile > 0 ? `${theme.image.tile}px auto` : 'cover'}
      style:background-position={theme.image.tile > 0 ? 'top left' : 'center'}
      style:opacity={theme.image.opacity}
      style:filter={theme.image.blur > 0 ? `blur(${theme.image.blur}px)` : null}
    ></div>
  {/if}
{:else if preset}
  {#key preset}
    <div class="desk-wall-light absolute inset-0" style:background={PRESETS[preset].light}></div>
    <div class="desk-wall-dark absolute inset-0" style:background={PRESETS[preset].dark}></div>
  {/key}
{:else if url}
  <div
    class="absolute inset-0 bg-center bg-no-repeat"
    style:background-image="url({url})"
    style:background-size={size}
    style:background-color="var(--surface-desktop)"
  ></div>
{:else}
  <div class="absolute inset-0" style:background="var(--wallpaper)"></div>
{/if}
