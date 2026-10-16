<script lang="ts">
  import { useDesk } from '../deskState.svelte'
  import { snapRect, type SnapZone } from '../geometry'
  import Window from './Window.svelte'

  const desk = useDesk()
  let preview = $state<SnapZone | null>(null)
  const previewRect = $derived(preview ? snapRect(preview, desk.windows.area) : null)
  /// On a phone only the window in front is drawn (the rest stay mounted).
  const front = $derived(desk.windows.compact ? desk.windows.active?.id : undefined)
</script>

<div class="pointer-events-none absolute inset-0">
  {#if previewRect}
    <div
      class="absolute rounded-xl border-2 transition-all duration-150"
      style:left="{previewRect.x + 6}px"
      style:top="{previewRect.y + 6}px"
      style:width="{previewRect.width - 12}px"
      style:height="{previewRect.height - 12}px"
      style:z-index="99998"
      style:border-color="color-mix(in srgb, var(--desk-accent) 70%, transparent)"
      style:background="color-mix(in srgb, var(--desk-accent) 14%, transparent)"
    ></div>
  {/if}
  <!-- Keyed by id: a window keeps its component (and its app's state) for as
       long as it is open, whatever else opens, closes or moves. -->
  {#each desk.windows.windows as win (win.id)}
    <div class="pointer-events-auto" style:display={front !== undefined && front !== win.id ? 'none' : 'contents'}>
      <Window {win} onsnappreview={(zone) => (preview = zone)} />
    </div>
  {/each}
</div>
