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

<span
  class="desk-tile shrink-0"
  style:width="{size}rem"
  style:height="{size}rem"
  style:background="linear-gradient(180deg, {spec.tint[0]}, {spec.tint[1]})"
  aria-hidden="true"
>
  <Icon style="width: {size * 0.5}rem; height: {size * 0.5}rem" strokeWidth={1.9} />
</span>
