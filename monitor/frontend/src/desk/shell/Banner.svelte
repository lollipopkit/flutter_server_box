<script lang="ts">
  import { TriangleAlert } from '@lucide/svelte'
  import { fly } from 'svelte/transition'
  import { useDesk } from '../deskState.svelte'

  const desk = useDesk()
  const banner = $derived(desk.notifications?.banner ?? null)
</script>

{#if banner}
  {#key banner.id}
    <button
      class="desk-glass-strong absolute right-2 top-[calc(var(--menubar-h)+1rem)] z-[100002] flex w-80 max-w-[calc(100%-1rem)] gap-2.5 rounded-2xl p-3 text-left"
      transition:fly={{ x: 40, duration: 220 }}
      onclick={() => {
        desk.notifications?.dismissBanner()
        desk.togglePanel('notifications')
      }}
    >
      <TriangleAlert class="mt-0.5 h-4 w-4 shrink-0 text-warning" />
      <span class="min-w-0">
        <span class="block truncate text-[0.8rem] font-semibold">{banner.subject}</span>
        <span class="desk-muted line-clamp-2 text-xs">{banner.body}</span>
      </span>
    </button>
  {/key}
{/if}
