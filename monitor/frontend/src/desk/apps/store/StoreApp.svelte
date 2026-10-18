<script lang="ts">
  /// The App Store: the web apps this agent can deploy (its catalog: shipped,
  /// the store's repositories, the operator's own folder), browsed by the
  /// sidebar's places (all, recommended, installed, each category) or
  /// searched, each with a page of its own (`StackDetail`: what it is, and
  /// installing, updating and uninstalling it); and the desk apps the agent
  /// offers, a place of their own. A search looks through both.

  import { AppIcon, Badge, Card, Icon, IconButton, SearchField, SidebarItem, SidebarSection, Spinner } from '../../lk'

  import { errorText } from '../../../lib/errorText'
  import type { IconTone } from '../../lk'
  import { AppToolbar, PageStack, SplitView, useWindow } from '../../sys'
  import StackDetail from '../../../components/stack/StackDetail.svelte'
  import DeskPackages from './DeskPackages.svelte'
  import { healthBadge } from '../../../components/stack/health'
  import { pick } from '../../../components/stack/text'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { canAct } from '../../../lib/access'
  import { servers } from '../../../lib/servers.svelte'
  import type { StackApp } from '../../../types'
  import { untrack } from 'svelte'

  const win = useWindow()

  let apps = $state<StackApp[] | null>(null)
  let error = $state('')
  let query = $state('')
  type Kept = { app?: string; place?: string } | null
  /// The sidebar's place: `all`, `recommended`, `installed`, `desk` (the desk
  /// apps) or a category; kept with the window.
  let place = $state(untrack(() => (win.appState as Kept)?.place ?? 'all'))
  /// The app whose page is open, kept with the window.
  let open = $state<string | null>(untrack(() => (win.appState as Kept)?.app ?? null))
  let left = $state<string | null>(null)
  // Opened again on another app's page (a notification about it).
  $effect(() => {
    const asked = (win.appState as Kept)?.app ?? null
    if (asked && asked !== untrack(() => open)) open = asked
  })

  let refreshing = $state(false)
  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  /// Whether the account may act over this link: setting up, changing and
  /// removing all need it.
  const canChange = $derived(canAct(caps))

  async function load(serverId = servers.currentId, fresh = false) {
    error = ''
    try {
      const r = fresh ? await api.refreshStacks() : await api.listStacks()
      // Local inference's engines are set up in its own window.
      if (serverId === servers.currentId) apps = r.apps.filter((a) => a.source !== 'part')
    } catch (e) {
      error = errorText(e)
    }
  }

  /// Reads the catalog's repositories now.
  async function refresh() {
    refreshing = true
    await load(servers.currentId, true)
    refreshing = false
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  function show(id: string | null) {
    if (open && !id) left = open
    open = id
    win.setAppState(id ? { app: id, place } : { place })
    if (!id) void load()
  }

  function go(next: string) {
    place = next
    left = null
    show(null)
  }

  const categories = $derived([...new Set((apps ?? []).flatMap((a) => a.manifest.categories))].sort((a, b) => categoryText(a).localeCompare(categoryText(b))))
  const hasRecommended = $derived((apps ?? []).some((a) => a.manifest.recommended))
  const searching = $derived(query.trim() !== '')

  function inPlace(a: StackApp, at: string): boolean {
    switch (at) {
      case 'all':
        return true
      case 'recommended':
        return !!a.manifest.recommended
      case 'installed':
        return !!a.stack
      default:
        return a.manifest.categories.includes(at)
    }
  }

  const shown = $derived(
    (apps ?? []).filter((a) => {
      // A search looks through every web app, whatever place is chosen.
      if (!searching && !inPlace(a, place)) return false
      const q = query.trim().toLowerCase()
      if (!q) return true
      return [pick(a.manifest.title, $locale), a.manifest.project, pick(a.manifest.description, $locale), a.manifest.developer ?? '']
        .some((w) => w.toLowerCase().includes(q))
    }),
  )
  const current = $derived(apps?.find((a) => a.manifest.id === open) ?? null)

  const CATEGORY_ICONS: Record<string, string> = {
    photos: 'photo_library',
    media: 'movie',
    files: 'folder',
    documents: 'description',
    productivity: 'task_alt',
    development: 'code',
    ai: 'smart_toy',
    home: 'home',
    network: 'lan',
    monitoring: 'monitoring',
    security: 'shield',
    tools: 'build',
  }

  function placeText(at: string): string {
    if (at === 'installed') return $LL.stackInstalled()
    if (at === 'desk') return $LL.storeDeskApps()
    return categoryText(at)
  }

  function categoryText(c: string): string {
    const map: Record<string, () => string> = {
      all: $LL.storeAll,
      recommended: $LL.storeRecommended,
      photos: $LL.storeCategoryPhotos,
      media: $LL.storeCategoryMedia,
      files: $LL.storeCategoryFiles,
      documents: $LL.storeCategoryDocuments,
      productivity: $LL.storeCategoryProductivity,
      development: $LL.storeCategoryDevelopment,
      ai: $LL.storeCategoryAi,
      home: $LL.storeCategoryHome,
      network: $LL.storeCategoryNetwork,
      monitoring: $LL.storeCategoryMonitoring,
      security: $LL.storeCategorySecurity,
      tools: $LL.storeCategoryTools,
    }
    return map[c]?.() ?? c
  }

  function stateBadge(a: StackApp): { tone: 'success' | 'neutral' | 'danger'; text: string } | null {
    if (a.job?.state === 'running') return { tone: 'neutral', text: $LL.stackWorking() }
    if (!a.stack) return null
    if (a.stack.state === 'installed' && a.health && a.health.state !== 'healthy' && a.health.state !== 'starting') {
      return healthBadge(a.health.state, $LL)
    }
    if (a.stack.state === 'installed') return { tone: 'success', text: $LL.stackInstalled() }
    if (a.stack.state === 'failed') return { tone: 'danger', text: $LL.stackFailed() }
    return { tone: 'neutral', text: $LL.stackWorking() }
  }
</script>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection>
      <SidebarItem label={$LL.storeAll()} icon="apps" active={place === 'all'} trailing={apps?.length} onclick={() => go('all')} />
      {#if hasRecommended}
        <SidebarItem label={$LL.storeRecommended()} icon="star" active={place === 'recommended'} onclick={() => go('recommended')} />
      {/if}
      <SidebarItem
        label={$LL.stackInstalled()}
        icon="download_done"
        active={place === 'installed'}
        trailing={apps?.filter((a) => a.stack).length || undefined}
        onclick={() => go('installed')}
      />
    </SidebarSection>
    {#if categories.length}
      <SidebarSection title={$LL.storeCategories()}>
        {#each categories as c (c)}
          <SidebarItem label={categoryText(c)} icon={CATEGORY_ICONS[c] ?? 'category'} active={place === c} onclick={() => go(c)} />
        {/each}
      </SidebarSection>
    {/if}
    <SidebarSection title={$LL.storeExtend()}>
      <SidebarItem label={$LL.storeDeskApps()} icon="widgets" active={place === 'desk'} onclick={() => go('desk')} />
    </SidebarSection>
  {/snippet}

<AppToolbar title={current ? pick(current.manifest.title, $locale) : searching ? undefined : placeText(place)} back={open ? () => show(null) : undefined}>
  {#snippet actions()}
    {#if !open && canChange}
      <IconButton icon="refresh" label={$LL.storeRefresh()} disabled={refreshing} onclick={() => void refresh()} />
    {/if}
    {#if !open}
      <SearchField bind:value={query} placeholder={$LL.storeSearch()} width={220} class="min-w-[90px]" />
    {/if}
  {/snippet}
</AppToolbar>

<PageStack
  key={open ?? `home:${place}`}
  depth={open ? 1 : 0}
  back={open ? { key: `home:${place}`, go: () => show(null) } : null}
  forward={!open && left ? { key: left, go: () => show(left) } : null}
>
  {#if open}
    <main class="pane-reading pb-[21px] pt-[5px]">
      {#key open}<StackDetail stackId={open} />{/key}
    </main>
  {:else}
    <main class="pane-board space-y-[17px] pb-[21px] pt-[5px]">
      {#if error}
        <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
          <Icon name="error" size={17} />
          <p>{error}</p>
        </Card>
      {/if}
      {#if place === 'desk' || searching}
        <DeskPackages {query} {canChange} heading={searching} />
      {/if}
      {#if place !== 'desk' || searching}
        {#if !apps}
          {#if !error}<div class="flex justify-center py-12"><Spinner size={48} /></div>{/if}
        {:else if shown.length === 0}
          {#if !searching}
            <div class="flex flex-col items-center gap-[9px] py-[55px] text-(--text-tertiary)">
              <Icon name="storefront" size={48} />
              <p class="text-[13px]">{$LL.storeEmpty()}</p>
            </div>
          {/if}
        {:else}
          <section class="space-y-[9px]">
            {#if searching}<h3 class="lk-caps text-(--text-secondary)">{$LL.storeWebApps()}</h3>{/if}
            <div class="grid grid-cols-1 gap-[13px] @2xl:grid-cols-2 @5xl:grid-cols-3">
              {#each shown as a (a.manifest.id)}
                {@const badge = stateBadge(a)}
                <button class="text-left" onclick={() => show(a.manifest.id)}>
                  <Card variant="raised" class="flex h-full items-start gap-[13px] transition-transform active:scale-[0.98]">
                    <AppIcon glyph={a.manifest.glyph} tone={a.manifest.tone as IconTone} size={52} />
                    <div class="min-w-0 flex-1 space-y-[3px]">
                      <div class="flex items-center gap-[7px]">
                        <span class="truncate text-[15px] font-semibold text-(--text-primary)">{pick(a.manifest.title, $locale)}</span>
                        {#if badge}<Badge tone={badge.tone}>{badge.text}</Badge>{/if}
                        {#if a.source === 'local'}<Badge tone="neutral">{$LL.storeLocal()}</Badge>{/if}
                      </div>
                      <p class="truncate text-[12px] text-(--text-tertiary)">
                        {a.manifest.project}{#if a.manifest.developer}{` · ${a.manifest.developer}`}{/if}
                      </p>
                      <p class="line-clamp-2 text-[13px] text-(--text-secondary)">{pick(a.manifest.description, $locale)}</p>
                    </div>
                  </Card>
                </button>
              {/each}
            </div>
          </section>
        {/if}
      {/if}
    </main>
  {/if}
</PageStack>
</SplitView>
