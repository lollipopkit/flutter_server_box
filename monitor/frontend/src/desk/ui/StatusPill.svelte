<script lang="ts" module>
  export type PillTone = 'success' | 'warning' | 'danger' | 'accent' | 'neutral'
</script>

<script lang="ts">
  import type { Snippet } from 'svelte'

  /// A state in a few capitals on a soft fill (ACTIVE, PLANNED, EXITED).

  interface Props {
    tone?: PillTone
    children: Snippet
  }

  const { tone = 'neutral', children }: Props = $props()
  const TONE: Record<PillTone, string> = {
    success: 'bg-success/12 text-success',
    warning: 'bg-warning/14 text-warning',
    danger: 'bg-danger/12 text-danger',
    accent: 'bg-primary/12 text-primary',
    neutral: 'bg-soft text-muted-fg',
  }
</script>

<span
  class="inline-flex items-center whitespace-nowrap rounded-full px-2 py-0.5 text-[0.68rem] font-bold uppercase tracking-[0.04em] {TONE[tone]}"
>
  {@render children()}
</span>
