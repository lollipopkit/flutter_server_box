<script lang="ts">
  /// One desk app package's page in the App Store: what it is and does, who
  /// published it, the version offered and the one installed, where it comes
  /// from, the systems it is for and every permission it asks; Open, Install,
  /// Update, Approve and Uninstall, each with the account's password where it
  /// installs or removes. A first-party app the agent ships is installed on
  /// its own; uninstalled here, it stays so until installed here again.

  import { AppIcon, Badge, Button, Card, Group, Icon, Row, Spinner } from '../../lk'
  import type { IconTone } from '../../lk'
  import { useWindow } from '../../sys'
  import ReauthDialog from '../../../components/ReauthDialog.svelte'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { permissionText } from '../../../lib/appPermissions'
  import { errorText } from '../../../lib/errorText'
  import { DATE_TIME, fmtBytes, fmtDate } from '../../../lib/format'
  import type { InstalledApp, OfferedApp } from '../../../types'
  import { standing, textOf } from './deskPackage'

  interface Props {
    id: string
    /// Whether the account may act over this link.
    canChange: boolean
  }

  const { id, canChange }: Props = $props()
  const win = useWindow()

  let offered = $state<OfferedApp | null>(null)
  let installed = $state<InstalledApp | null>(null)
  let loaded = $state(false)
  let error = $state('')
  let asking = $state<'install' | 'remove' | null>(null)

  async function load() {
    try {
      const [c, i] = await Promise.all([api.appCatalog(), api.listApps()])
      offered = c.apps.find((a) => a.id === id) ?? null
      installed = i.apps.find((a) => a.id === id) ?? null
      error = ''
    } catch (e) {
      error = errorText(e)
    } finally {
      loaded = true
    }
  }

  $effect(() => {
    void load()
  })

  const manifest = $derived(offered?.manifest ?? installed?.manifest ?? null)
  const title = $derived(manifest ? textOf(manifest.title, $locale) : id)
  const description = $derived(manifest?.description ? textOf(manifest.description, $locale) : '')
  const s = $derived(offered ? standing(offered, installed ? [installed] : []) : installed ? 'current' : 'none')

  const message = $derived.by(() => {
    if (asking === 'remove') return $LL.storeDeskUninstallMessage({ name: title })
    if (!asking || !offered) return ''
    const asks = offered.manifest.permissions.map((p) => permissionText($LL, p))
    const what = asks.length ? $LL.settingsAppApproveMessage({ name: title, permissions: asks.join(', ') }) : $LL.settingsAppApproveBare({ name: title })
    const who = offered.signedBy ? '' : ` ${$LL.storeUnknownPublisherNote()}`
    return `${what} ${$LL.settingsAppApproveRisk()}${who}`
  })

  async function confirm(password: string) {
    if (asking === 'remove') {
      await api.removeApp(id, password)
    } else if (offered) {
      // The same package waiting: approved. Another (or none): installed and
      // approved at once, so the one installed stays as it is until then.
      if (installed && installed.sha256 === offered.sha256) await api.approveApp(id, installed.sha256, installed.manifest.permissions, password)
      else await api.installOffered(id, offered.sha256, offered.manifest.permissions, password)
    }
    await load()
    await win.reloadApps()
  }
</script>

{#if !loaded}
  <div class="flex justify-center py-12"><Spinner size={48} /></div>
{:else if !manifest}
  <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
    <Icon name="error" size={17} />
    <p>{error || $LL.storeEmpty()}</p>
  </Card>
{:else}
  <div class="space-y-[17px]">
    <div class="flex flex-wrap items-center gap-[17px] px-[2px] pb-[4px]">
      <AppIcon glyph={manifest.glyph} tone={manifest.tone as IconTone} size={72} />
      <div class="flex min-w-0 flex-1 flex-col gap-[3px]">
        <span class="flex items-center gap-[9px]">
          <span class="truncate text-[27px] font-bold tracking-[-0.01em]">{title}</span>
          {#if s === 'current'}<Badge tone="success">{$LL.stackInstalled()}</Badge>{/if}
          {#if s === 'waiting'}<Badge tone="warning" dot>{$LL.settingsAppWaiting()}</Badge>{/if}
        </span>
        <span class="text-[13px] text-(--text-secondary)">
          {offered?.signedBy || installed?.signed_by ? $LL.storeFirstParty() : $LL.storeUnknownPublisher()} · {offered?.version ?? installed?.version}
        </span>
      </div>
      <div class="flex flex-wrap items-center gap-[9px]">
        {#if s === 'current' || s === 'update'}
          <Button icon="open_in_new" variant={s === 'update' ? 'secondary' : 'primary'} onclick={() => win.open(id)}>{$LL.stackOpen()}</Button>
        {/if}
        {#if canChange && offered && s !== 'current'}
          <Button icon={s === 'none' ? 'download' : 'upgrade'} onclick={() => (asking = 'install')}>
            {s === 'update' ? $LL.stackUpdate({ version: offered.version }) : s === 'waiting' ? $LL.settingsAppApprove() : $LL.storeInstall()}
          </Button>
        {/if}
      </div>
    </div>

    {#if description}<p class="text-[13px] leading-relaxed text-(--text-secondary)">{description}</p>{/if}
    {#if offered?.signedBy && offered.source === 'bundled'}
      <p class="flex items-start gap-[7px] text-[12px] text-(--text-tertiary)"><Icon name="verified" size={15} />{$LL.storeDeskBuiltIn()}</p>
    {:else if offered && !offered.signedBy}
      <p class="flex items-start gap-[7px] text-[12px] text-(--color-warning)"><Icon name="warning" size={15} />{$LL.storeUnknownPublisherNote()}</p>
    {/if}
    {#if error}<p class="text-[13px] text-(--color-danger)">{error}</p>{/if}

    <Group title={$LL.settingsAppPermissions()}>
      {#each manifest.permissions as p (p)}
        <Row label={permissionText($LL, p)} />
      {:else}
        <Row label={$LL.settingsAppNoPermissions()} />
      {/each}
    </Group>

    <Group>
      <Row label={$LL.stackDeveloper()} value={offered?.signedBy || installed?.signed_by ? $LL.storeFirstParty() : manifest.publisher} />
      {#if offered}<Row label={$LL.stackVersion()} value={offered.version} mono />{/if}
      {#if installed}
        <Row label={$LL.settingsAppInstalled()} value={`${installed.version} · ${fmtDate(new Date(installed.installed_at), DATE_TIME)}`} />
      {/if}
      {#if offered}
        <Row label={$LL.filesSize()} value={fmtBytes(offered.size)} />
        <Row label={$LL.storeDeskFrom()} value={offered.source === 'bundled' ? $LL.storeDeskShipped() : (offered.repo ?? '')} mono={offered.source !== 'bundled'} />
      {/if}
      {#if manifest.os?.length}<Row label={$LL.storeDeskRunsOn()} value={manifest.os.join(', ')} />{/if}
    </Group>

    {#if canChange && installed}
      <div class="flex justify-end">
        <Button variant="destructive" icon="delete" onclick={() => (asking = 'remove')}>{$LL.storeDeskUninstall()}</Button>
      </div>
    {/if}
  </div>
{/if}

<ReauthDialog open={asking !== null} {message} onconfirm={confirm} onclose={() => (asking = null)} />
