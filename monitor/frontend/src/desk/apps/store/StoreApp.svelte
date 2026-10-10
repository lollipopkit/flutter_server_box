<script lang="ts">
  /// The App Store: the web apps this agent can deploy (its catalog: shipped,
  /// the store's repositories, the operator's own folder), to
  /// browse by category or search, each with a page of its own
  /// (`StackDetail`: what it is, and for an admin installing, updating and
  /// uninstalling it).

  import { AppIcon, Badge, Card, Icon, IconButton, SearchField, SegmentedControl, Spinner } from '../../lk'
  import type { IconTone } from '../../lk'
  import { AppToolbar, PageStack, useWindow } from '../../sys'
  import StackDetail from '../../../components/stack/StackDetail.svelte'
  import { healthBadge } from '../../../components/stack/health'
  import { pick } from '../../../components/stack/text'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import type { StackApp } from '../../../types'
  import { untrack } from 'svelte'

  const win = useWindow()

  let apps = $state<StackApp[] | null>(null)
  let error = $state('')
  let query = $state('')
  let category = $state('all')
  /// The app whose page is open, kept with the window.
  let open = $state<string | null>(untrack(() => (win.appState as { app?: string } | null)?.app ?? null))
  let left = $state<string | null>(null)
  // Opened again on another app's page (a notification about it).
  $effect(() => {
    const asked = (win.appState as { app?: string } | null)?.app ?? null
    if (asked && asked !== untrack(() => open)) open = asked
  })

  let refreshing = $state(false)
  const admin = $derived(capabilitiesStore.byServer[servers.currentId]?.me?.admin === true)

  async function load(serverId = servers.currentId, fresh = false) {
    error = ''
    try {
      const r = fresh ? await api.refreshStacks() : await api.listStacks()
      if (serverId === servers.currentId) apps = r.apps
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  /// Reads the catalog's repositories now (admin).
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
    win.setAppState(id ? { app: id } : null)
    if (!id) void load()
  }

  const categories = $derived(['all', ...new Set((apps ?? []).flatMap((a) => a.manifest.categories))])
  const shown = $derived(
    (apps ?? []).filter((a) => {
      if (category !== 'all' && !a.manifest.categories.includes(category)) return false
      const q = query.trim().toLowerCase()
      if (!q) return true
      return [pick(a.manifest.title, $locale), a.manifest.project, pick(a.manifest.description, $locale), a.manifest.developer ?? '']
        .some((w) => w.toLowerCase().includes(q))
    }),
  )
  const current = $derived(apps?.find((a) => a.manifest.id === open) ?? null)

  function categoryText(c: string): string {
    const map: Record<string, () => string> = {
      all: $LL.storeAll,
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

<AppToolbar title={current ? pick(current.manifest.title, $locale) : undefined} back={open ? () => show(null) : undefined}>
  {#snippet actions()}
    {#if !open && admin}
      <IconButton icon="refresh" label={$LL.storeRefresh()} disabled={refreshing} onclick={() => void refresh()} />
    {/if}
    {#if !open}
      <SearchField bind:value={query} placeholder={$LL.storeSearch()} width={220} class="min-w-[90px]" />
    {/if}
  {/snippet}
</AppToolbar>

<PageStack
  key={open ?? 'home'}
  depth={open ? 1 : 0}
  back={open ? { key: 'home', go: () => show(null) } : null}
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
      {#if !apps}
        {#if !error}<div class="flex justify-center py-12"><Spinner size={48} /></div>{/if}
      {:else}
        {#if categories.length > 2}
          <SegmentedControl
            size="sm"
            label={$LL.storeCategories()}
            value={category}
            options={categories.map((c) => ({ value: c, label: categoryText(c) }))}
            onchange={(c) => (category = c)}
          />
        {/if}
        {#if shown.length === 0}
          <div class="flex flex-col items-center gap-[9px] py-[55px] text-(--text-tertiary)">
            <Icon name="storefront" size={48} />
            <p class="text-[13px]">{$LL.storeEmpty()}</p>
          </div>
        {:else}
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
        {/if}
      {/if}
    </main>
  {/if}
</PageStack>
