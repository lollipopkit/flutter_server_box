<script lang="ts">
  /// AI agents on this machine: Codex, Claude Code, pi, opencode, Hermes and
  /// OpenClaw for the agent's account. Each installed, updated or removed
  /// as a job, pointed at a model of Agent mode's providers (a local one
  /// too), and its gateway run where it has one. What runs where is the
  /// backend's; this page asks and shows.

  import Badge from '$lk/Badge.svelte'
  import Button from '$lk/Button.svelte'
  import Card from '$lk/Card.svelte'
  import Checkbox from '$lk/Checkbox.svelte'
  import Group from '$lk/Group.svelte'
  import Icon from '$lk/Icon.svelte'
  import IconButton from '$lk/IconButton.svelte'
  import Row from '$lk/Row.svelte'
  import Select from '$lk/Select.svelte'
  import Spinner from '$lk/Spinner.svelte'
  import { DeskError, translator } from 'serverbox-desk'
  import { desk } from '$common/desk'
  import JobLog from '$common/JobLog.svelte'
  import { JobRun } from '$common/job.svelte'
  import { dictionaries } from './locales'

  type ToolId = 'codex' | 'claude' | 'pi' | 'opencode' | 'hermes' | 'openclaw'
  interface Found {
    tool: ToolId
    path: string | null
    version: string | null
    pinned: string | null
    homepage: string
    gateway: boolean
    apis: string[]
  }
  interface Provider {
    id: string
    name: string
    api: string
    baseUrl: string
    models: string[]
  }

  const NAMES: Record<ToolId, string> = {
    codex: 'Codex',
    claude: 'Claude Code',
    pi: 'pi',
    opencode: 'opencode',
    hermes: 'Hermes',
    openclaw: 'OpenClaw',
  }

  let locale = $state(desk.info.locale)
  const t = $derived(translator(dictionaries, locale))
  desk.on('locale', (l) => (locale = l))

  let tools = $state<Found[] | null>(null)
  let selected = $state<ToolId>('codex')
  let providers = $state<Provider[]>([])
  let provider = $state('')
  let model = $state('')
  let purge = $state(false)
  let removing = $state(false)
  let saved = $state('')
  let gatewayOut = $state('')
  let busy = $state(false)
  let error = $state('')
  const job = new JobRun()

  function said(e: unknown): string {
    if (!(e instanceof DeskError)) return String(e)
    const [code, rest] = (e.detail ?? '').split('\n', 2)
    if (code === 'unreadable') return t('unreadable', { path: rest ?? '' })
    return e.detail || e.message
  }

  async function load() {
    try {
      tools = await desk.call<Found[]>('view')
      error = ''
    } catch (e) {
      error = said(e)
    }
  }

  async function loadProviders() {
    try {
      providers = await desk.call<Provider[]>('providers')
    } catch {
      // Without Agent mode's providers, nothing to point at; said below.
    }
  }

  const current = $derived(tools?.find((x) => x.tool === selected))
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

  function choose(id: ToolId) {
    selected = id
    saved = ''
    gatewayOut = ''
    removing = false
  }

  async function change(fn: 'install' | 'update' | 'uninstall') {
    removing = false
    const args: Record<string, unknown> = { tool: selected }
    if (fn === 'uninstall') args.purge = purge
    await job.start(fn, args, undefined, said)
    await load()
  }

  async function configure() {
    busy = true
    error = ''
    saved = ''
    try {
      await desk.call('configure', { tool: selected, provider, model })
      saved = t('saved', { model })
    } catch (e) {
      error = said(e)
    } finally {
      busy = false
    }
  }

  async function gateway(action: 'status' | 'install' | 'start' | 'stop') {
    busy = true
    try {
      const r = await desk.call<{ exitCode: number; output: string }>('gateway', { tool: selected, action })
      gatewayOut = r.output.trim()
    } catch (e) {
      error = said(e)
    } finally {
      busy = false
    }
  }

  function apiText(a: string): string {
    return a === 'openai-responses' ? 'Responses' : a === 'anthropic-messages' ? 'Anthropic Messages' : 'Chat Completions'
  }

  void job.resume(said).then(() => load())
  void load()
  void loadProviders()
</script>

<main class="page tools">
  <div class="trail">
    <span class="grow"></span>
    <IconButton icon="refresh" label={t('refresh')} onclick={() => void load()} />
  </div>
  {#if error}
    <Card><p class="error"><Icon name="error" size={17} /><span>{error}</span></p></Card>
  {/if}
  {#if job.status}
    <JobLog
      {t}
      status={job.status}
      title={job.running ? t('working') : job.status === 'succeeded' ? t('done') : t('failed')}
      lines={job.lines}
      oncancel={() => job.cancel()}
    />
  {/if}

  {#if !tools}
    {#if !error}<div class="center"><Spinner /></div>{/if}
  {:else}
    <div class="split">
      <Group>
        {#each tools as x (x.tool)}
          <Row label={NAMES[x.tool]} sub={x.version ?? t('notInstalled')} class={x.tool === selected ? 'chosen' : ''} onclick={() => choose(x.tool)} />
        {/each}
      </Group>

      {#if current}
        <div class="detail">
          <Group>
            <Row label={NAMES[current.tool]} sub={current.path ?? t('notInstalled')} mono={!!current.path}>
              {#if current.version}<Badge tone="success">{current.version}</Badge>{/if}
            </Row>
            {#if current.pinned}<Row label={t('release')} value={current.pinned} mono />{/if}
            <Row label={t('modelApis')} value={current.apis.map(apiText).join(', ')} />
          </Group>
          <div class="trail wrap">
            {#if !current.path}
              <Button variant="primary" icon="download" disabled={job.running} onclick={() => void change('install')}>{t('install')}</Button>
            {:else}
              <Button variant="secondary" icon="upgrade" disabled={job.running} onclick={() => void change('update')}>{t('update')}</Button>
              <Button variant="destructive" disabled={job.running} onclick={() => (removing = true)}>{t('remove')}</Button>
            {/if}
            <button type="button" class="link plain" onclick={() => void desk.openUrl(current.homepage)}>{t('homepage')}</button>
          </div>
          {#if removing}
            <Card>
              <div class="intro">
                <p>{t('removeAsk', { name: NAMES[current.tool] })}</p>
                <Checkbox label={t('purge')} bind:checked={purge} />
                <div class="trail">
                  <Button variant="destructive" onclick={() => void change('uninstall')}>{t('remove')}</Button>
                  <Button variant="ghost" onclick={() => (removing = false)}>{t('cancel')}</Button>
                </div>
              </div>
            </Card>
          {/if}

          {#if current.path}
            <Group title={t('model')}>
              {#if usable.length}
                <div class="trail wrap pad">
                  <Select
                    class="grow"
                    label={t('provider')}
                    options={usable.map((p) => ({ value: p.id, label: p.name }))}
                    bind:value={provider}
                  />
                  <Select class="grow" label={t('model')} options={models.map((m) => ({ value: m, label: m }))} bind:value={model} />
                  <Button variant="primary" disabled={busy || !provider || !model} onclick={configure}>{t('use')}</Button>
                </div>
                <div class="pad">
                  {#if saved}<p class="hint ok">{saved}</p>{/if}
                  <p class="hint">{t('keyNote')}</p>
                </div>
              {:else}
                <p class="hint pad">{t('noProvider', { apis: current.apis.map(apiText).join(', ') })}</p>
              {/if}
            </Group>

            {#if current.gateway}
              <Group title={t('gateway')}>
                <div class="trail wrap pad">
                  <Button size="sm" variant="secondary" disabled={busy} onclick={() => void gateway('status')}>{t('gatewayStatus')}</Button>
                  <Button size="sm" variant="secondary" disabled={busy} onclick={() => void gateway('install')}>{t('gatewayInstall')}</Button>
                  <Button size="sm" variant="secondary" disabled={busy} onclick={() => void gateway('start')}>{t('gatewayStart')}</Button>
                  <Button size="sm" variant="secondary" disabled={busy} onclick={() => void gateway('stop')}>{t('gatewayStop')}</Button>
                </div>
                {#if gatewayOut}<pre class="lk-mono out">{gatewayOut}</pre>{/if}
              </Group>
            {/if}
          {/if}
        </div>
      {/if}
    </div>
  {/if}
</main>

<style>
  .tools {
    max-width: 980px;
  }

  /* The tools beside the chosen one when there is room, above it when not. */
  .split {
    display: grid;
    gap: 13px;
    align-items: start;
  }

  @media (min-width: 720px) {
    .split {
      grid-template-columns: 240px minmax(0, 1fr);
    }
  }

  .detail {
    display: flex;
    flex-direction: column;
    gap: 13px;
    min-width: 0;
  }

  .split :global(.chosen) {
    background: var(--color-accent-soft);
  }

  .plain {
    border: 0;
    background: none;
    padding: 0 5px;
    font: inherit;
    font-size: 13px;
    cursor: pointer;
  }

  .ok {
    color: var(--color-success);
  }

  .out {
    margin: 0 13px 11px;
    max-height: 220px;
    overflow: auto;
    font-size: 12px;
    white-space: pre-wrap;
    color: var(--text-secondary);
  }
</style>
