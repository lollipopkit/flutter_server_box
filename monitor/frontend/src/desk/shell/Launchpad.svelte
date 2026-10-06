<script lang="ts">
  import { MonitorUp, PanelBottom, Search } from '@lucide/svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import AppIcon from './AppIcon.svelte'

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
  class="desk-glass desk-pop absolute bottom-[calc(var(--dock-reserve)+0.25rem)] left-1/2 z-[100001] flex max-h-[min(36rem,calc(100%-var(--dock-reserve)-4rem))] w-[min(44rem,calc(100%-1rem))] -translate-x-1/2 flex-col rounded-(--radius-panel) p-4"
  role="dialog"
  aria-label={$LL.deskLaunchpad()}
  tabindex="-1"
  onpointerdown={(e) => e.stopPropagation()}
>
  <label class="mx-auto mb-4 flex w-64 items-center gap-2 rounded-lg px-2.5 py-1.5" style:background="hsl(var(--ink) / 0.08)">
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
  <div class="grid grid-cols-3 gap-x-2 gap-y-4 overflow-y-auto sm:grid-cols-5">
    {#each shown as spec (spec.id)}
      <button
        class="desk-hover flex flex-col items-center gap-1.5 p-2"
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
        <AppIcon {spec} size={3.5} />
        <span class="w-full truncate text-center text-xs">{spec.title($LL)}</span>
      </button>
    {/each}
  </div>
</div>
