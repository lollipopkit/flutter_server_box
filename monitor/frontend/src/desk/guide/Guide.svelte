<script lang="ts">
  /// The first-run guide: what this desk is, where its apps are, and a few
  /// web apps worth installing on this machine. Shown to an account that has
  /// not been here before (Settings offers it again), and skippable at every
  /// step — the desk is never held up by it.
  ///
  /// It installs nothing itself: a chosen app opens on its page in the App
  /// Store, where what its compose files do, the settings and the account's
  /// password are asked exactly as they always are.

  import { AppIcon, Badge, Button, Card, Checkbox, Dialog, Icon, Spinner } from '../lk'

  import { api } from '../../lib/api'
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

  const { prefs }: Props = $props()
  const desk = useDesk()
  const scope = useScope()
  // svelte-ignore state_referenced_locally
  const flow = new GuideFlow(prefs)

  /// The catalog, once it has been read: what the guide recommends from.
  let apps = $state<StackApp[] | null>(null)
  let error = $state('')
  let asked = false
  /// What the machine says about running web apps (`GET /stacks/{id}/prepare`,
  /// the answer the deploy dialog starts from): unknown until it answers.
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
  const recommended = $derived((apps ?? []).filter((a) => a.manifest.recommended))
  /// The dock's apps, in its order: what this desk is arranged with.
  const mainApps = $derived(
    prefs.value.dock
      .map((id) => desk.apps.find((a) => a.id === id))
      .filter((a) => a !== undefined)
      .slice(0, 6),
  )

  $effect(() => {
    const serverId = servers.currentId
    // Capabilities arrive after the desk does; an agent that serves no web
    // apps has no catalog to read.
    if (asked || !caps) return
    asked = true
    if (!caps.features?.includes('stacks')) {
      apps = []
      return
    }
    void load(serverId)
  })

  async function load(serverId: string) {
    error = ''
    try {
      const { apps: catalog } = await api.listStacks()
      if (scope.stale(serverId)) return
      apps = catalog
      const first = catalog.find((a) => a.manifest.recommended) ?? catalog[0]
      if (!first) return
      const prepared = await api.prepareStack(first.manifest.id)
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

  /// Marks the guide done and opens each chosen app's App Store page, a
  /// window each: that is where the deploy dialog lives.
  function install() {
    const chosen = [...flow.chosen]
    flow.finish()
    for (const id of chosen) desk.open('serverbox.store', { newWindow: true, appState: { app: id } })
  }
</script>

<Dialog wide {title} class="lk-guide">
  {#if flow.step === 'welcome'}
    <p class="text-[13px] leading-relaxed text-(--text-secondary)">{$LL.deskGuideBody({ host })}</p>
    <p class="pt-[9px] text-[13px] leading-relaxed text-(--text-secondary)">{$LL.deskGuideWelcomeMore()}</p>
  {:else if flow.step === 'apps'}
    <p class="text-[13px] leading-relaxed text-(--text-secondary)">
      {$LL.deskGuideAppsBody({ apps: $LL.deskApps(), host })}
    </p>
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
        <span>{$LL.deskGuideNoDocker()} {runtimeText}</span>
      </Card>
      <p class="pt-[7px] text-[12px] leading-relaxed text-(--text-tertiary)">{$LL.deskGuideNoDockerHint()}</p>
      <p class="pt-[7px] text-[12px] leading-relaxed text-(--text-tertiary)">{$LL.deskGuideWebAppsNote()}</p>
    {:else if error}
      <Card class="mt-[9px] flex items-start gap-[9px] text-[13px] text-(--color-danger)" padding="9px 11px">
        <Icon name="error" size={17} />
        <span>{error}</span>
      </Card>
    {:else if !apps}
      <div class="flex justify-center py-[21px]"><Spinner size={34} /></div>
    {:else if recommended.length === 0}
      <p class="pt-[13px] text-[13px] text-(--text-tertiary)">{$LL.storeEmpty()}</p>
    {:else}
      <div class="space-y-[7px] pt-[13px]">
        {#each recommended as a (a.manifest.id)}
          <Card variant="raised" class="flex items-center gap-[11px]" padding="9px 11px" selected={flow.chosen.includes(a.manifest.id)}>
            <Checkbox
              checked={flow.chosen.includes(a.manifest.id)}
              onchange={() => flow.toggle(a.manifest.id)}
              aria-label={pick(a.manifest.title, $locale)}
            />
            <button type="button" class="min-w-0 flex-1 space-y-[2px] text-left" onclick={() => flow.toggle(a.manifest.id)}>
              <span class="flex items-center gap-[7px]">
                <span class="truncate text-[14px] font-semibold text-(--text-primary)">{pick(a.manifest.title, $locale)}</span>
                {#if a.stack?.state === 'installed'}<Badge tone="success">{$LL.stackInstalled()}</Badge>{/if}
              </span>
              <span class="block text-[12px] leading-snug text-(--text-tertiary)">{pick(a.manifest.description, $locale)}</span>
            </button>
          </Card>
        {/each}
      </div>
      <p class="pt-[11px] text-[12px] leading-relaxed text-(--text-tertiary)">{$LL.deskGuideWebAppsNote()}</p>
    {/if}
  {/if}

  {#snippet actions()}
    <Button variant="ghost" onclick={() => flow.finish()}>{$LL.deskGuideSkip()}</Button>
    <div class="flex-1"></div>
    {#if !flow.first}
      <Button variant="secondary" icon="arrow_back" onclick={() => flow.previous()}>{$LL.back()}</Button>
    {/if}
    {#if flow.step === 'webApps'}
      <Button variant="primary" icon="download" disabled={runtime === 'absent' || flow.chosen.length === 0} onclick={install}>
        {$LL.deskGuideInstall()}
      </Button>
    {:else}
      <Button variant="primary" iconRight="arrow_forward" onclick={() => flow.next()}>{$LL.deskGuideNext()}</Button>
    {/if}
  {/snippet}
</Dialog>

<style>
  /* Taller than a short window: the guide scrolls inside itself, so its title
     and its buttons stay reachable. */
  :global(.lk-guide) {
    max-height: calc(100% - 34px);
    overflow-y: auto;
  }
</style>
