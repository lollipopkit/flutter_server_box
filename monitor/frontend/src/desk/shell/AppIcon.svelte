<script lang="ts">
  import type { AppSpec } from '../apps'

  interface Props {
    spec: AppSpec
    /// The tile's edge, in rem.
    size?: number
  }

  const { spec, size = 3 }: Props = $props()
  const Icon = $derived(spec.icon)
</script>

<span class="desk-tile shrink-0" style:width="{size}rem" style:height="{size}rem" aria-hidden="true">
  <Icon style="width: {size * 0.42}rem; height: {size * 0.42}rem" strokeWidth={1.8} />
</span>
