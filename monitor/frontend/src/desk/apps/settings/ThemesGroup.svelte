<script lang="ts">
  /// The theme packages (`.fsbt`) this account installed on the agent: which
  /// one the desk is drawn with (one row per package, or per variant), one
  /// installed from a file, and the way to the store.

  import { Button, Group, Icon, IconButton, Radio, Row, Spinner } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { css, themeDark, themeValue, type DeskThemes, type InstalledTheme, type PackageTheme } from '../../themes.svelte'
  import { theme as mode } from '../../../lib/theme.svelte'

  interface Props {
    themes: DeskThemes
    /// The value of the theme the desk is drawn with, or null.
    selected: string | null
    onstore: () => void
  }

  const { themes, selected, onstore }: Props = $props()

  let busy = $state(false)
  let error = $state('')
  let fileInput = $state<HTMLInputElement | null>(null)

  /// What a choice is called: `Pride · Trans` for a variant.
  function labelOf(pkg: InstalledTheme, theme: PackageTheme): string {
    return theme.variant ? `${pkg.name} · ${theme.variant.name}` : pkg.name
  }

  function modeNote(theme: PackageTheme): string | undefined {
    if (theme.modes.length !== 1) return undefined
    return theme.modes[0] === 'dark' ? $LL.settingsThemeDarkOnly() : $LL.settingsThemeLightOnly()
  }

  async function choose(event: Event) {
    const input = event.currentTarget as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (!file) return
    error = ''
    busy = true
    try {
      const installed = await themes.install(file)
      const first = installed.package.themes[0]
      if (first) themes.select(installed.installationId, first)
    } catch (e) {
      error = $LL.settingsThemeRefused({ reason: e instanceof Error ? e.message : String(e) })
    } finally {
      busy = false
    }
  }

  async function remove(pkg: InstalledTheme) {
    error = ''
    busy = true
    try {
      await themes.remove(pkg.installationId)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
  }
</script>

<Group title={$LL.settingsThemePackages()}>
  <Row label={$LL.settingsThemeDefault()} sub={$LL.settingsThemeDefaultHint()}>
    <Radio name="desk-theme" value="" group={selected ?? ''} onchange={() => themes.select(null, null)} aria-label={$LL.settingsThemeDefault()} />
  </Row>
  {#each themes.installed as pkg (pkg.installationId)}
    {#each pkg.package.themes as theme, i (theme.variant?.key ?? i)}
      {@const value = themeValue(pkg.installationId, theme)}
      {@const scheme = themeDark(theme, mode.dark) ? theme.schemeDark : theme.schemeLight}
      <Row label={labelOf(pkg, theme)} sub={modeNote(theme)}>
        {#snippet leading()}
          <!-- The theme in two dots: its accent over its surface, in the
               brightness it would be drawn in. -->
          <span
            class="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-full shadow-[inset_0_0_0_.5px_var(--border-strong)]"
            style:background={css(scheme.surface)}
            aria-hidden="true"
          >
            <span class="h-[13px] w-[13px] rounded-full" style:background={css(scheme.primary)}></span>
          </span>
        {/snippet}
        <div class="flex items-center gap-[7px]">
          {#if i === 0}
            <IconButton icon="delete" size="sm" label={$LL.settingsThemeRemove({ name: pkg.name })} disabled={busy} onclick={() => void remove(pkg)} />
          {/if}
          <Radio
            name="desk-theme"
            {value}
            group={selected ?? ''}
            onchange={() => themes.select(pkg.installationId, theme)}
            aria-label={labelOf(pkg, theme)}
          />
        </div>
      </Row>
    {/each}
  {/each}
  <input bind:this={fileInput} type="file" class="hidden" accept=".fsbt,application/zip" onchange={choose} />
  <Row label={$LL.settingsThemeInstall()}>
    <div class="flex items-center gap-[7px]">
      <Button variant="secondary" size="sm" icon="upload_file" disabled={busy} onclick={() => fileInput?.click()}>
        {#if busy}<Spinner size={16} />{/if}
        {$LL.settingsThemeInstallFile()}
      </Button>
      <Button variant="tinted" size="sm" icon="storefront" onclick={onstore}>{$LL.settingsThemeStore()}</Button>
    </div>
  </Row>
  {#if error}
    <p class="flex items-start gap-[7px] py-[9px] text-[13px] text-(--color-danger)" role="alert">
      <Icon name="error" size={17} />{error}
    </p>
  {/if}
</Group>
