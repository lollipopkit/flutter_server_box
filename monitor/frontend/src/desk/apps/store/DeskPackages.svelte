<script lang="ts">
  /// Desk apps the agent offers (`GET /apps/catalog`: shipped, and the
  /// store's): who published each (the first-party signature, or an unknown
  /// publisher), installed or not, and Install / Update / Approve, which
  /// installs the package as an upload is and approves exactly what it asks
  /// for with the account's password; Open once it is there.

  import { AppIcon, Badge, Button, Card } from '../../lk'
  import type { IconTone } from '../../lk'
  import { useWindow } from '../../sys'
  import ReauthDialog from '../../../components/ReauthDialog.svelte'
  import { pick } from '../../../components/stack/text'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { permissionText } from '../../../lib/appPermissions'
  import { errorText } from '../../../lib/errorText'
  import type { InstalledApp, OfferedApp } from '../../../types'

  interface Props {
    /// Search words, as the store's field has them.
    query: string
    /// Whether the account may act over this link.
    canChange: boolean
    /// Titled, beside the web apps (a search); untitled on a page of its own.
    heading?: boolean
  }

  const { query, canChange, heading = false }: Props = $props()
  const win = useWindow()

  let offered = $state<OfferedApp[]>([])
  let installed = $state<InstalledApp[]>([])
  let error = $state('')
  let asking = $state<OfferedApp | null>(null)

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
    void load()
  })

  const titleOf = (o: OfferedApp) => pick(typeof o.manifest.title === 'string' ? { en: o.manifest.title } : o.manifest.title, $locale)

  const shown = $derived(
    offered.filter((o) => {
      const q = query.trim().toLowerCase()
      return !q || [titleOf(o), o.id, ...(o.manifest.keywords ?? [])].some((w) => w.toLowerCase().includes(q))
    }),
  )

  /// Where [o] stands here: not installed, the same package (approved or
  /// waiting), or another version.
  function standing(o: OfferedApp): 'none' | 'current' | 'waiting' | 'update' {
    const i = installed.find((a) => a.id === o.id)
    if (!i) return 'none'
    if (i.sha256 !== o.sha256) return 'update'
    return i.approved_permissions ? 'current' : 'waiting'
  }

  const message = $derived.by(() => {
    if (!asking) return ''
    const name = titleOf(asking)
    const asks = asking.manifest.permissions.map((p) => permissionText($LL, p))
    const what = asks.length ? $LL.settingsAppApproveMessage({ name, permissions: asks.join(', ') }) : $LL.settingsAppApproveBare({ name })
    const who = asking.signedBy ? '' : ` ${$LL.storeUnknownPublisherNote()}`
    return `${what} ${$LL.settingsAppApproveRisk()}${who}`
  })

  async function confirm(password: string) {
    const o = asking
    if (!o) return
    const i = installed.find((a) => a.id === o.id)
    const app = i && i.sha256 === o.sha256 ? i : await api.installOffered(o.id)
    await api.approveApp(app.id, app.sha256, app.manifest.permissions, password)
    await load()
    await win.reloadApps()
  }
</script>

{#if error}
  <p class="text-[13px] text-(--color-danger)">{error}</p>
{/if}
{#if shown.length}
  <section class="space-y-[9px]">
    {#if heading}<h3 class="lk-caps text-(--text-secondary)">{$LL.storeDeskApps()}</h3>{/if}
    <div class="grid grid-cols-1 gap-[13px] @2xl:grid-cols-2 @5xl:grid-cols-3">
      {#each shown as o (o.id)}
        {@const s = standing(o)}
        <Card variant="raised" class="flex h-full items-start gap-[13px]">
          <AppIcon glyph={o.manifest.glyph} tone={o.manifest.tone as IconTone} size={52} />
          <div class="min-w-0 flex-1 space-y-[5px]">
            <div class="flex flex-wrap items-center gap-[7px]">
              <span class="truncate text-[15px] font-semibold text-(--text-primary)">{titleOf(o)}</span>
              {#if s === 'current'}<Badge tone="success">{$LL.stackInstalled()}</Badge>{/if}
              {#if s === 'waiting'}<Badge tone="warning" dot>{$LL.settingsAppWaiting()}</Badge>{/if}
            </div>
            <p class="truncate text-[12px] text-(--text-tertiary)">
              {o.signedBy ? $LL.storeFirstParty() : $LL.storeUnknownPublisher()} · {o.version}
            </p>
            <p class="line-clamp-2 text-[12px] text-(--text-secondary)">{o.manifest.permissions.map((p) => permissionText($LL, p)).join(', ')}</p>
            <div class="flex flex-wrap gap-[7px] pt-[3px]">
              {#if s === 'current'}
                <Button size="sm" variant="secondary" onclick={() => win.open(o.id)}>{$LL.stackOpen()}</Button>
              {:else if canChange}
                <Button size="sm" variant="primary" onclick={() => (asking = o)}>
                  {s === 'update' ? $LL.stackUpdate({ version: o.version }) : s === 'waiting' ? $LL.settingsAppApprove() : $LL.storeInstall()}
                </Button>
              {/if}
            </div>
          </div>
        </Card>
      {/each}
    </div>
  </section>
{/if}

<ReauthDialog open={asking !== null} {message} onconfirm={confirm} onclose={() => (asking = null)} />
