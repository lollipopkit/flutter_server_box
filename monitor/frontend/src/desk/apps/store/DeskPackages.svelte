<script lang="ts">
  /// Desk apps the agent offers (`GET /apps/catalog`: shipped, and the
  /// store's), each a card naming who published it (the first-party
  /// signature, or an unknown publisher) and whether it is installed; a card
  /// opens the app's page (`DeskPackageDetail`), where it is installed,
  /// updated, opened and uninstalled.

  import { AppIcon, Badge, Card } from '../../lk'
  import type { IconTone } from '../../lk'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { errorText } from '../../../lib/errorText'
  import type { InstalledApp, OfferedApp } from '../../../types'
  import { standing, textOf } from './deskPackage'

  interface Props {
    /// Search words, as the store's field has them.
    query: string
    /// Titled, beside the web apps (a search); untitled on a page of its own.
    heading?: boolean
    /// Read again whenever it changes (the store read its catalogs).
    revision?: number
    onopen: (id: string) => void
  }

  const { query, heading = false, revision = 0, onopen }: Props = $props()

  let offered = $state<OfferedApp[]>([])
  let installed = $state<InstalledApp[]>([])
  let error = $state('')

  async function load() {
    try {
      const [c, i] = await Promise.all([api.appCatalog(), api.listApps()])
      offered = c.apps
      installed = i.apps
      error = ''
    } catch (e) {
      error = errorText(e)
    }
  }

  $effect(() => {
    void revision
    void load()
  })

  const shown = $derived(
    offered.filter((o) => {
      const q = query.trim().toLowerCase()
      const words = [textOf(o.manifest.title, $locale), o.id, ...(o.manifest.keywords ?? [])]
      if (o.manifest.description) words.push(textOf(o.manifest.description, $locale))
      return !q || words.some((w) => w.toLowerCase().includes(q))
    }),
  )
</script>

{#if error}
  <p class="text-[13px] text-(--color-danger)">{error}</p>
{/if}
{#if shown.length}
  <section class="space-y-[9px]">
    {#if heading}<h3 class="lk-caps text-(--text-secondary)">{$LL.storeDeskApps()}</h3>{/if}
    <div class="grid grid-cols-1 gap-[13px] @2xl:grid-cols-2 @5xl:grid-cols-3">
      {#each shown as o (o.id)}
        {@const s = standing(o, installed)}
        <button class="text-left" onclick={() => onopen(o.id)}>
          <Card variant="raised" class="flex h-full items-start gap-[13px] transition-transform active:scale-[0.98]">
            <AppIcon glyph={o.manifest.glyph} tone={o.manifest.tone as IconTone} size={52} />
            <div class="min-w-0 flex-1 space-y-[3px]">
              <div class="flex items-center gap-[7px]">
                <span class="truncate text-[15px] font-semibold text-(--text-primary)">{textOf(o.manifest.title, $locale)}</span>
                {#if s === 'current'}<Badge tone="success">{$LL.stackInstalled()}</Badge>{/if}
                {#if s === 'waiting'}<Badge tone="warning" dot>{$LL.settingsAppWaiting()}</Badge>{/if}
                {#if s === 'update'}<Badge tone="accent">{$LL.storeDeskUpdate()}</Badge>{/if}
              </div>
              <p class="truncate text-[12px] text-(--text-tertiary)">
                {o.signedBy ? $LL.storeFirstParty() : $LL.storeUnknownPublisher()} · {o.version}
              </p>
              {#if o.manifest.description}
                <p class="line-clamp-2 text-[13px] text-(--text-secondary)">{textOf(o.manifest.description, $locale)}</p>
              {/if}
            </div>
          </Card>
        </button>
      {/each}
    </div>
  </section>
{/if}
