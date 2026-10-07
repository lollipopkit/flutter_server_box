<script lang="ts">
  import { LL } from '../../i18n/i18n-svelte'
  import { app } from '../registry.svelte'
  import type { AppSpec } from '../sys/manifest'
  import { useDesk, type MenuItem } from '../deskState.svelte'
  import LkAppIcon from '../lk/AppIcon.svelte'
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
    desk.menu = { x: r.left, y: r.top - 8, items, above: true }
  }

  /// Smaller tiles on a phone, so the dock fits more of them.
  const tile = $derived(desk.windows.compact ? 40 : 44)

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

<div class="pointer-events-none absolute inset-x-0 bottom-[var(--dock-bottom)] z-[100000] flex justify-center px-2">
  <nav
    class="lk-dock pointer-events-auto max-w-full"
    style:padding={desk.windows.compact ? '7px' : undefined}
    aria-label={$LL.deskDock()}
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

    {#each pinned as spec (spec.id)}
      <button
        class="lk-dock__item"
        class:lk-dock__item--bounce={bouncing === spec.id}
        class:opacity-50={dragging === spec.id}
        style:width="{tile}px"
        style:height="{tile}px"
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
        <span class="lk-dock__label">{spec.title($LL)}</span>
        <span class="lk-dock__icon"><AppIcon {spec} size={tile} /></span>
        {@render badge(spec.id)}
        {#if isRunning(spec.id)}<span class="lk-dock__dot"></span>{/if}
      </button>
    {/each}

    {#if running.length > 0}
      <span class="lk-dock__sep"></span>
      {#each running as spec (spec.id)}
        <button
          class="lk-dock__item"
          style:width="{tile}px"
          style:height="{tile}px"
          aria-label={spec.title($LL)}
          onclick={() => activate(spec)}
          oncontextmenu={(e) => menu(e, spec)}
        >
          <span class="lk-dock__label">{spec.title($LL)}</span>
          <span class="lk-dock__icon"><AppIcon {spec} size={tile} /></span>
          {@render badge(spec.id)}
          <span class="lk-dock__dot"></span>
        </button>
      {/each}
    {/if}
  </nav>
</div>

<style>
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
</style>
