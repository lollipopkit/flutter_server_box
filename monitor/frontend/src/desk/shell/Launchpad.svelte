<script lang="ts">
  import { LL } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import Input from '@lollipopkit/desk-ui/Input.svelte'
  import AppIcon from './AppIcon.svelte'

  const desk = useDesk()

  let search = $state<HTMLInputElement | null>(null)
  // `autofocus` is ignored once anything on the page has focus.
  $effect(() => {
    if (search) queueMicrotask(() => search?.focus())
  })
  let query = $state('')
  const shown = $derived(
    desk.apps.filter((a) => {
      const q = query.trim().toLowerCase()
      if (!q) return true
      return [a.title($LL), ...(a.keywords?.($LL) ?? [])].some((w) => w.toLowerCase().includes(q))
    }),
  )
</script>

<!-- The whole desk, blurred, with every app on it; a click beside the icons
     closes it. -->
<!-- svelte-ignore a11y_click_events_have_key_events -->
<div
  class="launchpad absolute inset-0 z-[100001] flex flex-col items-center gap-[55px] overflow-y-auto px-4 pb-28 pt-[70px]"
  role="dialog"
  aria-label={$LL.deskLaunchpad()}
  tabindex="-1"
  onpointerdown={(e) => e.stopPropagation()}
  onclick={(e) => {
    if (e.target === e.currentTarget) desk.panel = null
  }}
>
  <div class="w-[280px] max-w-full">
    <Input
      icon="search"
      filled
      placeholder={$LL.deskSearch()}
      aria-label={$LL.deskSearch()}
      bind:value={query}
      bind:ref={search}
      onkeydown={(e) => {
        if (e.key === 'Enter' && shown.length > 0) desk.open(shown[0].id)
      }}
    />
  </div>
  <div class="launchpad-grid">
    {#each shown as spec, i (spec.id)}
      <button
        class="launchpad-app"
        style:animation-delay="{i * 30}ms"
        onclick={() => desk.open(spec.id)}
        oncontextmenu={(e) => {
          const prefs = desk.prefs
          const pinned = prefs?.value.dock.includes(spec.id)
          const onDesk = prefs?.value.icons.some((i) => i.kind === 'app' && i.app_id === spec.id)
          desk.showMenu(e, [
            { label: $LL.deskOpen(), icon: 'open_in_new', action: () => desk.open(spec.id) },
            { separator: true },
            {
              label: pinned ? $LL.deskUnpin() : $LL.deskPin(),
              icon: pinned ? 'keep_off' : 'keep',
              action: () => (pinned ? prefs?.unpin(spec.id) : prefs?.pin(spec.id)),
            },
            {
              label: $LL.deskAddToDesk(),
              icon: 'add_to_home_screen',
              disabled: onDesk,
              action: () => prefs?.addIcon({ kind: 'app', app_id: spec.id, label: '' }),
            },
          ])
        }}
      >
        <AppIcon {spec} size={76} />
        <span class="w-full truncate">{spec.title($LL)}</span>
      </button>
    {/each}
  </div>
</div>

<style>
  .launchpad {
    background: color-mix(in srgb, var(--surface-desktop) 35%, transparent);
    backdrop-filter: blur(40px) saturate(1.4);
    -webkit-backdrop-filter: blur(40px) saturate(1.4);
    animation: launchpad-in var(--dur-scene) var(--ease-emphasized);
  }
  @keyframes launchpad-in {
    from {
      opacity: 0;
      transform: scale(1.08);
    }
    to {
      opacity: 1;
      transform: none;
    }
  }
  .launchpad-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, 120px);
    justify-content: center;
    gap: var(--space-34) var(--space-21);
    width: min(100%, calc(5 * 120px + 4 * 21px));
  }
  .launchpad-app {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-9);
    padding: 0;
    border: 0;
    background: none;
    font-size: var(--text-13);
    font-weight: var(--weight-semibold);
    color: var(--text-primary);
    cursor: default;
    animation: lk-pop-in var(--dur-window) var(--ease-spring-bouncy) both;
    transition: transform var(--dur-slow) var(--ease-spring-bouncy);
  }
  .launchpad-app:active {
    transform: scale(0.9);
  }
  .launchpad-app:focus-visible {
    outline: none;
    border-radius: var(--radius-card);
    box-shadow: var(--focus-ring);
  }
</style>
