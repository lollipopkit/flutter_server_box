<script lang="ts">
  import { ExternalLink, Folder, Pencil, Trash2 } from '@lucide/svelte'
  import { tick } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { app } from '../apps'
  import { useDesk } from '../deskState.svelte'
  import type { DeskIcon } from '../deskApi'
  import { placeIcons, CELL } from '../iconGrid'
  import AppIcon from './AppIcon.svelte'

  const desk = useDesk()

  /// Icons for apps this server and account can use, and paths when Files is.
  const usable = $derived(
    (desk.prefs?.value.icons ?? []).filter((i) => app(i.app_id)?.available(desk.caps) ?? false),
  )
  const area = $derived(desk.windows.area)
  const placed = $derived(placeIcons(usable, { width: area.width, height: area.height - area.top - area.bottom }))

  let selected = $state<string | null>(null)
  let renaming = $state<string | null>(null)
  let draft = $state('')
  let drag = $state<{ id: string; dx: number; dy: number; x0: number; y0: number; moved: boolean } | null>(null)

  function label(icon: DeskIcon): string {
    if (icon.label) return icon.label
    return app(icon.app_id)?.title($LL) ?? icon.app_id
  }

  function open(icon: DeskIcon) {
    if (icon.kind === 'path') desk.open(icon.app_id, { appState: { path: icon.path }, newWindow: true })
    else desk.open(icon.app_id)
  }

  async function startRename(icon: DeskIcon) {
    renaming = icon.id
    draft = label(icon)
    await tick()
    document.querySelector<HTMLInputElement>(`[data-rename="${icon.id}"]`)?.select()
  }

  function commitRename() {
    const name = draft.trim()
    if (renaming && name && name.length <= 64) desk.prefs?.renameIcon(renaming, name)
    renaming = null
  }

  function menu(e: MouseEvent, icon: DeskIcon) {
    selected = icon.id
    desk.showMenu(e, [
      { label: $LL.deskOpen(), icon: ExternalLink, action: () => open(icon) },
      { label: $LL.deskRename(), icon: Pencil, action: () => void startRename(icon) },
      { separator: true },
      { label: $LL.deskRemoveFromDesk(), icon: Trash2, danger: true, action: () => desk.prefs?.removeIcon(icon.id) },
    ])
  }

  function onpointerdown(e: PointerEvent, id: string) {
    if (e.button !== 0 || renaming === id) return
    e.stopPropagation()
    selected = id
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
    drag = { id, dx: 0, dy: 0, x0: e.clientX, y0: e.clientY, moved: false }
  }

  function onpointermove(e: PointerEvent) {
    if (!drag) return
    drag.dx = e.clientX - drag.x0
    drag.dy = e.clientY - drag.y0
    if (Math.abs(drag.dx) + Math.abs(drag.dy) > 4) drag.moved = true
  }

  /// Let go at the icon's cell ([x], [y]) moved by the drag: the nearest cell.
  function onpointerup(x: number, y: number) {
    if (!drag) return
    const { id, dx, dy, moved } = drag
    drag = null
    if (!moved) return
    const width = area.width
    // Cells count from the right edge, as the grid lays them out.
    const col = Math.max(0, Math.round((width - CELL.width - CELL.margin - (x + dx)) / CELL.width))
    const row = Math.max(0, Math.round((y + dy - CELL.margin) / CELL.height))
    desk.prefs?.placeIcon(id, col, row)
  }
</script>

<svelte:window
  onpointerdown={() => {
    selected = null
  }}
/>

<div class="pointer-events-none absolute inset-x-0" style:top="{area.top}px" style:bottom="{area.bottom}px">
  {#each placed as { icon, x, y } (icon.id)}
    {@const spec = app(icon.app_id)}
    {@const dragged = drag?.id === icon.id && drag.moved}
    <div
      class="pointer-events-auto absolute flex w-24 select-none flex-col items-center gap-1 rounded-lg p-1.5 text-center"
      class:desk-icon-selected={selected === icon.id}
      style:left="{x + (dragged ? drag!.dx : 0)}px"
      style:top="{y + (dragged ? drag!.dy : 0)}px"
      style:z-index={dragged ? 5 : 1}
      style:touch-action="none"
      role="button"
      tabindex="0"
      aria-label={label(icon)}
      data-desk-icon={icon.id}
      onpointerdown={(e) => onpointerdown(e, icon.id)}
      onpointermove={onpointermove}
      onpointerup={() => onpointerup(x, y)}
      ondblclick={() => open(icon)}
      oncontextmenu={(e) => menu(e, icon)}
      onkeydown={(e) => {
        if (e.key === 'Enter') open(icon)
        if (e.key === 'F2') void startRename(icon)
      }}
    >
      {#if icon.kind === 'path'}
        <span class="desk-tile h-12 w-12" style:background="linear-gradient(180deg,#7dd3fc,#0284c7)">
          <Folder class="h-6 w-6" />
        </span>
      {:else if spec}
        <AppIcon {spec} size={3} />
      {/if}
      {#if renaming === icon.id}
        <input
          class="w-full rounded bg-white px-1 text-center text-xs text-black outline-none ring-2"
          style:--tw-ring-color="var(--desk-accent)"
          data-rename={icon.id}
          bind:value={draft}
          maxlength="64"
          onpointerdown={(e) => e.stopPropagation()}
          onkeydown={(e) => {
            if (e.key === 'Enter') commitRename()
            if (e.key === 'Escape') renaming = null
          }}
          onblur={commitRename}
        />
      {:else}
        <span class="desk-icon-label line-clamp-2 break-words rounded px-1 text-xs font-medium">{label(icon)}</span>
      {/if}
    </div>
  {/each}
</div>

<style>
  .desk-icon-label {
    color: white;
    text-shadow: 0 1px 3px rgb(0 0 0 / 0.6);
  }
  .desk-icon-selected {
    background: hsl(var(--ink) / 0.14);
  }
  .desk-icon-selected .desk-icon-label {
    background: var(--desk-accent);
    text-shadow: none;
  }
</style>
