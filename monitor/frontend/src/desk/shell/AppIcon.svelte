<script lang="ts">
  import type { AppSpec } from '../sys/manifest'
  import { useDesk } from '../deskState.svelte'
  import LkAppIcon from '@lollipopkit/desk-ui/AppIcon.svelte'

  /// An app's icon by its registry entry.

  interface Props {
    spec: AppSpec
    /// The tile's edge, in px.
    size?: number
    class?: string
  }

  const { spec, size = 44, class: className }: Props = $props()
  const desk = useDesk()
  /// The app may change its icon while it runs.
  const icon = $derived(desk.appChrome(spec.id).icon ?? spec)
</script>

<LkAppIcon glyph={icon.glyph} tone={icon.tone} {size} class={className} />
