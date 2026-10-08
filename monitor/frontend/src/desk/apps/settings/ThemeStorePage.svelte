<script lang="ts">
  /// The theme store: the themes the ServerBox catalog's repositories offer,
  /// read by this server's agent (which fetches, checks each package's digest
  /// and installs it for this account).

  import { Button, Card, Icon, IconButton, Spinner } from '../../lk'
  import SettingsPage from './SettingsPage.svelte'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { useDeskPrefs } from '../../deskState.svelte'
  import type { StoreItem, ThemeStoreView } from '../../themes.svelte'
  import { fmtBytes } from '../../../lib/format'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()
  const appearance = useDeskPrefs()
  const themes = $derived(appearance.themes)

  let view = $state<ThemeStoreView | null>(null)
  let loading = $state(false)
  let error = $state('')
  /// The listing being installed, by id.
  let installing = $state<string | null>(null)
  let failed = $state<{ id: string; reason: string } | null>(null)

  async function load(refresh = false) {
    if (!themes) return
    loading = true
    error = ''
    try {
      view = await themes.store(refresh)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      loading = false
    }
  }

  $effect(() => {
    void load()
  })

  /// A listing's description in the panel's language: its full tag, then
  /// its language, then English, then whatever it has first.
  function describe(item: StoreItem): string {
    const d = item.listing.description
    if (typeof d === 'string') return d
    const tag = $locale.toLowerCase().replace('_', '-')
    const language = tag.split('-')[0]
    return d[tag] ?? d[language] ?? d.en ?? Object.values(d)[0] ?? ''
  }

  /// What installing this listing would do for this account.
  function stateOf(item: StoreItem): 'install' | 'update' | 'installed' | 'unavailable' {
    if (!item.release) return 'unavailable'
    const mine = themes?.installed.find((t) => t.id === item.listing.id)
    if (!mine) return 'install'
    return mine.installationId === item.release.sha256 ? 'installed' : 'update'
  }

  async function install(item: StoreItem) {
    if (!themes || !item.release) return
    installing = item.listing.id
    failed = null
    try {
      const installed = await themes.installFromStore(item, item.release.version)
      const first = installed.package.themes[0]
      if (first) themes.select(installed.installationId, first)
    } catch (e) {
      failed = { id: item.listing.id, reason: e instanceof Error ? e.message : String(e) }
    } finally {
      installing = null
    }
  }
</script>

<SettingsPage title={$LL.settingsThemeStore()} description={$LL.settingsThemeStoreDesc()} back={onback}>
  {#snippet actions()}
    <IconButton icon="refresh" label={$LL.refresh()} disabled={loading} onclick={() => void load(true)} />
  {/snippet}
  {#if !view && loading}
    <div class="flex justify-center py-12"><Spinner size={48} /></div>
  {:else if error && !view}
    <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} />{error}</Card>
  {:else if view}
    {#if view.items.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-12 text-(--text-tertiary)">
        <Icon name="storefront" size={55} weight={300} />
        <span class="text-[15px] font-bold text-(--text-secondary)">{$LL.settingsThemeStoreEmpty()}</span>
      </div>
    {/if}
    <div class="flex flex-col gap-[9px]">
      {#each view.items as item (`${item.repoUrl} ${item.listing.id}`)}
        {@const state = stateOf(item)}
        <Card class="flex flex-col gap-[7px]">
          <div class="flex items-start gap-[13px]">
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-baseline gap-x-[7px]">
                <span class="text-[15px] font-semibold">{item.listing.name}</span>
                {#if item.release}<span class="lk-num text-[12px] text-(--text-tertiary)">{item.release.version}</span>{/if}
              </div>
              <p class="text-[12px] text-(--text-tertiary)">
                {[$LL.settingsThemeStoreFrom({ repo: item.repo }), item.release?.size ? fmtBytes(item.release.size) : '', item.listing.license ?? '']
                  .filter(Boolean)
                  .join(' · ')}
              </p>
            </div>
            {#if state === 'installed'}
              <span class="flex items-center gap-[5px] text-[12px] font-semibold text-(--color-success)">
                <Icon name="check_circle" size={16} fill />{$LL.settingsThemeInstalled()}
              </span>
            {:else if state === 'unavailable'}
              <span class="text-[12px] text-(--text-tertiary)">{$LL.settingsThemeNeedsNewer()}</span>
            {:else}
              <Button
                size="sm"
                variant={state === 'update' ? 'tinted' : 'primary'}
                disabled={installing !== null}
                onclick={() => void install(item)}
              >
                {#if installing === item.listing.id}<Spinner size={16} />{/if}
                {state === 'update' ? $LL.settingsThemeUpdate() : $LL.settingsThemeGet()}
              </Button>
            {/if}
          </div>
          {#if describe(item)}<p class="text-[13px] text-(--text-secondary) [text-wrap:pretty]">{describe(item)}</p>{/if}
          {#if failed?.id === item.listing.id}
            <p class="text-[12px] text-(--color-danger)" role="alert">{failed.reason}</p>
          {/if}
        </Card>
      {/each}
    </div>
    {#if error}<p class="text-[13px] text-(--color-danger)" role="alert">{error}</p>{/if}
  {/if}
</SettingsPage>
