<script lang="ts">
  /// The desk's own look: the accent, the wallpaper (a preset, or one image
  /// the desk keeps) and how that image is fitted. This is the one section
  /// that touches the desk's preferences — see `useDeskAppearance`.

  import { ImageUp, Trash2 } from '@lucide/svelte'
  import { Button, Card, Spinner } from '@serverbox/webui'
  import { LL } from '../../../i18n/i18n-svelte'
  import { ApiError } from '../../../lib/api'
  import { useDeskAppearance } from '../../deskState.svelte'
  import { ACCENTS, WALLPAPERS, type WallpaperPreset } from '../../prefs.svelte'
  import Wallpaper from '../../shell/Wallpaper.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import ThemeToggle from './ThemeToggle.svelte'

  /// The agent's own limit (`api::desk`); checked here too, so an oversized
  /// file is refused before it travels.
  const MAX_WALLPAPER_BYTES = 8 * 1024 * 1024

  const FITS = [
    { value: 'cover' as const, label: () => $LL.settingsFitCover() },
    { value: 'contain' as const, label: () => $LL.settingsFitContain() },
    { value: 'fill' as const, label: () => $LL.settingsFitFill() },
  ]

  /// A selected swatch or preset reads as chosen through the accent itself,
  /// not a fixed highlight.
  const ACCENT_TINT = 'color-mix(in srgb, var(--desk-accent) 14%, transparent)'

  const appearance = useDeskAppearance()
  const prefs = $derived(appearance.prefs)
  const value = $derived(prefs?.value ?? null)
  /// The preset in use, or null for the custom image.
  const preset = $derived(prefs?.preset ?? null)
  const custom = $derived(value?.wallpaper === 'custom')
  const fit = $derived(value?.wallpaper_fit ?? 'cover')
  const accent = $derived(value?.accent ?? null)
  const accentColor = $derived(accent ?? ACCENTS[0])

  let busy = $state(false)
  let error = $state('')
  let fileInput = $state<HTMLInputElement | null>(null)

  /// The agent answers `tooLarge` or `notAnImage` for the two refusals it
  /// makes itself; anything else is its own message.
  function wallpaperError(e: unknown): string {
    if (e instanceof ApiError) {
      if (e.code === 'tooLarge') return $LL.settingsWallpaperTooLarge()
      if (e.code === 'notAnImage') return $LL.settingsWallpaperNotImage()
      return e.message
    }
    return String(e)
  }

  async function choose(event: Event) {
    const input = event.currentTarget as HTMLInputElement
    const file = input.files?.[0]
    // Cleared so picking the same file again still fires a change.
    input.value = ''
    if (!file || !prefs) return
    error = ''
    if (file.size > MAX_WALLPAPER_BYTES) {
      error = $LL.settingsWallpaperTooLarge()
      return
    }
    busy = true
    try {
      await prefs.setCustomWallpaper(file)
    } catch (e) {
      error = wallpaperError(e)
    } finally {
      busy = false
    }
  }

  async function remove() {
    if (!prefs) return
    error = ''
    busy = true
    try {
      await prefs.removeCustomWallpaper()
    } catch (e) {
      error = wallpaperError(e)
    } finally {
      busy = false
    }
  }

  /// The presets' ids are their names.
  function presetName(name: WallpaperPreset): string {
    return name[0].toUpperCase() + name.slice(1)
  }
</script>

<AppToolbar title={$LL.deskAppearance()} />

<main class="mx-auto max-w-3xl space-y-4 px-4 py-4 @3xl:px-6">
  {#if !prefs}
    <div class="flex justify-center py-12"><Spinner size="lg" /></div>
  {:else}
    <Card class="space-y-4">
      <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.deskWallpaper()}</h2>

      <!-- The desk as it looks now, at 16:10: the wallpaper with a menubar
           and a dock drawn over it, so the choice is seen in place. -->
      <div class="relative aspect-[16/10] w-full overflow-hidden rounded-2xl border border-line">
        <Wallpaper preset={preset} url={prefs.wallpaperUrl} fit={fit} />
        <div class="absolute inset-x-2 top-2 flex items-center gap-1.5 rounded-lg bg-black/25 px-2 py-1.5 backdrop-blur-sm">
          <span class="h-2 w-2 rounded-full" style:background={accentColor}></span>
          <span class="h-1.5 w-12 rounded-full bg-white/50"></span>
          <span class="flex-1"></span>
          <span class="h-1.5 w-6 rounded-full bg-white/35"></span>
          <span class="h-1.5 w-4 rounded-full bg-white/35"></span>
        </div>
        <div class="absolute inset-x-0 bottom-2 flex justify-center">
          <div class="flex items-center gap-1.5 rounded-2xl bg-black/30 px-2.5 py-1.5 backdrop-blur-sm">
            {#each [1, 0.85, 0.7, 0.55] as opacity (opacity)}
              <span class="h-4 w-4 rounded-lg" style:background={accentColor} style:opacity={opacity}></span>
            {/each}
          </div>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2 @2xl:grid-cols-4">
        {#each WALLPAPERS as name (name)}
          {@const active = !custom && preset === name}
          <button
            type="button"
            class="rounded-xl border border-line p-1 text-left transition-colors hover:bg-soft"
            style:border-color={active ? 'var(--desk-accent)' : null}
            style:background={active ? ACCENT_TINT : null}
            aria-pressed={active}
            onclick={() => prefs.update({ wallpaper: `preset:${name}` })}
          >
            <span class="relative block aspect-[16/10] overflow-hidden rounded-lg">
              <Wallpaper preset={name} url={null} fit="cover" />
            </span>
            <span class="mt-1 block truncate px-0.5 text-xs" class:text-fg-strong={active}>{presetName(name)}</span>
          </button>
        {/each}
      </div>

      <div class="flex flex-wrap items-center gap-2">
        {#if prefs.remote}
          <input
            bind:this={fileInput}
            type="file"
            class="hidden"
            accept="image/png,image/jpeg,image/webp"
            onchange={choose}
          />
          <Button variant="secondary" size="sm" disabled={busy} onclick={() => fileInput?.click()}>
            {#if busy}<Spinner class="w-4 h-4" />{:else}<ImageUp class="w-4 h-4" />{/if}
            {$LL.settingsWallpaperCustom()}
          </Button>
        {/if}
        {#if custom}
          <Button variant="secondary" size="sm" disabled={busy} onclick={remove}>
            <Trash2 class="w-4 h-4" />{$LL.settingsWallpaperRemove()}
          </Button>
        {/if}
      </div>

      <div class="space-y-1">
        <span class="block text-sm text-muted-fg">{$LL.settingsWallpaperFit()}</span>
        <div class="inline-flex items-center gap-0.5 rounded-lg border border-line p-0.5" class:opacity-50={!custom}>
          {#each FITS as option (option.value)}
            <button
              type="button"
              disabled={!custom}
              class="rounded-md px-2.5 py-1 text-xs text-muted-fg transition-colors hover:text-fg disabled:cursor-not-allowed"
              class:text-fg-strong={fit === option.value}
              style:background={fit === option.value ? ACCENT_TINT : null}
              aria-pressed={fit === option.value}
              onclick={() => prefs.update({ wallpaper_fit: option.value })}
            >
              {option.label()}
            </button>
          {/each}
        </div>
      </div>

      {#if error}
        <p class="text-sm text-danger">{error}</p>
      {/if}
    </Card>

    <Card class="space-y-4">
      <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.settingsAccent()}</h2>
      <div class="flex flex-wrap items-center gap-2">
        {#each ACCENTS as swatch, i (swatch)}
          {@const isDefault = i === 0}
          {@const selected = accentColor === swatch}
          <button
            type="button"
            class="h-7 w-7 rounded-full border border-line transition-transform hover:scale-105"
            style:background={swatch}
            style:box-shadow={selected ? '0 0 0 2px var(--color-surface), 0 0 0 4px var(--color-fg-strong)' : null}
            aria-pressed={selected}
            aria-label={isDefault ? $LL.settingsAccentDefault() : swatch}
            title={isDefault ? $LL.settingsAccentDefault() : swatch}
            onclick={() => prefs.update({ accent: isDefault ? null : swatch })}
          ></button>
        {/each}
      </div>
      <p class="text-xs text-faint-fg">{$LL.settingsAccentNote()}</p>
      <div class="space-y-1">
        <span class="block text-sm text-muted-fg">{$LL.theme()}</span>
        <ThemeToggle />
      </div>
    </Card>
  {/if}
</main>
