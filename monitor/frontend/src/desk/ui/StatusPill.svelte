<script lang="ts" module>
  export type PillTone = 'success' | 'warning' | 'danger' | 'accent' | 'neutral'
</script>

<script lang="ts">
  import type { Snippet } from 'svelte'

  /// TODO: remove once every app uses `lk/Badge` — a compatibility shim.

  interface Props {
    tone?: PillTone
    children: Snippet
  }

  const { tone = 'neutral', children }: Props = $props()
</script>

<span class="lk-badge lk-badge--{tone}">{@render children()}</span>
