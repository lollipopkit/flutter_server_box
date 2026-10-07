<script lang="ts">
  import { tick } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { app } from '../registry.svelte'
  import { useDesk } from '../deskState.svelte'
  import type { DeskIcon } from '../deskApi'
  import { placeIcons, CELL } from '../iconGrid'
  import LkAppIcon from '../lk/AppIcon.svelte'
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
      { label: $LL.deskOpen(), icon: 'open_in_new', action: () => open(icon) },
      { label: $LL.deskRename(), icon: 'edit', action: () => void startRename(icon) },
      { separator: true },
      { label: $LL.deskRemoveFromDesk(), icon: 'delete', danger: true, action: () => desk.prefs?.removeIcon(icon.id) },
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
      class="desk-icon pointer-events-auto absolute flex w-[84px] select-none flex-col items-center gap-[5px] rounded-[11px] py-[7px] text-center"
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
        <LkAppIcon glyph="folder" tone="sky" size={54} />
      {:else if spec}
        <AppIcon {spec} size={54} />
      {/if}
      {#if renaming === icon.id}
        <input
          class="lk-rename w-full text-center"
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
        <span class="desk-icon-label line-clamp-2 break-words">{label(icon)}</span>
      {/if}
    </div>
  {/each}
</div>

<style>
  .desk-icon-label {
    padding: 1px 7px;
    border-radius: var(--radius-xs);
    font-size: var(--text-12);
    font-weight: var(--weight-semibold);
    color: var(--text-primary);
  }
  .desk-icon-selected {
    background: var(--fill-press);
  }
  .desk-icon-selected .desk-icon-label {
    background: var(--color-accent);
    color: var(--text-on-accent);
  }
  .lk-rename {
    height: 22px;
    padding: 0 var(--space-5);
    border: 0;
    border-radius: var(--radius-xs);
    background: var(--surface-field);
    box-shadow: inset 0 0 0 1px var(--color-accent), var(--focus-ring);
    font: var(--weight-semibold) var(--text-12) var(--font-ui);
    color: var(--text-primary);
    outline: none;
  }
</style>
