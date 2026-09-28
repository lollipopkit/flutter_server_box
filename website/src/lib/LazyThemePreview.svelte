<script>
  // A theme's preview, loaded when it is about to be seen: until then a
  // phone-sized block in the theme's own page color, so the grid does not
  // move when the preview arrives.
  import { onMount } from 'svelte'
  import ThemePreview from './ThemePreview.svelte'
  import { loadPreview } from './previews.js'

  let { theme, mode, scale = 1 } = $props()

  let box
  let preview = $state(null)
  let failed = $state(false)

  onMount(() => {
    const load = () =>
      loadPreview(theme).then(
        (p) => (preview = p),
        () => (failed = true),
      )
    if (!('IntersectionObserver' in window)) {
      load()
      return
    }
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          io.disconnect()
          load()
        }
      },
      { rootMargin: '300px' },
    )
    io.observe(box)
    return () => io.disconnect()
  })

  const ph = $derived(theme.placeholder?.[mode] ?? {})
</script>

<div bind:this={box} class="lazy-preview" style={`--s:${scale}`}>
  {#if preview}
    <ThemePreview {preview} {mode} {scale} />
  {:else}
    <div
      class="lazy-placeholder"
      class:failed
      style={`background:${ph.surface ?? '#888'}; --accent:${ph.primary ?? 'transparent'};`}
      aria-hidden="true"
    ></div>
  {/if}
</div>

<style>
  .lazy-placeholder {
    zoom: var(--s);
    width: 248px;
    height: 470px;
    border-radius: 26px;
    box-shadow: 0 0 0 1px rgba(127, 127, 127, 0.25);
    background-image: linear-gradient(
      110deg,
      transparent 30%,
      color-mix(in srgb, var(--accent) 18%, transparent) 50%,
      transparent 70%
    );
    background-size: 250% 100%;
    animation: shimmer 1.4s linear infinite;
  }

  .lazy-placeholder.failed {
    animation: none;
  }

  @keyframes shimmer {
    from {
      background-position: 120% 0;
    }
    to {
      background-position: -120% 0;
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .lazy-placeholder {
      animation: none;
    }
  }
</style>
