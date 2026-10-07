<script lang="ts">
  import type { AppSpec } from '../apps'
  import LkAppIcon from '../lk/AppIcon.svelte'

  /// An app's icon by its registry entry.

  interface Props {
    spec: AppSpec
    /// The tile's edge, in px.
    size?: number
    class?: string
  }

  const { spec, size = 44, class: className }: Props = $props()
</script>

<LkAppIcon glyph={spec.glyph} tone={spec.tone} {size} class={className} />
