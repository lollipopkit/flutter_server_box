<script lang="ts">
  /// Local inference on this machine: what it has (GPUs, memory, Docker),
  /// which engines run on it and how, llmfit's models for each (Run sets the
  /// engine up with the model), and each engine: Ollama, llama.cpp, vLLM and
  /// SGLang are the agent's stacks, set up in the desk's own sheet
  /// (`openStack`); MLX installed and served here; Ollama's models pulled
  /// and removed. What fits is the backend's; this page words it.

  import Badge from '$lk/Badge.svelte'
  import Button from '$lk/Button.svelte'
  import Card from '$lk/Card.svelte'
  import Group from '$lk/Group.svelte'
  import Icon from '$lk/Icon.svelte'
  import IconButton from '$lk/IconButton.svelte'
  import Input from '$lk/Input.svelte'
  import Row from '$lk/Row.svelte'
  import SegmentedControl from '$lk/SegmentedControl.svelte'
  import Select from '$lk/Select.svelte'
  import Spinner from '$lk/Spinner.svelte'
  import Switch from '$lk/Switch.svelte'
  import { DeskError, formatBytes, translator } from 'serverbox-desk'
  import { desk } from '$common/desk'
  import JobLog from '$common/JobLog.svelte'
  import { JobRun } from '$common/job.svelte'
  import { dictionaries } from './locales'
  import { ENGINE_NAMES, gib, mibAsGib, type Candidate, type Engine, type EngineFit, type OllamaModel, type Overview, type Recommendation } from './model'

  let locale = $state(desk.info.locale)
  const t = $derived(translator(dictionaries, locale))
  desk.on('locale', (l) => (locale = l))

  type Page = 'overview' | 'models' | Engine
  let page = $state<Page>('overview')
  let view = $state<Overview | null>(null)
  let error = $state('')

  // Models.
  let useCase = $state('any')
  let allPublishers = $state(false)
  let recs = $state<Recommendation | null>(null)
  let recsError = $state('')
  let recsLoading = $state(false)
  let recEngine = $state<Engine | null>(null)
  /// Models were asked for once: a failure stays on screen until Refresh.
  let recsAsked = $state(false)

  // MLX.
  let mlxModel = $state('')
  let mlxPort = $state('8585')
  let mlxBusy = $state(false)

  // Ollama.
  let ollamaModels = $state<Record<string, OllamaModel[]>>({})
  let pullModel = $state('')
  let ollamaError = $state('')

  const job = new JobRun()

  function said(e: unknown): string {
    if (!(e instanceof DeskError)) return String(e)
    const [code, rest] = (e.detail ?? '').split('\n', 2)
    if (code === 'llmfit') return t('llmfitFailed', { reason: rest ?? '' })
    if (code === 'invalidModel') return t('invalidModel')
    return e.detail || e.message
  }

  async function load() {
    try {
      const v = await desk.call<Overview>('view')
      view = v
      error = ''
      if (v.mlx?.service.model && !mlxModel) mlxModel = v.mlx.service.model
      if (v.mlx?.service.port) mlxPort = String(v.mlx.service.port)
      for (const o of v.ollama) void loadOllama(o.id)
    } catch (e) {
      error = said(e)
    }
  }

  async function loadOllama(instance: string) {
    try {
      ollamaModels = { ...ollamaModels, [instance]: await desk.call<OllamaModel[]>('ollamaModels', { instance }) }
    } catch (e) {
      ollamaError = said(e)
    }
  }

  async function recommend() {
    recsAsked = true
    recsLoading = true
    recsError = ''
    try {
      const r = await desk.call<Recommendation>('recommend', { useCase: useCase === 'any' ? null : useCase, allPublishers })
      recs = r
      if (!recEngine || !r.engines.includes(recEngine)) recEngine = r.engines[0] ?? null
    } catch (e) {
      recsError = said(e)
    } finally {
      recsLoading = false
    }
  }

  // A starting server, or an engine being set up, is followed while the
  // page is open.
  $effect(() => {
    const busy =
      (view?.mlx?.service.model && !view.mlx.service.running) ||
      view?.engines.some((f) => f.deployed && (f.deployed.state === 'installing' || f.deployed.health === 'starting'))
    if (!busy) return
    const timer = setInterval(() => void load(), 3000)
    return () => clearInterval(timer)
  })

  $effect(() => {
    if (page === 'models' && !recsAsked) void recommend()
  })

  const fit = (e: Engine) => view?.engines.find((f) => f.engine === e)

  function blockedText(code: string): string {
    const known = ['needsLinux', 'needsAppleSilicon', 'needsPython', 'needsOllamaApp', 'needsDocker', 'needsGpu', 'needsNvidia', 'needsGpuContainers', 'gpuTooOld', 'gpuTooSmall']
    return known.includes(code) ? t(code) : code
  }

  /// Where an engine stands: blocked, deployed (and how it is), or ready to set up.
  function stateOf(f: EngineFit): { text: string; tone: 'success' | 'warning' | 'danger' | 'neutral' } {
    if (f.blocked) return { text: blockedText(f.blocked), tone: 'neutral' }
    if (f.engine === 'mlx') {
      const svc = view?.mlx?.service
      if (svc?.running) return { text: t('serving', { model: svc.model ?? '' }), tone: 'success' }
      return view?.mlx?.installed ? { text: t('installed'), tone: 'neutral' } : { text: t('canRun'), tone: 'neutral' }
    }
    const d = f.deployed
    if (d?.state === 'installed') {
      const h = d.health
      return { text: h === 'healthy' ? t('running') : h === 'starting' ? t('starting') : (h ?? t('installed')), tone: h === 'healthy' ? 'success' : h === 'starting' ? 'warning' : h ? 'danger' : 'neutral' }
    }
    if (f.engine === 'ollama' && view?.ollama.some((o) => o.id === 'native')) return { text: t('foundOnMachine'), tone: 'success' }
    // Ollama's own install on a Mac, not answering.
    if (f.engine === 'ollama' && view?.hardware.os === 'darwin') return { text: t('notRunning'), tone: 'warning' }
    return { text: t('canRun'), tone: 'neutral' }
  }

  /// The engine's stack in the desk's own sheet, set up with [c] when given.
  async function setUp(f: EngineFit, c: Candidate | null) {
    if (!f.stack) return
    try {
      await desk.openStack(f.stack, { model: c?.setting, backend: f.backend })
      await load()
    } catch (e) {
      error = said(e)
    }
  }

  /// Runs [c] with its engine: MLX started with it, Ollama's pull, or the
  /// engine's setup with the model chosen.
  function run(c: Candidate) {
    const f = fit(c.engine)
    if (!f) return
    if (c.engine === 'mlx') mlxModel = c.setting
    else if (c.engine === 'ollama' && view?.ollama.length) pullModel = c.setting
    else void setUp(f, c)
    page = c.engine
  }

  async function installMlx() {
    await job.start('mlxInstall', {}, undefined, said)
    await load()
  }

  async function startMlx() {
    mlxBusy = true
    error = ''
    try {
      await desk.call('mlxStart', { model: mlxModel.trim(), port: Number(mlxPort) })
      await load()
    } catch (e) {
      error = said(e)
    } finally {
      mlxBusy = false
    }
  }

  async function stopMlx() {
    mlxBusy = true
    try {
      await desk.call('mlxStop')
      await load()
    } catch (e) {
      error = said(e)
    } finally {
      mlxBusy = false
    }
  }

  async function pull(instance: string) {
    ollamaError = ''
    const model = pullModel.trim()
    if ((await job.start('ollamaPull', { instance, model }, undefined, said)) !== undefined) pullModel = ''
    await loadOllama(instance)
  }

  async function remove(instance: string, model: string) {
    ollamaError = ''
    try {
      await desk.call('ollamaDelete', { instance, model })
      await loadOllama(instance)
    } catch (e) {
      ollamaError = said(e)
    }
  }

  const engines = $derived(view?.engines ?? [])
  const useCases = $derived([
    { value: 'any', label: t('useAny') },
    { value: 'general', label: t('useGeneral') },
    { value: 'coding', label: t('useCoding') },
    { value: 'reasoning', label: t('useReasoning') },
    { value: 'chat', label: t('useChat') },
    { value: 'multimodal', label: t('useMultimodal') },
    { value: 'embedding', label: t('useEmbedding') },
  ])
  const top = $derived(page === 'overview' || page === 'models' ? page : 'overview')

  void job.resume(said).then(() => load())
  void load()
</script>

<main class="page wide">
  <div class="trail">
    <div class="grow">
      <SegmentedControl
        label={t('title')}
        options={[
          { value: 'overview', label: t('thisMachine') },
          { value: 'models', label: t('models') },
        ]}
        value={top}
        onchange={(v) => (page = v as Page)}
      />
    </div>
    <IconButton icon="refresh" label={t('refresh')} onclick={() => void (page === 'models' ? recommend() : load())} />
  </div>
  {#if error}
    <Card><p class="error"><Icon name="error" size={17} /><span>{error}</span></p></Card>
  {/if}
  {#if job.status}
    <JobLog
      {t}
      status={job.status}
      title={job.fn === 'mlxInstall'
        ? job.running ? t('installingMlx') : job.status === 'succeeded' ? t('installed') : t('installFailed')
        : job.running ? t('pulling') : job.status === 'succeeded' ? t('pulled') : t('pullFailed')}
      lines={job.lines}
      oncancel={() => job.cancel()}
    />
  {/if}

  {#if !view}
    {#if !error}<div class="center"><Spinner /></div>{/if}
  {:else if page === 'overview'}
    {@const hw = view.hardware}
    <Group title={t('thisMachine')}>
      <Row label={t('system')} value={`${hw.os} · ${hw.arch}`} mono />
      <Row label={t('memory')} value={mibAsGib(hw.memoryMib)} />
      {#each hw.gpus as g, i (i)}
        <Row label={g.name} sub={g.compute ? t('compute', { cc: (g.compute / 10).toFixed(1) }) : undefined} value={g.memoryMib ? mibAsGib(g.memoryMib) : g.vendor} />
      {:else}
        <Row label={t('gpu')} value={t('noGpu')} />
      {/each}
      {#if hw.os === 'linux'}
        <Row label="Docker" value={hw.docker ? (hw.nvidiaContainers ? t('dockerGpu') : t('dockerCpu')) : t('noDocker')} />
      {/if}
    </Group>

    <Group title={t('engines')}>
      {#each engines as f, i (f.engine)}
        {@const st = stateOf(f)}
        <Row
          label={ENGINE_NAMES[f.engine]}
          sub={f.blocked ? undefined : [i === 0 ? t('bestHere') : f.backend.toUpperCase(), f.cpuBecause ? blockedText(f.cpuBecause) : ''].filter(Boolean).join(' · ')}
          onclick={() => (page = f.engine)}
        >
          <Badge tone={st.tone}>{st.text}</Badge>
        </Row>
      {/each}
    </Group>
    <p class="hint">{t('agentNote')}</p>
  {:else if page === 'models'}
    <div class="trail wrap">
      <Select class="grow" label={t('useCase')} options={useCases} bind:value={useCase} onchange={() => void recommend()} />
      <Switch label={t('allPublishers')} checked={allPublishers} onchange={(on) => { allPublishers = on; void recommend() }} />
      <span class="hint">{t('allPublishers')}</span>
    </div>
    {#if recs && recs.engines.length > 1 && recEngine}
      <SegmentedControl label={t('engines')} options={recs.engines.map((e) => ({ value: e, label: ENGINE_NAMES[e] }))} value={recEngine} onchange={(e) => (recEngine = e as Engine)} />
    {/if}
    {#if recsError}
      <Card><p class="error"><Icon name="error" size={17} /><span>{recsError}</span></p></Card>
    {/if}
    {#if recsLoading}
      <div class="center"><Spinner /></div>
    {:else if recs && recEngine}
      {@const list = recs.candidates.filter((c) => c.engine === recEngine)}
      <Group title={t('fitsWith', { engine: ENGINE_NAMES[recEngine] })}>
        {#each list as c (c.setting)}
          <Row
            label={c.name}
            sub={[
              c.paramsB ? `${c.paramsB.toFixed(1)}B` : '',
              gib(c.memoryGib),
              c.tokensPerSecond ? t('tokensPerSecond', { n: Math.round(c.tokensPerSecond) }) : '',
              c.license ?? '',
              c.setting !== c.name ? c.setting : '',
            ].filter(Boolean).join(' · ')}
          >
            <Badge tone={c.fit === 'perfect' ? 'success' : c.fit === 'good' ? 'neutral' : 'warning'}>
              {c.fit === 'perfect' ? t('fitPerfect') : c.fit === 'good' ? t('fitGood') : t('fitMarginal')}
            </Badge>
            <Button size="sm" icon="play_arrow" onclick={() => run(c)}>{t('run')}</Button>
          </Row>
        {:else}
          <p class="hint pad">{t('nothingFits')}</p>
        {/each}
      </Group>
      <p class="hint">{t('byLlmfit', { version: view.llmfitVersion })}</p>
    {:else if recs}
      <p class="hint">{t('noEngine')}</p>
    {/if}
  {:else}
    {@const f = fit(page)}
    <div class="trail">
      <Button size="sm" variant="ghost" icon="chevron_left" onclick={() => (page = 'overview')}>{t('thisMachine')}</Button>
      <strong class="grow">{ENGINE_NAMES[page]}</strong>
    </div>
    {#if f?.blocked}
      <Card><p class="note"><Icon name="info" size={17} /><span>{blockedText(f.blocked)}</span></p></Card>
    {/if}

    {#if page === 'mlx'}
      {#if view.mlx && !f?.blocked}
        {@const svc = view.mlx.service}
        <Group title="MLX">
          <Row label="mlx-lm" value={view.mlx.installed ? view.mlx.version : t('notInstalled')}>
            {#if !view.mlx.installed}<Button size="sm" icon="download" disabled={job.running} onclick={installMlx}>{t('install')}</Button>{/if}
          </Row>
          {#if svc.model}
            <Row label={svc.model} mono sub={svc.port ? `http://127.0.0.1:${svc.port}/v1` : undefined}>
              <Badge tone={svc.running ? 'success' : 'warning'}>{svc.running ? t('running') : t('starting')}</Badge>
              <Button size="sm" variant="secondary" icon="stop" disabled={mlxBusy} onclick={stopMlx}>{t('stop')}</Button>
            </Row>
          {/if}
        </Group>
        {#if view.mlx.installed}
          <Group title={t('serve')}>
            <div class="trail wrap pad">
              <Input class="grow" label={t('model')} mono placeholder="mlx-community/Qwen3-8B-4bit" bind:value={mlxModel} />
              <Input class="port" label={t('port')} mono bind:value={mlxPort} />
              <Button variant="primary" icon="play_arrow" disabled={mlxBusy || !mlxModel.trim()} onclick={startMlx}>{svc.model ? t('replace') : t('start')}</Button>
            </div>
            <p class="hint pad">{t('mlxNote')}</p>
          </Group>
        {/if}
      {/if}
    {:else}
      {#if page === 'ollama'}
        {#each view.ollama as o (o.id)}
          <Group title={o.id === 'native' ? t('ollamaNative') : t('ollamaDeployed')}>
            <Row label={o.url} mono value={o.version ?? ''} />
            {#each ollamaModels[o.id] ?? [] as model (model.name)}
              <Row label={model.name} mono sub={[formatBytes(model.size), model.parameterSize, model.quantization].filter(Boolean).join(' · ')}>
                {#if model.loaded}<Badge tone="success">{t('loaded')}</Badge>{/if}
                <IconButton icon="delete" label={t('removeModel')} onclick={() => void remove(o.id, model.name)} />
              </Row>
            {/each}
            <div class="trail wrap pad">
              <Input class="grow" label={t('pullLabel')} mono placeholder="qwen3:8b" bind:value={pullModel} />
              <Button variant="primary" icon="download" disabled={!pullModel.trim() || job.running} onclick={() => void pull(o.id)}>{t('pull')}</Button>
            </div>
          </Group>
        {/each}
        {#if !f?.blocked && view.hardware.os === 'darwin' && !view.ollama.length}
          <Card><p class="note"><Icon name="info" size={17} /><span>{t('ollamaStart')}</span></p></Card>
        {/if}
        {#if ollamaError}<p class="danger">{ollamaError}</p>{/if}
      {/if}
      {#if f?.stack && view.hardware.os !== 'darwin' && !(page === 'ollama' && view.ollama.some((o) => o.id === 'native') && !f.deployed)}
        <Group>
          <Row label={ENGINE_NAMES[page]} sub={f.deployed ? stateOf(f).text : t('canRun')}>
            <Button size="sm" variant={f.deployed ? 'secondary' : 'primary'} disabled={!!f.blocked} onclick={() => void setUp(f, null)}>
              {f.deployed ? t('manage') : t('setUp')}
            </Button>
          </Row>
        </Group>
      {/if}
    {/if}
  {/if}
</main>

<style>
  .wide {
    max-width: 920px;
  }

  .page :global(.port) {
    width: 110px;
  }
</style>
