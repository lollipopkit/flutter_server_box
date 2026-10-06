<script lang="ts">
  import { LayoutGrid } from '@lucide/svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { app, type AppSpec } from '../apps'
  import { useDesk, type MenuItem } from '../deskState.svelte'
  import AppIcon from './AppIcon.svelte'

  const desk = useDesk()

  /// The pinned apps this account can use, then the running ones not pinned.
  const pinned = $derived(
    (desk.prefs?.value.dock ?? [])
      .map((id) => app(id))
      .filter((a): a is AppSpec => !!a && a.available(desk.caps)),
  )
  const running = $derived(
    [...new Set(desk.windows.windows.map((w) => w.appId))]
      .filter((id) => !pinned.some((p) => p.id === id))
      .map((id) => app(id))
      .filter((a): a is AppSpec => !!a),
  )

  function isRunning(id: string) {
    return desk.windows.windows.some((w) => w.appId === id)
  }

  /// Not running: opens it. Running: the app's front window comes forward,
  /// or goes away when it already is in front.
  function activate(spec: AppSpec) {
    const mine = desk.windows.of(spec.id)
    if (mine.length === 0) {
      desk.open(spec.id)
      return
    }
    const front = mine.reduce((a, b) => (b.z > a.z ? b : a))
    if (desk.windows.active?.id === front.id && !front.minimized) desk.windows.minimize(front.id)
    else for (const w of mine) desk.windows.focus(w.id)
    desk.panel = null
  }

  function menu(e: MouseEvent, spec: AppSpec) {
    const prefs = desk.prefs
    const mine = desk.windows.of(spec.id)
    const items: MenuItem[] = mine.map((w) => ({
      label: w.title ?? spec.title($LL),
      checked: desk.windows.active?.id === w.id,
      action: () => desk.windows.focus(w.id),
    }))
    if (items.length > 0) items.push({ separator: true })
    if (spec.instances > 1) {
      items.push({
        label: $LL.deskNewWindow(),
        disabled: mine.length >= spec.instances,
        action: () => desk.open(spec.id, { newWindow: true }),
      })
    }
    const isPinned = desk.prefs?.value.dock.includes(spec.id)
    items.push({
      label: isPinned ? $LL.deskUnpin() : $LL.deskPin(),
      action: () => (isPinned ? prefs?.unpin(spec.id) : prefs?.pin(spec.id)),
    })
    if (mine.length > 0) {
      items.push({ separator: true }, { label: $LL.deskQuit(), action: () => desk.windows.closeApp(spec.id) })
    }
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
    e.preventDefault()
    e.stopPropagation()
    desk.menu = { x: r.left, y: r.top - 8, items, above: true }
  }

  /// Smaller tiles on a phone, so the dock fits more of them.
  const tile = $derived(desk.windows.compact ? 2.5 : 3)

  // Reordering the pinned part by dragging.
  let dragging = $state<string | null>(null)
</script>

<nav
  class="desk-glass absolute bottom-2 left-1/2 z-[100000] flex select-none max-w-[calc(100%-1rem)] -translate-x-1/2 items-end gap-1 overflow-x-auto rounded-(--radius-panel) px-2 py-1.5"
  aria-label={$LL.deskDock()}
  onpointerdown={(e) => {
    e.stopPropagation()
    desk.menu = null
  }}
>
  <button
    class="desk-hover group relative flex flex-col items-center px-1"
    aria-label={$LL.deskLaunchpad()}
    title={$LL.deskLaunchpad()}
    aria-expanded={desk.panel === 'launchpad'}
    onclick={(e) => {
      e.stopPropagation()
      desk.togglePanel('launchpad')
    }}
  >
    <span class="desk-tile" style:width="{tile}rem" style:height="{tile}rem" style:background="linear-gradient(180deg,#a5b4fc,#6366f1)">
      <LayoutGrid class="h-6 w-6" />
    </span>
    <span class="mt-0.5 h-1 w-1"></span>
  </button>

  {#each pinned as spec (spec.id)}
    <button
      class="desk-hover relative flex flex-col items-center px-1 transition-transform hover:-translate-y-1"
      class:opacity-50={dragging === spec.id}
      title={spec.title($LL)}
      aria-label={spec.title($LL)}
      draggable="true"
      ondragstart={(e) => {
        dragging = spec.id
        e.dataTransfer?.setData('text/plain', spec.id)
      }}
      ondragend={() => (dragging = null)}
      ondragover={(e) => e.preventDefault()}
      ondrop={(e) => {
        e.preventDefault()
        if (dragging && dragging !== spec.id) desk.prefs?.moveInDock(dragging, pinned.findIndex((p) => p.id === spec.id))
        dragging = null
      }}
      onclick={() => activate(spec)}
      oncontextmenu={(e) => menu(e, spec)}
    >
      <AppIcon {spec} size={tile} />
      <span class="mt-0.5 h-1 w-1 rounded-full" class:bg-current={isRunning(spec.id)}></span>
    </button>
  {/each}

  {#if running.length > 0}
    <span class="mx-1 mb-2 h-10 w-px self-center bg-current opacity-20"></span>
    {#each running as spec (spec.id)}
      <button
        class="desk-hover relative flex flex-col items-center px-1 transition-transform hover:-translate-y-1"
        title={spec.title($LL)}
        aria-label={spec.title($LL)}
        onclick={() => activate(spec)}
        oncontextmenu={(e) => menu(e, spec)}
      >
        <AppIcon {spec} size={tile} />
        <span class="mt-0.5 h-1 w-1 rounded-full bg-current"></span>
      </button>
    {/each}
  {/if}
</nav>
