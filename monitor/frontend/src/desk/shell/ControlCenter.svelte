<script lang="ts">
  import { BellOff, LockKeyhole, LogOut, Monitor, Moon, Settings, Sun } from '@lucide/svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName, servers } from '../../lib/servers.svelte'
  import { theme, type Theme } from '../../lib/theme.svelte'
  import { useDesk } from '../deskState.svelte'
  import { ACCENTS, WALLPAPERS } from '../prefs.svelte'
  import PanelHead from './PanelHead.svelte'
  import Wallpaper from './Wallpaper.svelte'

  interface Props {
    onlock: () => void
  }

  const { onlock }: Props = $props()
  const desk = useDesk()

  const serverLabel = $derived(
    serverNames.byServer[desk.entry.id] ?? (desk.entry.id === 'local' ? $LL.thisServer() : displayName(desk.entry)),
  )
  const dnd = $derived(desk.notifications?.dnd ?? false)

  const THEMES: { id: Theme; icon: typeof Sun; label: () => string }[] = [
    { id: 'light', icon: Sun, label: () => $LL.deskThemeLight() },
    { id: 'dark', icon: Moon, label: () => $LL.deskThemeDark() },
    { id: 'system', icon: Monitor, label: () => $LL.deskThemeSystem() },
  ]

  function lock() {
    desk.panel = null
    onlock()
  }
</script>

<PanelHead eyebrow={serverLabel} title={$LL.deskControlCenter()}>
  {#snippet aside()}
    {#if desk.storage?.remote}
      <span
        class="rounded-full px-2.5 py-1 text-[0.7rem] font-bold {desk.live
          ? 'bg-success/12 text-success'
          : 'bg-warning/12 text-warning'}"
      >
        {desk.live ? $LL.deskLiveShort() : $LL.deskOfflineShort()}
      </span>
    {/if}
  {/snippet}
</PanelHead>

<div class="grid grid-cols-2 gap-2 text-[0.8rem]">
  <button
    class="desk-card col-span-2 flex min-h-16 items-center gap-2.5 p-2.5 text-left"
    onclick={() => desk.open('settings', { appState: { section: 'appearance' } })}
  >
    <span class="desk-glyph h-8 w-8 rounded-full"><Settings class="h-4 w-4" /></span>
    <span class="min-w-0">
      <strong class="block text-[0.8rem]">{$LL.deskAppSettings()}</strong>
      <small class="desk-muted block truncate text-[0.68rem]">{$LL.deskSettingsHint()}</small>
    </span>
  </button>
  <button
    class="desk-card flex min-h-16 items-center gap-2.5 p-2.5 text-left"
    class:desk-chosen={dnd}
    aria-pressed={dnd}
    onclick={() => desk.notifications?.setDnd(!dnd)}
  >
    <span class="desk-glyph h-8 w-8 rounded-full" class:desk-selected={dnd}><BellOff class="h-4 w-4" /></span>
    <span class="min-w-0">
      <strong class="block text-[0.8rem]">{$LL.deskDnd()}</strong>
      <small class="desk-muted block truncate text-[0.68rem]">{dnd ? $LL.deskOn() : $LL.deskOff()}</small>
    </span>
  </button>
  <button class="desk-card flex min-h-16 items-center gap-2.5 p-2.5 text-left" onclick={lock}>
    <span class="desk-glyph h-8 w-8 rounded-full"><LockKeyhole class="h-4 w-4" /></span>
    <span class="min-w-0">
      <strong class="block text-[0.8rem]">{$LL.deskLock()}</strong>
      <small class="desk-muted block truncate text-[0.68rem]">{$LL.deskLockHint()}</small>
    </span>
  </button>

  <section class="desk-card col-span-2 p-3">
    <h3 class="desk-eyebrow mb-2">{$LL.deskAppearance()}</h3>
    <div class="grid grid-cols-3 gap-1.5">
      {#each THEMES as t (t.id)}
        {@const Icon = t.icon}
        <button
          class="flex flex-col items-center gap-1 rounded-lg py-1.5 transition-colors {theme.current === t.id
            ? 'desk-chosen'
            : 'hover:bg-soft'}"
          aria-pressed={theme.current === t.id}
          onclick={() => theme.set(t.id)}
        >
          <Icon class="h-4 w-4" />
          <span class="text-[0.7rem]">{t.label()}</span>
        </button>
      {/each}
    </div>
    <div class="mt-3 flex flex-wrap gap-1.5">
      {#each ACCENTS as color (color)}
        <button
          class="h-5 w-5 rounded-full ring-offset-2 ring-offset-(--sb-white) transition-transform hover:scale-110"
          class:ring-2={(desk.prefs?.value.accent ?? ACCENTS[0]) === color}
          style:background={color}
          style:--tw-ring-color={color}
          aria-label={color}
          onclick={() => desk.prefs?.update({ accent: color === ACCENTS[0] ? null : color })}
        ></button>
      {/each}
    </div>
  </section>

  <section class="desk-card col-span-2 p-3">
    <h3 class="desk-eyebrow mb-2">{$LL.deskWallpaper()}</h3>
    <div class="grid grid-cols-4 gap-1.5">
      {#each WALLPAPERS as preset (preset)}
        <button
          class="relative aspect-[4/3] overflow-hidden rounded-md ring-offset-2 ring-offset-(--sb-white)"
          class:ring-2={desk.prefs?.preset === preset}
          style:--tw-ring-color="var(--desk-accent)"
          aria-label={preset}
          onclick={() => desk.prefs?.update({ wallpaper: `preset:${preset}` })}
        >
          <Wallpaper {preset} url={null} fit="cover" />
        </button>
      {/each}
    </div>
  </section>
</div>

<div class="mt-4">
  <button
    class="inline-flex items-center gap-1.5 rounded-lg bg-danger/10 px-3 py-1.5 text-[0.8rem] font-semibold text-danger transition-colors hover:bg-danger/15"
    onclick={() => {
      servers.logout(desk.entry.id)
      lock()
    }}
  >
    <LogOut class="h-3.5 w-3.5" />
    {$LL.logout()}
  </button>
</div>
