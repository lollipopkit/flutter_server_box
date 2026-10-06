<script lang="ts">
  import { BellOff, LockKeyhole, Monitor, Moon, Settings, Sun } from '@lucide/svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { theme, type Theme } from '../../lib/theme.svelte'
  import { useDesk } from '../deskState.svelte'
  import { ACCENTS, WALLPAPERS } from '../prefs.svelte'
  import Wallpaper from './Wallpaper.svelte'

  interface Props {
    onlock: () => void
  }

  const { onlock }: Props = $props()
  const desk = useDesk()

  const THEMES: { id: Theme; icon: typeof Sun; label: () => string }[] = [
    { id: 'light', icon: Sun, label: () => $LL.deskThemeLight() },
    { id: 'dark', icon: Moon, label: () => $LL.deskThemeDark() },
    { id: 'system', icon: Monitor, label: () => $LL.deskThemeSystem() },
  ]
</script>

<div class="space-y-3 p-3 text-[0.8rem]">
  <div class="grid grid-cols-2 gap-2">
    <button
      class="desk-hover flex items-center gap-2 rounded-xl p-2.5 text-left"
      style:background="hsl(var(--ink) / 0.06)"
      aria-pressed={desk.notifications?.dnd ?? false}
      onclick={() => desk.notifications?.setDnd(!desk.notifications.dnd)}
    >
      <span
        class="grid h-7 w-7 place-items-center rounded-full"
        class:desk-selected={desk.notifications?.dnd}
        style:background={desk.notifications?.dnd ? undefined : 'hsl(var(--ink) / 0.12)'}
      >
        <BellOff class="h-3.5 w-3.5" />
      </span>
      <span class="font-medium">{$LL.deskDnd()}</span>
    </button>
    <button
      class="desk-hover flex items-center gap-2 rounded-xl p-2.5 text-left"
      style:background="hsl(var(--ink) / 0.06)"
      onclick={() => {
        desk.panel = null
        onlock()
      }}
    >
      <span class="grid h-7 w-7 place-items-center rounded-full" style:background="hsl(var(--ink) / 0.12)">
        <LockKeyhole class="h-3.5 w-3.5" />
      </span>
      <span class="font-medium">{$LL.deskLock()}</span>
    </button>
  </div>

  <section class="rounded-xl p-2.5" style:background="hsl(var(--ink) / 0.06)">
    <h3 class="desk-muted mb-2 text-[0.65rem] font-bold uppercase tracking-wider">{$LL.deskAppearance()}</h3>
    <div class="grid grid-cols-3 gap-1">
      {#each THEMES as t (t.id)}
        {@const Icon = t.icon}
        <button
          class="desk-hover flex flex-col items-center gap-1 rounded-lg py-1.5"
          class:desk-selected={theme.current === t.id}
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
          class="h-5 w-5 rounded-full ring-offset-1 transition-transform hover:scale-110"
          class:ring-2={(desk.prefs?.value.accent ?? ACCENTS[0]) === color}
          style:background={color}
          style:--tw-ring-color={color}
          aria-label={color}
          onclick={() => desk.prefs?.update({ accent: color === ACCENTS[0] ? null : color })}
        ></button>
      {/each}
    </div>
  </section>

  <section class="rounded-xl p-2.5" style:background="hsl(var(--ink) / 0.06)">
    <h3 class="desk-muted mb-2 text-[0.65rem] font-bold uppercase tracking-wider">{$LL.deskWallpaper()}</h3>
    <div class="grid grid-cols-4 gap-1.5">
      {#each WALLPAPERS as preset (preset)}
        <button
          class="relative aspect-[4/3] overflow-hidden rounded-md ring-offset-1"
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

  <button
    class="desk-hover flex w-full items-center gap-2 px-2 py-1.5"
    onclick={() => desk.open('settings', { appState: { section: 'appearance' } })}
  >
    <Settings class="h-4 w-4" />
    {$LL.deskMoreSettings()}
  </button>
</div>
