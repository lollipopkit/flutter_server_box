<script lang="ts">
  /// One web app of the agent's catalog, all of it: what it is (description,
  /// developer, licence, source, requirements, what it does here), and for
  /// an admin installing it (setup, confirmation, password), its progress,
  /// then updating, opening and uninstalling it. The App Store's page for an
  /// app, and Settings → Apps' for an installed one.

  import { AppIcon, Badge, Button, Card, Group, Icon, Row, Spinner } from '../../desk/lk'
  import type { IconTone } from '../../desk/lk'
  import { useWindow } from '../../desk/sys'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { api } from '../../lib/api'
  import { capabilitiesStore } from '../../lib/capabilities.svelte'
  import { servers } from '../../lib/servers.svelte'
  import type { StackApp, StackHealth, StackJob } from '../../types'
  import { healthBadge } from './health'
  import StackLogin from './StackLogin.svelte'
  import StackProgress from './StackProgress.svelte'
  import StackRemove from './StackRemove.svelte'
  import StackSetup from './StackSetup.svelte'
  import { stackAppId } from './apps'
  import { noticeText } from './notices'
  import { stackRefusal } from './refusal'
  import { mib, pick } from './text'
  import { untrack } from 'svelte'

  interface Props {
    stackId: string
    /// Shows the app's own header (an App Store page); Settings draws its own.
    header?: boolean
  }

  const { stackId, header = true }: Props = $props()
  const win = useWindow()

  let app = $state<StackApp | null>(null)
  let job = $state<StackJob | null>(null)
  let error = $state('')
  let removing = $state(false)
  /// The setup form is open: an admin chose to install, or to change a
  /// deployed app's settings.
  let setting = $state(false)

  const admin = $derived(capabilitiesStore.byServer[servers.currentId]?.me?.admin === true)
  const title = $derived(app ? pick(app.manifest.title, $locale) : '')
  const stack = $derived(app?.stack ?? null)
  const appId = $derived(stackAppId(stackId))
  const tr = (text: Record<string, string> | null | undefined) => pick(text, $locale)

  async function load(serverId = servers.currentId) {
    error = ''
    try {
      const found = (await api.listStacks()).apps.find((a) => a.manifest.id === stackId) ?? null
      if (serverId !== servers.currentId) return
      app = found
      if (found?.job?.state === 'running') job = found.job
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  function finished() {
    job = null
    setting = false
    // The panel offers the app while it is installed.
    void capabilitiesStore.refresh(servers.currentId)
    void load()
  }

  async function update() {
    error = ''
    try {
      job = await api.stackAction(stackId, 'update')
    } catch (e) {
      error = app ? stackRefusal(e, app.manifest, stack?.settings, $LL, $locale).text : e instanceof Error ? e.message : String(e)
    }
  }

  function jobTitle(j: StackJob): string {
    if (j.kind === 'install') return $LL.stackInstalling({ name: title })
    if (j.kind === 'update') return $LL.stackUpdating({ name: title })
    if (j.kind === 'reconfigure') return $LL.stackReconfiguring({ name: title })
    if (j.kind === 'remove') return $LL.stackRemoving({ name: title })
    return $LL.stackWorking()
  }

  function healthLook(state: StackHealth['state']): { tone: 'success' | 'neutral' | 'danger'; text: string } {
    return healthBadge(state, $LL)
  }

  function fromText(a: StackApp): string {
    if (a.source === 'local') return $LL.stackFromLocal()
    if (a.source === 'store' && a.repo) return URL.parse(a.repo)?.host ?? a.repo
    return $LL.stackFromBundled()
  }

  function stateText(state: string): string {
    if (state === 'installed') return $LL.stackInstalled()
    if (state === 'installing') return $LL.stackInstalling({ name: title })
    return $LL.stackFailed()
  }
</script>

<div class="space-y-[13px]">
  {#if error}
    <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
      <Icon name="error" size={17} />
      <p>{error}</p>
    </Card>
  {/if}

  {#if !app}
    {#if !error}<div class="flex justify-center py-12"><Spinner size={48} /></div>{/if}
  {:else if job}
    {#key job.id}
      <StackProgress {stackId} {job} title={jobTitle(job)} ondone={finished} />
    {/key}
  {:else if setting}
    <StackSetup manifest={app.manifest} current={stack?.settings} onstarted={(j) => (job = j)} />
    <div class="flex justify-start">
      <Button variant="ghost" icon="arrow_back" onclick={() => (setting = false)}>{$LL.cancel()}</Button>
    </div>
  {:else}
    {#if header}
      <div class="flex flex-wrap items-center gap-[17px] px-[2px] pb-[4px]">
        <AppIcon glyph={app.manifest.glyph} tone={app.manifest.tone as IconTone} size={72} />
        <div class="flex min-w-0 flex-1 flex-col gap-[3px]">
          <span class="truncate text-[27px] font-bold tracking-[-0.01em]">{title}</span>
          <span class="text-[13px] text-(--text-secondary)">
            {$LL.stackPoweredBy({ name: app.manifest.project, version: stack?.version ?? app.manifest.version })}
            {#if app.manifest.developer}· {app.manifest.developer}{/if}
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-[9px]">
          {#if !stack}
            {#if admin}
              <Button icon="download" onclick={() => (setting = true)}>{$LL.stackGet()}</Button>
            {:else}
              <span class="text-[12px] text-(--text-tertiary)">{$LL.stackAskAdmin()}</span>
            {/if}
          {:else if appId && stack.state === 'installed'}
            <Button icon="open_in_new" onclick={() => win.open(appId)}>{$LL.stackOpen()}</Button>
          {/if}
        </div>
      </div>
      <p class="text-[13px] leading-relaxed text-(--text-secondary)">{tr(app.manifest.description)}</p>
    {/if}

    {#if stack}
      <Group title={$LL.stackManage()}>
        <Row label={$LL.stackStateLabel()} value={stateText(stack.state)}>
          <Badge tone={stack.state === 'installed' ? 'success' : stack.state === 'failed' ? 'danger' : 'neutral'}>{stateText(stack.state)}</Badge>
        </Row>
        <Row label={$LL.stackVersion()} value={stack.version} mono />
        {#if app.health}
          {@const h = healthLook(app.health.state)}
          <Row label={$LL.stackHealth()} value={h.text} sub={app.health.failing.length ? app.health.failing.join(', ') : undefined}>
            <Badge tone={h.tone}>{h.text}</Badge>
          </Row>
        {/if}
        {#if stack.last_error}<Row label={$LL.stackFailed()} value={stack.last_error} mono />{/if}
      </Group>
      {#if admin && stack.state === 'installed' && app.manifest.login}
        <StackLogin {stackId} login={app.manifest.login} name={title} />
      {/if}
      {#if admin}
        <div class="flex flex-wrap justify-end gap-[9px]">
          <Button variant="destructive" onclick={() => (removing = true)}>{$LL.stackRemove()}</Button>
          {#if stack.settings}
            <Button variant="secondary" icon="tune" onclick={() => (setting = true)}>{$LL.stackChangeSettings()}</Button>
          {/if}
          {#if stack.version !== app.manifest.version || stack.state === 'failed'}
            <Button variant="secondary" onclick={() => void update()}>
              {stack.state === 'failed' ? $LL.stackRetry() : $LL.stackUpdate({ version: app.manifest.version })}
            </Button>
          {/if}
          {#if !header && appId && stack.state === 'installed'}
            <Button icon="open_in_new" onclick={() => win.open(appId)}>{$LL.stackOpen()}</Button>
          {/if}
        </div>
      {/if}
    {/if}

    <Group title={$LL.stackInformation()}>
      <Row label={$LL.stackProject()} value={app.manifest.project} />
      {#if app.manifest.developer}<Row label={$LL.stackDeveloper()} value={app.manifest.developer} />{/if}
      <Row label={$LL.stackVersion()} value={app.manifest.version} mono />
      <Row label={$LL.stackLicense()} value={app.manifest.license.spdx} />
      {#if app.manifest.requirements.memory_min_mib}
        <Row
          label={$LL.stackMemory()}
          value={$LL.stackMemoryNeeds({
            min: mib(app.manifest.requirements.memory_min_mib),
            recommended: mib(app.manifest.requirements.memory_recommended_mib ?? app.manifest.requirements.memory_min_mib),
          })}
        />
      {/if}
      {#if app.manifest.requirements.arch.length}<Row label={$LL.stackArch()} value={app.manifest.requirements.arch.join(', ')} />{/if}
      {#if app.source}<Row label={$LL.stackFrom()} value={fromText(app)} />{/if}
    </Group>
    <div class="flex flex-wrap gap-x-[17px] gap-y-[5px] px-[2px] text-[13px]">
      <a class="text-(--color-accent-text) hover:underline" href={app.manifest.homepage} target="_blank" rel="noreferrer noopener">{$LL.stackHomepage()}</a>
      <a class="text-(--color-accent-text) hover:underline" href={app.manifest.source} target="_blank" rel="noreferrer noopener">{$LL.stackSource()}</a>
      <a class="text-(--color-accent-text) hover:underline" href={app.manifest.license.url} target="_blank" rel="noreferrer noopener">{$LL.stackLicenseRead()}</a>
    </div>

    {#if app.manifest.notices.length}
      <Group title={$LL.stackNotices()}>
        {#each app.manifest.notices as n (n)}
          <div class="flex items-start gap-[9px] px-[13px] py-[9px] text-[13px] text-(--text-secondary)">
            <Icon name="info" size={16} class="mt-[1px] shrink-0" />
            <span>{noticeText(n, $LL)}</span>
          </div>
        {/each}
      </Group>
    {/if}
    <p class="px-[2px] text-[12px] text-(--text-tertiary)">{$LL.stackThirdParty({ name: app.manifest.project })}</p>
  {/if}
</div>

<StackRemove open={removing} {stackId} name={title} onstarted={(j) => (job = j)} onclose={() => (removing = false)} />
