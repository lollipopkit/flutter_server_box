<script lang="ts">
  import { MonitorUp, PanelBottom, Search } from '@lucide/svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import AppIcon from './AppIcon.svelte'
  import PanelHead from './PanelHead.svelte'

  const desk = useDesk()

  /// `autofocus` is ignored once anything on the page has focus.
  function focusNow(el: HTMLInputElement) {
    queueMicrotask(() => el.focus())
  }
  let query = $state('')
  const shown = $derived(
    desk.apps.filter((a) => {
      const q = query.trim().toLowerCase()
      if (!q) return true
      return [a.title($LL), ...(a.keywords?.($LL) ?? [])].some((w) => w.toLowerCase().includes(q))
    }),
  )
</script>

<div
  class="desk-sheet desk-pop absolute bottom-(--dock-reserve) left-1/2 z-[100001] flex max-h-[calc(100%-var(--dock-reserve)-var(--menubar-h)-1.5rem)] w-[min(61.25rem,calc(100%-1.5rem))] -translate-x-1/2 flex-col rounded-(--radius-panel) p-6"
  role="dialog"
  aria-label={$LL.deskLaunchpad()}
  tabindex="-1"
  onpointerdown={(e) => e.stopPropagation()}
>
  <PanelHead
    eyebrow={$LL.deskApps()}
    title={desk.entry.username ? $LL.deskWelcome({ user: desk.entry.username }) : $LL.deskLaunchpad()}
  >
    {#snippet aside()}
      <label class="flex w-56 items-center gap-2 rounded-lg border border-line px-2.5 py-1.5">
        <Search class="h-3.5 w-3.5 opacity-60" />
        <input
          class="w-full bg-transparent text-sm outline-none placeholder:opacity-60"
          placeholder={$LL.deskSearch()}
          bind:value={query}
          use:focusNow
          onkeydown={(e) => {
            if (e.key === 'Enter' && shown.length > 0) desk.open(shown[0].id)
          }}
        />
      </label>
    {/snippet}
  </PanelHead>
  <div class="grid grid-cols-2 gap-2.5 overflow-y-auto sm:grid-cols-3 lg:grid-cols-4">
    {#each shown as spec (spec.id)}
      <button
        class="desk-card flex flex-col items-center gap-1.5 px-2 py-2.5 text-center"
        onclick={() => desk.open(spec.id)}
        oncontextmenu={(e) => {
          const prefs = desk.prefs
          const pinned = prefs?.value.dock.includes(spec.id)
          const onDesk = prefs?.value.icons.some((i) => i.kind === 'app' && i.app_id === spec.id)
          desk.showMenu(e, [
            { label: $LL.deskOpen(), action: () => desk.open(spec.id) },
            { separator: true },
            {
              label: pinned ? $LL.deskUnpin() : $LL.deskPin(),
              icon: PanelBottom,
              action: () => (pinned ? prefs?.unpin(spec.id) : prefs?.pin(spec.id)),
            },
            {
              label: $LL.deskAddToDesk(),
              icon: MonitorUp,
              disabled: onDesk,
              action: () => prefs?.addIcon({ kind: 'app', app_id: spec.id, label: '' }),
            },
          ])
        }}
      >
        <AppIcon {spec} size={2.125} />
        <strong class="w-full truncate text-xs">{spec.title($LL)}</strong>
        <span class="desk-muted w-full truncate text-[0.65rem]">{spec.about($LL)}</span>
      </button>
    {/each}
  </div>
</div>
