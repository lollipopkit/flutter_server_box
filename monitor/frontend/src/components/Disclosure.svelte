<script lang="ts">
  import { ChevronDown } from '@lucide/svelte'
  import type { Snippet } from 'svelte'

  interface Props {
    summary: string
    children: Snippet
    /// Collapsed by default — these are reference notes, not primary content
    open?: boolean
  }

  let { summary, children, open = false }: Props = $props()
</script>

<details bind:open class="group">
  <summary
    class="flex items-center gap-1.5 cursor-pointer select-none text-xs text-faint-fg hover:text-muted-fg list-none [&::-webkit-details-marker]:hidden"
  >
    <ChevronDown class="w-3.5 h-3.5 shrink-0 transition-transform group-open:rotate-180" />
    {summary}
  </summary>
  <div class="mt-2">
    {@render children()}
  </div>
</details>
