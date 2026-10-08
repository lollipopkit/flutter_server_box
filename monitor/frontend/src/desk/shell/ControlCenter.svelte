<script lang="ts">
  import { LL } from '../../i18n/i18n-svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName } from '../../lib/servers.svelte'
  import { theme } from '../../lib/theme.svelte'
  import { useDesk } from '../deskState.svelte'
  import ControlTile from '../lk/ControlTile.svelte'
  import IconButton from '../lk/IconButton.svelte'
  import AppIcon from './AppIcon.svelte'
  import { app } from '../registry.svelte'
  import { WALLPAPERS } from '../prefs.svelte'
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
  /// Apps with a window running out of sight, each once.
  const background = $derived(
    [...new Set(desk.inBackground.map((w) => w.appId))].map((id) => app(id)).filter((a) => a !== undefined),
  )
</script>

<div class="grid grid-cols-2 gap-[9px]">
  <ControlTile
    icon="dns"
    label={serverLabel}
    detail={desk.storage?.remote ? (desk.live ? $LL.deskLiveShort() : $LL.deskOfflineShort()) : $LL.settingsThisBrowser()}
    on={!desk.storage?.remote || desk.live}
    onclick={() => desk.open('status')}
  />
  <ControlTile
    icon="dark_mode"
    label={$LL.deskThemeDark()}
    detail={theme.current === 'system' ? $LL.deskThemeSystem() : theme.dark ? $LL.deskOn() : $LL.deskOff()}
    on={theme.dark}
    ontoggle={(on) => theme.set(on ? 'dark' : 'light')}
  />
  <ControlTile
    icon="do_not_disturb_on"
    label={$LL.deskDnd()}
    detail={dnd ? $LL.deskOn() : $LL.deskOff()}
    on={dnd}
    ontoggle={(on) => desk.notifications?.setDnd(on)}
  />
  <ControlTile
    icon="lock"
    label={$LL.deskLock()}
    detail={$LL.deskLockHint()}
    onclick={() => {
      desk.panel = null
      onlock()
    }}
  />
  <div class="lk-ctile lk-ctile--col col-span-2">
    <div class="lk-ctile__label">{$LL.deskWallpaper()}</div>
    <div class="grid grid-cols-4 gap-[7px]">
      {#each WALLPAPERS as preset (preset)}
        <button
          class="wall relative aspect-[4/3] overflow-hidden rounded-[var(--radius-sm)]"
          aria-label={preset}
          aria-pressed={desk.prefs?.preset === preset}
          onclick={() => desk.prefs?.update({ wallpaper: `preset:${preset}` })}
        >
          <Wallpaper {preset} url={null} fit="cover" />
        </button>
      {/each}
    </div>
  </div>
  {#if background.length > 0}
    <div class="lk-ctile lk-ctile--col col-span-2">
      <div class="lk-ctile__label">{$LL.deskInBackground()}</div>
      {#each background as spec (spec.id)}
        <div class="flex items-center gap-[9px]">
          <AppIcon {spec} size={22} />
          <span class="min-w-0 flex-1 truncate text-[13px]">{spec.title($LL)}</span>
          <IconButton
            icon="stop_circle"
            size="sm"
            label="{$LL.deskQuit()} {spec.title($LL)}"
            onclick={() => desk.windows.closeApp(spec.id)}
          />
        </div>
      {/each}
    </div>
  {/if}
  <ControlTile
    class="col-span-2"
    icon="settings"
    label={$LL.deskAppSettings()}
    detail={$LL.deskSettingsHint()}
    onclick={() => desk.open('settings', { appState: { section: 'appearance' } })}
  />
</div>

<style>
  .wall {
    padding: 0;
    border: 0;
    box-shadow: inset 0 0 0 0.5px var(--border-hairline);
    transition: transform var(--dur-slow) var(--ease-spring-bouncy);
  }
  .wall:active {
    transform: scale(0.95);
  }
  .wall[aria-pressed='true'] {
    box-shadow:
      0 0 0 2px var(--color-accent),
      0 0 0 4px color-mix(in srgb, var(--color-accent) 25%, transparent);
  }
  .wall:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
