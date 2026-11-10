<script lang="ts">
  /// The first-run guide: what this desk is, where its apps are, and the
  /// catalog's recommended web apps. Skippable at every step.
  ///
  /// It installs nothing itself: an app's Install opens its App Store page,
  /// where the deploy dialog asks what it always asks.

  import { AppIcon, Badge, Button, Card, Dialog, Icon, Spinner } from '../lk'

  import { api } from '../../lib/api'
  import { canAct } from '../../lib/access'
  import { capabilitiesStore } from '../../lib/capabilities.svelte'
  import { errorText } from '../../lib/errorText'
  import { useScope } from '../../lib/scope.svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName, servers } from '../../lib/servers.svelte'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import type { IconTone } from '../lk'
  import type { StackApp } from '../../types'
  import { pick } from '../../components/stack/text'
  import { useDesk } from '../deskState.svelte'
  import type { DeskPrefs } from '../prefs.svelte'
  import { GuideFlow } from './flow.svelte'

  interface Props {
    prefs: DeskPrefs
  }

  const STORE = 'serverbox.store'

  const { prefs }: Props = $props()
  const desk = useDesk()
  const scope = useScope()
  // svelte-ignore state_referenced_locally
  const flow = new GuideFlow(prefs)

  /// The catalog's recommended apps, once read; empty where the agent runs none.
  let apps = $state<StackApp[] | null>(null)
  let error = $state('')
  let asked = false
  /// Whether this machine can run them (`/stacks/{id}/prepare`'s runtime).
  let runtime = $state<'unknown' | 'here' | 'absent'>('unknown')
  let runtimeText = $state('')

  const title = $derived(
    flow.step === 'welcome'
      ? $LL.deskGuideWelcomeTitle()
      : flow.step === 'apps'
        ? $LL.deskGuideAppsTitle()
        : $LL.deskGuideWebAppsTitle(),
  )
  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  const host = $derived(
    serverNames.byServer[servers.currentId] ??
      (servers.currentId === 'local' ? $LL.thisServer() : displayName(servers.current ?? { id: '', url: '', token: null })),
  )
  const hasStore = $derived(desk.apps.some((a) => a.id === STORE))
  /// The dock's apps, in its order.
  const mainApps = $derived(
    prefs.value.dock
      .map((id) => desk.apps.find((a) => a.id === id))
      .filter((a) => a !== undefined)
      .slice(0, 6),
  )

  $effect(() => {
    const serverId = servers.currentId
    // Capabilities arrive after the desk does.
    if (asked || !caps) return
    asked = true
    if (!caps.features?.includes('stacks')) {
      apps = []
      return
    }
    void load(serverId, canAct(caps))
  })

  async function load(serverId: string, acting: boolean) {
    error = ''
    try {
      const { apps: catalog } = await api.listStacks()
      if (scope.stale(serverId)) return
      apps = catalog.filter((a) => a.manifest.recommended)
      // Only an account that may act here is asked (and told) about Docker;
      // the App Store page explains the rest.
      if (!acting || !apps[0]) return
      const prepared = await api.prepareStack(apps[0].manifest.id)
      if (scope.stale(serverId)) return
      if (prepared.runtime.available) {
        runtime = 'here'
        return
      }
      runtime = 'absent'
      runtimeText = prepared.runtime.error === 'noCompose' ? $LL.stackNoCompose() : $LL.stackNoRuntime()
    } catch (e) {
      if (!scope.stale(serverId)) error = errorText(e)
    }
  }

  /// Done with the guide, on [app]'s App Store page (or the store's list).
  function openStore(app: string | null) {
    flow.finish()
    desk.open(STORE, { appState: app ? { app } : null })
  }
</script>

<Dialog wide {title} class="lk-guide">
  {#if flow.step === 'welcome'}
    <p class="text-[13px] leading-relaxed text-(--text-secondary)">{$LL.deskGuideBody({ host })}</p>
    <p class="pt-[9px] text-[13px] leading-relaxed text-(--text-secondary)">{$LL.deskGuideWelcomeMore()}</p>
  {:else if flow.step === 'apps'}
    <p class="text-[13px] leading-relaxed text-(--text-secondary)">{$LL.deskGuideAppsBody({ apps: $LL.deskApps() })}</p>
    <div class="grid grid-cols-2 gap-[9px] pt-[13px]">
      {#each mainApps as a (a.id)}
        <Card variant="raised" class="flex min-w-0 items-center gap-[9px]" padding="7px 9px">
          <AppIcon glyph={a.glyph} tone={a.tone as IconTone} size={28} />
          <span class="truncate text-[13px] text-(--text-primary)">{a.title($LL)}</span>
        </Card>
      {/each}
    </div>
    <p class="pt-[11px] text-[12px] leading-relaxed text-(--text-tertiary)">{$LL.deskGuideAppsMore()}</p>
  {:else}
    <p class="text-[13px] leading-relaxed text-(--text-secondary)">{$LL.deskGuideWebAppsBody()}</p>
    {#if runtime === 'absent'}
      <Card class="mt-[9px] flex items-start gap-[9px] text-[13px]" padding="9px 11px">
        <Icon name="info" size={17} />
        <span>{$LL.deskGuideNoDocker()} {runtimeText} {$LL.deskGuideNoDockerHint()}</span>
      </Card>
    {/if}
    {#if error}
      <Card class="mt-[9px] flex items-start gap-[9px] text-[13px] text-(--color-danger)" padding="9px 11px">
        <Icon name="error" size={17} />
        <span>{error}</span>
      </Card>
    {:else if !apps}
      <div class="flex justify-center py-[21px]"><Spinner size={34} /></div>
    {:else if apps.length === 0}
      <p class="pt-[13px] text-[13px] text-(--text-tertiary)">{$LL.storeEmpty()}</p>
    {:else}
      <div class="space-y-[7px] pt-[13px]">
        {#each apps as a (a.manifest.id)}
          <Card variant="raised" class="flex items-center gap-[11px]" padding="9px 11px">
            <AppIcon glyph={a.manifest.glyph} tone={a.manifest.tone as IconTone} size={36} />
            <div class="min-w-0 flex-1 space-y-[2px]">
              <span class="block truncate text-[14px] font-semibold text-(--text-primary)">{pick(a.manifest.title, $locale)}</span>
              <span class="block text-[12px] leading-snug text-(--text-tertiary)">{pick(a.manifest.description, $locale)}</span>
            </div>
            {#if a.stack?.state === 'installed'}
              <Badge tone="success">{$LL.stackInstalled()}</Badge>
            {:else if hasStore}
              <Button size="sm" variant="secondary" disabled={runtime === 'absent'} onclick={() => openStore(a.manifest.id)}>
                {$LL.deskGuideInstall()}
              </Button>
            {/if}
          </Card>
        {/each}
      </div>
      <p class="pt-[11px] text-[12px] leading-relaxed text-(--text-tertiary)">{$LL.deskGuideWebAppsNote()}</p>
    {/if}
  {/if}

  {#snippet actions()}
    {#if !flow.last}
      <Button variant="ghost" onclick={() => flow.finish()}>{$LL.deskGuideSkip()}</Button>
    {/if}
    <div class="flex-1"></div>
    {#if !flow.first}
      <Button variant="secondary" icon="arrow_back" onclick={() => flow.previous()}>{$LL.back()}</Button>
    {/if}
    {#if flow.last}
      {#if hasStore}
        <Button variant="secondary" icon="storefront" onclick={() => openStore(null)}>{$LL.deskGuideOpenStore()}</Button>
      {/if}
      <Button variant="primary" onclick={() => flow.finish()}>{$LL.deskGuideDone()}</Button>
    {:else}
      <Button variant="primary" iconRight="arrow_forward" onclick={() => flow.next()}>{$LL.deskGuideNext()}</Button>
    {/if}
  {/snippet}
</Dialog>

<style>
  /* The guide scrolls inside itself, so its title and buttons stay reachable. */
  :global(.lk-guide) {
    max-height: calc(100% - 34px);
    overflow-y: auto;
  }
</style>
