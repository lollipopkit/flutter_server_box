<script lang="ts" module>
  /// The icon tones: berry-palette tones for the system's own apps, soft
  /// hues for the rest.
  export type IconTone =
    | 'berry'
    | 'soft'
    | 'bright'
    | 'pale'
    | 'mist'
    | 'ink'
    | 'sky'
    | 'violet'
    | 'teal'
    | 'leaf'
    | 'amber'
</script>

<script lang="ts">
  import Icon from './Icon.svelte'

  /// An app's icon: a flat 23% squircle in one tone, a hairline edge, one
  /// filled glyph at 54%. No gradient, no sheen, no shadow.

  interface Props {
    glyph: string
    tone?: IconTone
    size?: number
    /// Read out; absent, the icon is decoration.
    label?: string
    class?: string
  }

  const { glyph, tone = 'berry', size = 50, label, class: className = '' }: Props = $props()
</script>

<span
  role={label ? 'img' : undefined}
  aria-label={label}
  aria-hidden={label ? undefined : true}
  class="lk-appicon lk-appicon--{tone} {className}"
  style:width="{size}px"
  style:height="{size}px"
>
  <Icon name={glyph} size={Math.round(size * 0.54)} fill weight={500} class="lk-appicon__glyph" />
</span>
