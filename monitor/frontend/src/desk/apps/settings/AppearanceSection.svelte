<script lang="ts">
  /// The desk's wallpaper (a preset, or one image the desk keeps) and how
  /// that image is fitted. This is the one section that touches the desk's
  /// preferences — see `useDeskPrefs`.

  import { Button, Card, Group, Row, SegmentedControl, Select, Spinner, Switch } from '../../lk'
  import { AppToolbar } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { ApiError } from '../../../lib/api'
  import { useDeskPrefs } from '../../deskState.svelte'
  import { WALLPAPERS, type WallpaperPreset } from '../../prefs.svelte'
  import { DOCK_SIZES, shellPrefs, type DockPosition, type DockSize, type TitlebarStyle } from '../../shellPrefs.svelte'
  import Wallpaper from '../../shell/Wallpaper.svelte'
  import ThemeToggle from './ThemeToggle.svelte'

  /// The agent's own limit (`api::desk`); checked here too, so an oversized
  /// file is refused before it travels.
  const MAX_WALLPAPER_BYTES = 8 * 1024 * 1024

  const FITS = $derived([
    { value: 'cover' as const, label: $LL.settingsFitCover() },
    { value: 'contain' as const, label: $LL.settingsFitContain() },
    { value: 'fill' as const, label: $LL.settingsFitFill() },
  ])

  const appearance = useDeskPrefs()
  const prefs = $derived(appearance.prefs)
  const value = $derived(prefs?.value ?? null)
  /// The preset in use, or null for the custom image.
  const preset = $derived(prefs?.preset ?? null)
  const custom = $derived(value?.wallpaper === 'custom')
  const fit = $derived(value?.wallpaper_fit ?? 'cover')

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

<main class="flex max-w-[560px] flex-col gap-[17px] pb-[21px] pl-[17px] pr-[21px] pt-[5px]">
  {#if !prefs}
    <div class="flex justify-center py-12"><Spinner size={48} /></div>
  {:else}
    <Group title={$LL.deskWallpaper()}>
      <div class="space-y-[13px] py-[13px]">

      <!-- The desk as it looks now, at 16:10: the wallpaper with a menubar
           and a dock drawn over it, so the choice is seen in place. -->
      <div class="relative aspect-[16/10] w-full overflow-hidden rounded-[13px] shadow-[inset_0_0_0_.5px_var(--border-hairline)]">
        <Wallpaper preset={preset} url={prefs.wallpaperUrl} fit={fit} />
        <div class="absolute inset-x-2 top-2 flex items-center gap-1.5 rounded-[9px] bg-(--glass-bar) px-[9px] py-[7px] backdrop-blur-sm">
          <span class="h-2 w-2 rounded-full bg-(--color-accent)"></span>
          <span class="h-1.5 w-12 rounded-full bg-white/50"></span>
          <span class="flex-1"></span>
          <span class="h-1.5 w-6 rounded-full bg-white/35"></span>
          <span class="h-1.5 w-4 rounded-full bg-white/35"></span>
        </div>
        <div class="absolute inset-x-0 bottom-2 flex justify-center">
          <div class="flex items-center gap-[7px] rounded-[17px] bg-black/30 px-[11px] py-[7px] backdrop-blur-sm">
            {#each [1, 0.85, 0.7, 0.55] as opacity (opacity)}
              <span class="h-4 w-4 rounded-[9px] bg-(--color-accent)" style:opacity={opacity}></span>
            {/each}
          </div>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-[9px] @2xl:grid-cols-4">
        {#each WALLPAPERS as name (name)}
          {@const active = !custom && preset === name}
          <Card
            onclick={() => prefs.update({ wallpaper: `preset:${name}` })}
            selected={active}
            class="cursor-default text-left"
            padding="5px"
          >
            <span class="relative block aspect-[16/10] overflow-hidden rounded-[9px]">
              <Wallpaper preset={name} url={null} fit="cover" />
            </span>
            <span class="mt-[5px] block truncate px-[3px] text-[12px] text-(--text-primary)">{presetName(name)}</span>
          </Card>
        {/each}
      </div>

      {#if prefs.remote}
        <input
          bind:this={fileInput}
          type="file"
          class="hidden"
          accept="image/png,image/jpeg,image/webp"
          onchange={choose}
        />
        <Row label={$LL.settingsWallpaperCustom()}>
          <div class="flex items-center gap-[7px]">
            {#if custom}<Button variant="secondary" size="sm" icon="delete" disabled={busy} onclick={remove}>{$LL.settingsWallpaperRemove()}</Button>{/if}
            <Button variant="tinted" size="sm" icon="upload" disabled={busy} onclick={() => fileInput?.click()}>
              {#if busy}<Spinner size={16} />{/if}
              {$LL.settingsWallpaperCustom()}
            </Button>
          </div>
        </Row>
      {/if}

      <Row label={$LL.settingsWallpaperFit()}>
        <Select
          class="w-[170px]"
          value={fit}
          disabled={!custom}
          options={FITS}
          onchange={(event: Event) => prefs.update({ wallpaper_fit: (event.currentTarget as HTMLSelectElement).value as typeof fit })}
        />
      </Row>

      {#if error}<p class="text-[13px] text-(--color-danger)" role="alert">{error}</p>{/if}
      </div>
    </Group>

    <Group title={$LL.deskAppearance()}>
      <Row label={$LL.theme()}>
        <ThemeToggle />
      </Row>
      <Row label={$LL.deskTitlebar()} sub={$LL.deskTitlebarHint()}>
        <SegmentedControl
          size="sm"
          label={$LL.deskTitlebar()}
          value={shellPrefs.titlebar}
          options={[
            { value: 'glass' as TitlebarStyle, label: $LL.deskTitlebarGlass() },
            { value: 'always' as TitlebarStyle, label: $LL.deskTitlebarAlways() },
          ]}
          onchange={(titlebar) => shellPrefs.set({ titlebar })}
        />
      </Row>
    </Group>

    <Group title={$LL.deskDock()}>
      <Row label={$LL.deskDockPosition()}>
        <SegmentedControl
          size="sm"
          label={$LL.deskDockPosition()}
          value={shellPrefs.dockPosition}
          options={[
            { value: 'left' as DockPosition, label: $LL.deskDockLeft() },
            { value: 'bottom' as DockPosition, label: $LL.deskDockBottom() },
            { value: 'right' as DockPosition, label: $LL.deskDockRight() },
          ]}
          onchange={(dockPosition) => shellPrefs.set({ dockPosition })}
        />
      </Row>
      <Row label={$LL.deskDockAutoHide()} sub={$LL.deskDockAutoHideHint()}>
        <Switch
          checked={shellPrefs.dockAutoHide}
          label={$LL.deskDockAutoHide()}
          onchange={(dockAutoHide: boolean) => shellPrefs.set({ dockAutoHide })}
        />
      </Row>
      <Row label={$LL.deskDockSize()}>
        <SegmentedControl
          size="sm"
          label={$LL.deskDockSize()}
          value={String(shellPrefs.dockSize)}
          options={DOCK_SIZES.map((size, i) => ({
            value: String(size),
            label: [$LL.deskSizeSmall(), $LL.deskSizeMedium(), $LL.deskSizeLarge()][i],
          }))}
          onchange={(v) => shellPrefs.set({ dockSize: Number(v) as DockSize })}
        />
      </Row>
    </Group>
  {/if}
</main>
