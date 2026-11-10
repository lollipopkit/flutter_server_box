<script lang="ts">
  /// A Material Symbols Rounded glyph by name (`folder`, `terminal`). Outline
  /// by default; `fill` for a selected or on state.

  interface Props {
    name: string
    size?: number
    fill?: boolean
    weight?: number
    color?: string
    /// Read out instead of hidden.
    title?: string
    class?: string
  }

  const { name, size = 18, fill = false, weight = 400, color, title, class: className = '' }: Props = $props()
  const settings = $derived(
    `"FILL" ${fill ? 1 : 0}, "wght" ${weight}, "GRAD" 0, "opsz" ${Math.min(48, Math.max(20, size))}`,
  )
</script>

<!-- The glyph name is drawn by CSS (`::before`, where the font's ligature
     turns it into the symbol), so it never becomes part of the text of the
     button or label around it. -->
<span
  class="lk-icon {className}"
  data-icon={name}
  aria-hidden={title ? undefined : true}
  role={title ? 'img' : undefined}
  aria-label={title}
  {title}
  style:font-size="{size}px"
  style:width="{size}px"
  style:height="{size}px"
  style:color
  style:font-variation-settings={settings}
></span>

