<script lang="ts">
  import { untrack } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { app } from '../registry.svelte'
  import type { AppSpec } from '../sys/manifest'
  import { useDesk, type MenuItem } from '../deskState.svelte'
  import LkAppIcon from '@lollipopkit/desk-ui/AppIcon.svelte'
  import AppIcon from './AppIcon.svelte'
  import { shellPrefs } from '../shellPrefs.svelte'
  import { dockItem } from './dockMotion'

  const desk = useDesk()

  /// On a side or at the bottom; on a phone always at the bottom.
  const position = $derived(shellPrefs.dockAt(desk.windows.compact))
  const vertical = $derived(position !== 'bottom')
  /// Hidden until the pointer reaches its edge, when it hides itself.
  const autoHide = $derived(shellPrefs.dockAutoHide && !desk.windows.compact)
  let hovered = $state(false)
  /// The pointer is on the dock or on the strip along its edge.
  let pointerIn = $state(false)
  let hideTimer: ReturnType<typeof setTimeout> | undefined
  function enter() {
    clearTimeout(hideTimer)
    pointerIn = true
    hovered = true
  }
  function leave() {
    pointerIn = false
    clearTimeout(hideTimer)
    // A menu opened from it keeps it out.
    hideTimer = setTimeout(() => {
      if (!desk.menu && !pointerIn) hovered = false
    }, 500)
  }
  // The menu it opened has closed with the pointer elsewhere: it goes.
  $effect(() => {
    if (!desk.menu && hovered && !untrack(() => pointerIn) && autoHide) leave()
  })
  const hidden = $derived(autoHide && !hovered)

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

  /// The dock as the desk first draws it does not animate in; what comes
  /// and goes after does. (The transitions are global: each item sits in an
  /// `{#if}` inside the list.)
  let ready = $state(false)
  $effect(() => {
    const t = setTimeout(() => (ready = true), 0)
    return () => clearTimeout(t)
  })

  /// What the dock shows, in order, each keyed by what it is.
  type Slot = { key: string; kind: 'pinned' | 'running'; spec: AppSpec } | { key: string; kind: 'sep' }
  const slots = $derived<Slot[]>([
    ...pinned.map((spec): Slot => ({ key: spec.id, kind: 'pinned', spec })),
    ...(running.length ? [{ key: '|', kind: 'sep' } as Slot] : []),
    ...running.map((spec): Slot => ({ key: spec.id, kind: 'running', spec })),
  ])

  function isRunning(id: string) {
    return desk.windows.windows.some((w) => w.appId === id)
  }

  /// Not running: opens it. Running: the app's front window comes forward,
  /// or goes away when it already is in front.
  function activate(spec: AppSpec) {
    const mine = desk.windows.of(spec.id)
    if (mine.length === 0) {
      bounce(spec.id)
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
    // What the app adds of its own (a recent file, a new session).
    const own = desk.appChrome(spec.id).dockItems
    if (own.length > 0) items.push(...own, { separator: true })
    if (spec.instances > 1) {
      items.push({
        label: $LL.deskNewWindow(),
        icon: 'add',
        disabled: mine.length >= spec.instances,
        action: () => desk.open(spec.id, { newWindow: true }),
      })
    }
    const isPinned = desk.prefs?.value.dock.includes(spec.id)
    items.push({
      label: isPinned ? $LL.deskUnpin() : $LL.deskPin(),
      icon: isPinned ? 'keep_off' : 'keep',
      action: () => (isPinned ? prefs?.unpin(spec.id) : prefs?.pin(spec.id)),
    })
    if (mine.length > 0) {
      items.push({ separator: true }, { label: $LL.deskQuit(), icon: 'close', action: () => desk.windows.closeApp(spec.id) })
    }
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
    e.preventDefault()
    e.stopPropagation()
    // Away from the dock's edge: above it, or beside it on a side.
    desk.menu =
      position === 'left'
        ? { x: r.right + 13, y: r.top, items }
        : position === 'right'
          ? { x: r.left - 13, y: r.top, items, end: true }
          : { x: r.left, y: r.top - 8, items, above: true }
  }

  /// Smaller tiles on a phone, so the dock fits more of them.
  const tile = $derived(desk.windows.compact ? 40 : shellPrefs.dockSize)

  /// The app just launched from the dock bounces twice.
  let bouncing = $state<string | null>(null)
  function bounce(id: string) {
    bouncing = id
    setTimeout(() => {
      if (bouncing === id) bouncing = null
    }, 1800)
  }

  // Reordering the pinned part by dragging.
  let dragging = $state<string | null>(null)
</script>

{#snippet badge(appId: string)}
  {@const text = desk.appChrome(appId).badge}
  {#if text}<span class="lk-badge lk-badge--count absolute -right-[5px] -top-[5px]" style:height="18px" style:min-width="18px">{text}</span>{/if}
{/snippet}

{#if autoHide}
  <!-- The strip along the dock's edge that brings it back. -->
  <div class="dock-reveal dock-reveal--{position} absolute z-[99999]" aria-hidden="true" onpointerenter={enter} onpointerleave={leave}></div>
{/if}
<div class="dock-place dock-place--{position} pointer-events-none absolute z-[100000] flex items-center justify-center">
  <nav
    class="lk-dock lk-dock--{position} pointer-events-auto max-h-full max-w-full"
    class:lk-dock--vertical={vertical}
    class:lk-dock--hidden={hidden}
    style:padding={desk.windows.compact ? '7px' : undefined}
    aria-label={$LL.deskDock()}
    aria-hidden={hidden || undefined}
    inert={hidden}
    onpointerenter={enter}
    onpointerleave={() => autoHide && leave()}
    onpointerdown={(e) => {
      e.stopPropagation()
      desk.menu = null
    }}
  >
    <button
      class="lk-dock__item"
      style:width="{tile}px"
      style:height="{tile}px"
      aria-label={$LL.deskLaunchpad()}
      aria-expanded={desk.panel === 'launchpad'}
      onclick={(e) => {
        e.stopPropagation()
        desk.togglePanel('launchpad')
      }}
    >
      <span class="lk-dock__label">{$LL.deskLaunchpad()}</span>
      <span class="lk-dock__icon"><LkAppIcon glyph="apps" tone="pale" size={tile} /></span>
    </button>

    <!-- Pinned apps, then (after a separator) the running ones not pinned:
         one keyed list, so an app that comes or goes animates and the rest
         slide over. -->
    {#each slots as slot (slot.key)}
      {#if slot.kind === 'sep'}
        <span
          class="lk-dock__sep"
          in:dockItem|global={{ size: 1, vertical, still: !ready }}
          out:dockItem|global={{ size: 1, vertical, leaving: true }}
        ></span>
      {:else}
        {@const spec = slot.spec}
        <button
          class="lk-dock__item"
          class:lk-dock__item--bounce={bouncing === spec.id}
          class:opacity-50={dragging === spec.id}
          style:width="{tile}px"
          style:height="{tile}px"
          aria-label={spec.title($LL)}
          draggable={slot.kind === 'pinned'}
          in:dockItem|global={{ size: tile, vertical, still: !ready }}
          out:dockItem|global={{ size: tile, vertical, leaving: true }}
          ondragstart={(e) => {
            if (slot.kind !== 'pinned') return
            dragging = spec.id
            e.dataTransfer?.setData('text/plain', spec.id)
          }}
          ondragend={() => (dragging = null)}
          ondragover={(e) => slot.kind === 'pinned' && e.preventDefault()}
          ondrop={(e) => {
            e.preventDefault()
            if (dragging && dragging !== spec.id) desk.prefs?.moveInDock(dragging, pinned.findIndex((p) => p.id === spec.id))
            dragging = null
          }}
          onclick={() => activate(spec)}
          oncontextmenu={(e) => menu(e, spec)}
        >
          <span class="lk-dock__label">{spec.title($LL)}</span>
          <span class="lk-dock__icon"><AppIcon {spec} size={tile} /></span>
          {@render badge(spec.id)}
          {#if isRunning(spec.id) && shellPrefs.dockRunDots}<span class="lk-dock__dot"></span>{/if}
        </button>
      {/if}
    {/each}
  </nav>
</div>

<style>
  .dock-place--bottom {
    left: 0;
    right: 0;
    bottom: var(--dock-bottom);
    padding: 0 8px;
  }
  .dock-place--left,
  .dock-place--right {
    top: var(--menubar-height);
    bottom: 0;
    padding: 8px 0;
  }
  .dock-place--left {
    left: 9px;
  }
  .dock-place--right {
    right: 9px;
  }
  .dock-reveal--bottom {
    left: 0;
    right: 0;
    bottom: 0;
    height: 4px;
  }
  .dock-reveal--left,
  .dock-reveal--right {
    top: var(--menubar-height);
    bottom: 0;
    width: 4px;
  }
  .dock-reveal--left {
    left: 0;
  }
  .dock-reveal--right {
    right: 0;
  }
  /* The items are buttons: reset what a button brings, keep the focus ring. */
  .lk-dock__item {
    padding: 0;
    border: 0;
    background: none;
  }
  .lk-dock__item:focus-visible {
    outline: none;
    border-radius: var(--radius-icon);
    box-shadow: var(--focus-ring);
  }
  .lk-dock__item:focus-visible .lk-dock__label {
    opacity: 1;
    transform: translate(-50%, 0);
  }
  .lk-dock--vertical .lk-dock__item:focus-visible .lk-dock__label {
    transform: translate(0, -50%);
  }
</style>
