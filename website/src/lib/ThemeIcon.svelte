<script>
  // One of a theme's icons, drawn the way the app draws it: the file as a
  // mask, filled with one color. The app tints with `BlendMode.srcIn`, which
  // keeps each part's opacity, and a mask keeps it the same way.
  let { src = null, color = 'currentColor', size = 22, label = undefined } = $props()
</script>

{#if src}
  <span
    class="theme-icon"
    role={label ? 'img' : undefined}
    aria-label={label}
    aria-hidden={label ? undefined : 'true'}
    style={`--ti-src:url("${src}"); --ti-color:${color}; --ti-size:${size}px;`}
  ></span>
{:else}
  <span class="theme-icon theme-icon-missing" aria-hidden="true" style={`--ti-color:${color}; --ti-size:${size}px;`}></span>
{/if}

<style>
  .theme-icon {
    display: inline-block;
    flex: none;
    width: var(--ti-size);
    height: var(--ti-size);
    background: var(--ti-color);
    -webkit-mask: var(--ti-src) center / contain no-repeat;
    mask: var(--ti-src) center / contain no-repeat;
  }

  /* A key the theme draws no image for: the app shows its built-in glyph,
     which the site does not have, so a neutral dot stands in. */
  .theme-icon-missing {
    -webkit-mask: none;
    mask: none;
    border-radius: 50%;
    transform: scale(0.45);
  }
</style>
