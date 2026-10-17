<script lang="ts">
  /// AI agents on this machine (`/agent-tools`): Codex, Claude Code, pi,
  /// opencode, Hermes and OpenClaw for the agent's account. Each is
  /// installed, updated or removed as a job, pointed at a model of Agent
  /// mode's providers (a local one too), and its gateway run where it has
  /// one. What runs where is the agent's; this page asks and shows.

  import { AppToolbar, SplitView } from '../../sys'
  import { Badge, Button, Card, Checkbox, Group, Icon, IconButton, Row, Select, SidebarItem, SidebarSection, Spinner } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import { errorText } from '../../../lib/errorText'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import type { AgentToolId, AgentToolProvider, AgentToolView, StackJob } from '../../../types'

  const NAMES: Record<AgentToolId, string> = {
    codex: 'Codex',
    claude: 'Claude Code',
    pi: 'pi',
    opencode: 'opencode',
    hermes: 'Hermes',
    openclaw: 'OpenClaw',
  }

  let tools = $state<AgentToolView[]>([])
  let selected = $state<AgentToolId>('codex')
  let job = $state<StackJob | null>(null)
  const running = $derived(job?.state === 'running')
  let error = $state('')
  let loading = $state(true)
  let providers = $state<AgentToolProvider[]>([])
  let provider = $state('')
  let model = $state('')
  let purge = $state(false)
  let removing = $state(false)
  let saved = $state('')
  let gatewayOut = $state('')
  let busy = $state(false)
  const { stale } = useScope()

  async function load(serverId = servers.currentId) {
    try {
      const v = await api.getAgentTools()
      if (stale(serverId)) return
      tools = v.tools
      if (v.job?.state === 'running') job = v.job
      error = ''
    } catch (e) {
      if (!stale(serverId)) error = errorText(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  async function loadProviders(serverId = servers.currentId) {
    try {
      const v = await api.agentToolProviders()
      if (!stale(serverId)) providers = v.providers
    } catch {
      // Without Agent mode's providers, nothing to point at; said below.
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
    void loadProviders()
  })

  const current = $derived(tools.find((t) => t.tool === selected))
  /// The providers this tool can speak to.
  const usable = $derived(providers.filter((p) => current?.apis.includes(p.api)))
  const models = $derived(usable.find((p) => p.id === provider)?.models ?? [])

  $effect(() => {
    // A provider of the tool's kind picked first; its first model.
    if (!usable.some((p) => p.id === provider)) provider = usable[0]?.id ?? ''
  })
  $effect(() => {
    if (!models.includes(model)) model = models[0] ?? ''
  })

  async function change(verb: 'install' | 'update' | 'uninstall') {
    error = ''
    try {
      job = await api.changeAgentTool(selected, verb, verb === 'uninstall' && purge)
      removing = false
    } catch (e) {
      error = errorText(e)
    }
  }

  async function configure() {
    busy = true
    error = ''
    saved = ''
    try {
      await api.configureAgentTool(selected, provider, model)
      saved = $LL.agentToolsSaved({ model })
    } catch (e) {
      error = e instanceof ApiError && e.body?.error === 'unreadable' ? $LL.agentToolsUnreadable({ path: String(e.body?.path ?? '') }) : errorText(e)
    } finally {
      busy = false
    }
  }

  async function gateway(action: 'status' | 'install' | 'start' | 'stop') {
    busy = true
    try {
      const r = await api.agentToolGateway(selected, action)
      gatewayOut = r.output.trim()
    } catch (e) {
      error = errorText(e)
    } finally {
      busy = false
    }
  }

  function apiText(a: string): string {
    return a === 'openai-responses' ? 'Responses' : a === 'anthropic-messages' ? 'Anthropic Messages' : 'Chat Completions'
  }
</script>

<AppToolbar title={NAMES[selected]}>
  {#snippet actions()}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} />
  {/snippet}
</AppToolbar>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection>
      {#each tools as t (t.tool)}
        <SidebarItem
          label={NAMES[t.tool]}
          icon={t.path ? 'check_circle' : 'radio_button_unchecked'}
          active={selected === t.tool}
          onclick={() => {
            selected = t.tool
            saved = ''
            gatewayOut = ''
            removing = false
          }}
        />
      {/each}
    </SidebarSection>
  {/snippet}

  <div class="mx-auto max-w-[720px] space-y-[13px] px-(--content-pad) pb-[21px]">
    {#if error}
      <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} /><p class="break-all">{error}</p></Card>
    {/if}
    {#if job}
      {#key job.id}
        <StackProgress
          {job}
          title={job.state === 'running' ? $LL.agentToolsWorking() : job.state === 'succeeded' ? $LL.agentToolsDone() : $LL.agentToolsFailed()}
          read={(since) => api.agentToolsJob(since)}
          stop={() => api.cancelAgentToolsJob()}
          ondone={(done) => {
            // Kept on screen: a failure says why.
            job = done
            void load()
          }}
        />
      {/key}
    {/if}

    {#if loading}
      <div class="grid place-items-center py-[55px]"><Spinner /></div>
    {:else if current}
      <Group>
        <Row label={NAMES[current.tool]} sub={current.path ?? $LL.agentToolsNotInstalled()} mono={!!current.path}>
          {#if current.version}<Badge tone="success">{current.version}</Badge>{/if}
        </Row>
        {#if current.pinned}<Row label={$LL.agentToolsRelease()} value={current.pinned} mono />{/if}
        <Row label={$LL.agentToolsModelApis()} value={current.apis.map(apiText).join(', ')} />
      </Group>
      <div class="flex flex-wrap gap-[9px]">
        {#if !current.path}
          <Button variant="primary" icon="download" disabled={running} onclick={() => void change('install')}>{$LL.agentToolsInstall()}</Button>
        {:else}
          <Button variant="secondary" icon="upgrade" disabled={running} onclick={() => void change('update')}>{$LL.agentToolsUpdate()}</Button>
          <Button variant="destructive" disabled={running} onclick={() => (removing = true)}>{$LL.agentToolsRemove()}</Button>
        {/if}
        <a class="self-center px-[5px] text-[13px] text-(--color-accent-text) hover:underline" href={current.homepage} target="_blank" rel="noreferrer noopener">{$LL.agentToolsHomepage()}</a>
      </div>
      {#if removing}
        <Card class="space-y-[9px] text-[13px]">
          <p>{$LL.agentToolsRemoveAsk({ name: NAMES[current.tool] })}</p>
          <Checkbox label={$LL.agentToolsPurge()} bind:checked={purge} />
          <div class="flex gap-[9px]">
            <Button variant="destructive" onclick={() => void change('uninstall')}>{$LL.agentToolsRemove()}</Button>
            <Button variant="ghost" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
          </div>
        </Card>
      {/if}

      {#if current.path}
        <Group title={$LL.agentToolsModel()}>
          {#if usable.length}
            <div class="flex flex-wrap items-end gap-[11px] px-[13px] py-[11px]">
              <Select class="min-w-[180px]" label={$LL.agentToolsProvider()} options={usable.map((p) => ({ value: p.id, label: p.name }))} bind:value={provider} />
              <Select class="min-w-[200px] flex-1" label={$LL.agentToolsModel()} options={models.map((m) => ({ value: m, label: m }))} bind:value={model} />
              <Button variant="primary" disabled={busy || !provider || !model} onclick={configure}>{$LL.agentToolsUse()}</Button>
            </div>
            {#if saved}<p class="px-[13px] pb-[11px] text-[12px] text-(--color-success)">{saved}</p>{/if}
            <p class="px-[13px] pb-[11px] text-[12px] text-(--text-tertiary)">{$LL.agentToolsKeyNote()}</p>
          {:else}
            <p class="px-[13px] py-[11px] text-[13px] text-(--text-tertiary)">{$LL.agentToolsNoProvider({ apis: current.apis.map(apiText).join(', ') })}</p>
          {/if}
        </Group>

        {#if current.gateway}
          <Group title={$LL.agentToolsGateway()}>
            <div class="flex flex-wrap gap-[9px] px-[13px] py-[11px]">
              <Button size="sm" variant="secondary" disabled={busy} onclick={() => void gateway('status')}>{$LL.agentToolsGatewayStatus()}</Button>
              <Button size="sm" variant="secondary" disabled={busy} onclick={() => void gateway('install')}>{$LL.agentToolsGatewayInstall()}</Button>
              <Button size="sm" variant="secondary" disabled={busy} onclick={() => void gateway('start')}>{$LL.agentToolsGatewayStart()}</Button>
              <Button size="sm" variant="secondary" disabled={busy} onclick={() => void gateway('stop')}>{$LL.agentToolsGatewayStop()}</Button>
            </div>
            {#if gatewayOut}<pre class="lk-mono mx-[13px] mb-[11px] max-h-[220px] overflow-auto text-[12px] whitespace-pre-wrap text-(--text-secondary)">{gatewayOut}</pre>{/if}
          </Group>
        {/if}
      {/if}
    {/if}
  </div>
</SplitView>
