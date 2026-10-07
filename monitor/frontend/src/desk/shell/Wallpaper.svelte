<script lang="ts" module>
  import type { WallpaperPreset } from '../prefs.svelte'

  /// One version of a preset: a ground, three soft blooms of colour and two
  /// low hills along the bottom.
  interface Scene {
    ground: string
    blooms: [string, number][]
    hills: [string, string]
  }

  const SCENES: Record<WallpaperPreset, { light: Scene; dark: Scene }> = {
    bloom: {
      light: { ground: '#f6eef5', blooms: [['#d4729b', 0.42], ['#f3b4cc', 0.55], ['#f0d8e4', 0.9]], hills: ['#f1e0e9', '#e9d3de'] },
      dark: { ground: '#170b12', blooms: [['#7a1f4a', 0.6], ['#8b2252', 0.35], ['#2a1220', 0.9]], hills: ['#1d0e17', '#240f1c'] },
    },
    dusk: {
      light: { ground: '#f7f0ea', blooms: [['#e8a36c', 0.38], ['#f2c7a8', 0.5], ['#efe0d4', 0.9]], hills: ['#f1e5db', '#ead9cb'] },
      dark: { ground: '#140d09', blooms: [['#7a3b14', 0.55], ['#4a2410', 0.5], ['#22150d', 0.9]], hills: ['#1a110b', '#21150e'] },
    },
    nightfall: {
      light: { ground: '#edf2f8', blooms: [['#7aa7d9', 0.38], ['#a9c8ea', 0.5], ['#dde8f4', 0.9]], hills: ['#e3ebf5', '#d9e4f1'] },
      dark: { ground: '#070b14', blooms: [['#1b3a6b', 0.6], ['#123257', 0.45], ['#0d1626', 0.9]], hills: ['#0b111d', '#0e1524'] },
    },
    graphite: {
      light: { ground: '#f1f1f3', blooms: [['#c9c9cf', 0.45], ['#dcdce0', 0.55], ['#e9e9ec', 0.9]], hills: ['#e8e8eb', '#e0e0e4'] },
      dark: { ground: '#0b0b0c', blooms: [['#2b2b30', 0.6], ['#222226', 0.5], ['#141416', 0.9]], hills: ['#121214', '#161618'] },
    },
  }

  /// Where the blooms sit and how large they are, on a 1600×900 canvas.
  const BLOOMS = [
    [320, 180, 260],
    [1320, 220, 280],
    [900, 780, 360],
  ]

  /// A scene as an SVG image: drawn by the browser, no request, crisp at any
  /// size.
  function image(scene: Scene): string {
    const blooms = scene.blooms
      .map(([fill, opacity], i) => {
        const [cx, cy, r] = BLOOMS[i]
        return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" fill-opacity="${opacity}"/>`
      })
      .join('')
    const svg =
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMid slice">` +
      `<defs><filter id="b" x="-20%" y="-30%" width="140%" height="160%"><feGaussianBlur stdDeviation="120"/></filter></defs>` +
      `<rect width="1600" height="900" fill="${scene.ground}"/>` +
      `<g filter="url(#b)">${blooms}</g>` +
      `<g opacity="0.72">` +
      `<path d="M0 690C190 610 310 570 480 570C700 570 820 715 1040 715C1250 715 1370 610 1600 505V900H0Z" fill="${scene.hills[0]}"/>` +
      `<path d="M0 775C170 715 270 685 430 685C630 685 790 815 990 815C1200 815 1370 750 1600 655V900H0Z" fill="${scene.hills[1]}"/>` +
      `</g></svg>`
    return `url("data:image/svg+xml,${encodeURIComponent(svg)}")`
  }

  const IMAGES = Object.fromEntries(
    Object.entries(SCENES).map(([id, s]) => [id, { light: image(s.light), dark: image(s.dark) }]),
  ) as Record<WallpaperPreset, { light: string; dark: string }>
</script>

<script lang="ts">
  interface Props {
    preset: WallpaperPreset | null
    /// The custom image, when [preset] is null.
    url: string | null
    fit: 'cover' | 'contain' | 'fill'
  }

  const { preset, url, fit }: Props = $props()
  const size = $derived(fit === 'fill' ? '100% 100%' : fit)
</script>

{#if preset}
  {#key preset}
    <div class="desk-wall-light absolute inset-0 bg-cover bg-center" style:background-image={IMAGES[preset].light}></div>
    <div class="desk-wall-dark absolute inset-0 bg-cover bg-center" style:background-image={IMAGES[preset].dark}></div>
  {/key}
{:else if url}
  <div
    class="absolute inset-0 bg-center bg-no-repeat"
    style:background-image="url({url})"
    style:background-size={size}
    style:background-color="#111"
  ></div>
{:else}
  <div class="absolute inset-0 bg-cover bg-center" style:background-image={IMAGES.bloom.light}></div>
{/if}
