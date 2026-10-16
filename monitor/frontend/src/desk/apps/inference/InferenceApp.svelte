<script lang="ts">
  /// Local inference (`/inference`): this machine's hardware and the engines
  /// that run on it, llmfit's models for each, and the engines themselves.
  /// Ollama, llama.cpp, vLLM and SGLang are stacks set up here (`StackDetail`,
  /// the agent's `source: 'part'`); MLX runs natively on Apple Silicon. Each
  /// model server joins Agent mode as a provider on its own.

  import { AppToolbar, SplitView } from '../../sys'
  import { Badge, Button, Card, Group, Icon, IconButton, Input, Row, SegmentedControl, Select, SidebarItem, SidebarSection, Spinner, Switch } from '../../lk'
  import StackDetail from '../../../components/stack/StackDetail.svelte'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import { errorText } from '../../../lib/errorText'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import type {
    InferenceCandidate,
    InferenceEngine,
    InferenceEngineFit,
    InferenceRecommend,
    InferenceView,
    OllamaModels,
    StackApp,
    StackJob,
    StackValue,
  } from '../../../types'
  import { ENGINE_NAMES, bytes, gib, mibAsGib, presetFor } from './model'

  type Page = 'overview' | 'models' | InferenceEngine

  let page = $state<Page>('overview')
  let view = $state<InferenceView | null>(null)
  let stacks = $state<StackApp[]>([])
  let error = $state('')
  const { stale } = useScope()

  // Models.
  let useCase = $state('any')
  let allPublishers = $state(false)
  let recs = $state<InferenceRecommend | null>(null)
  let recsError = $state('')
  let recsLoading = $state(false)
  let recEngine = $state<InferenceEngine | null>(null)

  /// What an engine's page opens with: the stack's setup with a model.
  let preset = $state<{ engine: InferenceEngine; values: Record<string, StackValue> } | null>(null)
  /// The key the engine page is drawn under: a new preset draws it anew.
  let pageKey = $state(0)

  // MLX.
  let mlxModel = $state('')
  let mlxPort = $state('8585')
  let mlxBusy = $state(false)
  let job = $state<StackJob | null>(null)

  // Ollama.
  let ollamaModels = $state<Record<string, OllamaModels>>({})
  let pullModel = $state('')
  let ollamaError = $state('')

  async function load(serverId = servers.currentId) {
    try {
      const [v, list] = await Promise.all([api.getInference(), api.listStacks()])
      if (stale(serverId)) return
      view = v
      stacks = list.apps.filter((a) => a.source === 'part')
      error = ''
      if (v.job?.state === 'running') job = v.job
      if (v.mlx?.service.model && !mlxModel) mlxModel = v.mlx.service.model
      if (v.mlx?.service.port) mlxPort = String(v.mlx.service.port)
      for (const o of v.ollama) void loadOllama(o.id, serverId)
    } catch (e) {
      if (!stale(serverId)) error = errorText(e)
    }
  }

  async function loadOllama(instance: string, serverId = servers.currentId) {
    try {
      const m = await api.ollamaModels(instance)
      if (!stale(serverId)) ollamaModels = { ...ollamaModels, [instance]: m }
    } catch (e) {
      if (!stale(serverId)) ollamaError = errorText(e)
    }
  }

  async function recommend(serverId = servers.currentId) {
    recsLoading = true
    recsError = ''
    try {
      const r = await api.recommendModels(useCase === 'any' ? null : useCase, allPublishers)
      if (stale(serverId)) return
      recs = r
      if (!recEngine || !r.engines.includes(recEngine)) recEngine = r.engines[0] ?? null
    } catch (e) {
      if (stale(serverId)) return
      recsError = e instanceof ApiError && e.body?.error === 'llmfit' ? $LL.inferenceLlmfitFailed({ reason: String(e.body?.reason ?? '') }) : errorText(e)
    } finally {
      if (!stale(serverId)) recsLoading = false
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
  })

  // Pulls and a starting server are followed while the page is open.
  $effect(() => {
    const busy = view?.pulls.some((p) => !p.done) || (view?.mlx?.service.model && !view.mlx.service.running)
    if (!busy) return
    const t = setInterval(() => void load(), 3000)
    return () => clearInterval(t)
  })

  $effect(() => {
    if (page === 'models' && !recs && !recsLoading) void recommend()
  })

  const fit = (e: InferenceEngine) => view?.engines.find((f) => f.engine === e)
  const stackOf = (f: InferenceEngineFit | undefined) => (f?.app ? stacks.find((s) => s.manifest.id === f.app) : undefined)

  function blockedText(code: string): string {
    const map: Record<string, () => string> = {
      needsLinux: $LL.inferenceNeedsLinux,
      needsAppleSilicon: $LL.inferenceNeedsAppleSilicon,
      needsPython: $LL.inferenceNeedsPython,
      needsOllamaApp: $LL.inferenceNeedsOllamaApp,
      needsDocker: $LL.inferenceNeedsDocker,
      needsGpu: $LL.inferenceNeedsGpu,
      needsNvidia: $LL.inferenceNeedsNvidia,
      needsGpuContainers: $LL.inferenceNeedsGpuContainers,
      gpuTooOld: $LL.inferenceGpuTooOld,
      gpuTooSmall: $LL.inferenceGpuTooSmall,
    }
    return map[code]?.() ?? code
  }

  /// Where an engine stands: blocked, deployed (and how it is), or ready to set up.
  function stateOf(f: InferenceEngineFit): { text: string; tone: 'success' | 'warning' | 'danger' | 'neutral' } {
    if (f.blocked) return { text: blockedText(f.blocked), tone: 'neutral' }
    if (f.engine === 'mlx') {
      const svc = view?.mlx?.service
      if (svc?.running) return { text: $LL.inferenceServing({ model: svc.model ?? '' }), tone: 'success' }
      return view?.mlx?.installed ? { text: $LL.inferenceInstalled(), tone: 'neutral' } : { text: $LL.inferenceCanRun(), tone: 'neutral' }
    }
    const s = stackOf(f)?.stack
    if (s?.state === 'installed') {
      const h = stackOf(f)?.health?.state
      return { text: h === 'healthy' ? $LL.inferenceRunning() : h === 'starting' ? $LL.inferenceStarting() : (h ?? $LL.inferenceInstalled()), tone: h === 'healthy' ? 'success' : h === 'starting' ? 'warning' : h ? 'danger' : 'neutral' }
    }
    if (f.engine === 'ollama' && view?.ollama.some((o) => o.id === 'native')) return { text: $LL.inferenceFoundOnMachine(), tone: 'success' }
    // Ollama's own install on a Mac, not answering.
    if (f.engine === 'ollama' && view?.hardware.os === 'darwin') return { text: $LL.inferenceNotRunning(), tone: 'warning' }
    return { text: $LL.inferenceCanRun(), tone: 'neutral' }
  }

  /// Runs [c] with its engine: the engine's setup with the model chosen, MLX
  /// started with it, or Ollama's pull.
  function run(c: InferenceCandidate) {
    const f = fit(c.engine)
    if (!f) return
    if (c.engine === 'mlx') {
      mlxModel = c.setting
    } else if (c.engine === 'ollama') {
      pullModel = c.setting
    } else {
      const s = stackOf(f)
      if (s) preset = { engine: c.engine, values: presetFor(f, s.manifest, c) }
    }
    pageKey++
    page = c.engine
  }

  function setUp(e: InferenceEngine) {
    const f = fit(e)
    const s = stackOf(f)
    preset = f && s && !s.stack ? { engine: e, values: presetFor(f, s.manifest, null) } : null
    pageKey++
    page = e
  }

  async function installMlx() {
    error = ''
    try {
      job = await api.installMlx()
    } catch (e) {
      error = errorText(e)
    }
  }

  async function startMlx() {
    mlxBusy = true
    error = ''
    try {
      await api.startMlx(mlxModel.trim(), Number(mlxPort))
      await load()
    } catch (e) {
      error = e instanceof ApiError && e.body?.error === 'invalidModel' ? $LL.inferenceInvalidModel() : errorText(e)
    } finally {
      mlxBusy = false
    }
  }

  async function stopMlx() {
    mlxBusy = true
    try {
      await api.stopMlx()
      await load()
    } catch (e) {
      error = errorText(e)
    } finally {
      mlxBusy = false
    }
  }

  async function pull(instance: string) {
    ollamaError = ''
    try {
      await api.pullOllama(instance, pullModel.trim())
      pullModel = ''
      await load()
    } catch (e) {
      ollamaError = e instanceof ApiError && e.body?.error === 'invalidModel' ? $LL.inferenceInvalidModel() : errorText(e)
    }
  }

  async function remove(instance: string, model: string) {
    ollamaError = ''
    try {
      await api.deleteOllama(instance, model)
      await loadOllama(instance)
    } catch (e) {
      ollamaError = errorText(e)
    }
  }

  const engines = $derived(view?.engines ?? [])
  const title = $derived(page === 'overview' ? null : page === 'models' ? $LL.inferenceModels() : ENGINE_NAMES[page])
  const useCases = $derived([
    { value: 'any', label: $LL.inferenceUseAny() },
    { value: 'general', label: $LL.inferenceUseGeneral() },
    { value: 'coding', label: $LL.inferenceUseCoding() },
    { value: 'reasoning', label: $LL.inferenceUseReasoning() },
    { value: 'chat', label: $LL.inferenceUseChat() },
    { value: 'multimodal', label: $LL.inferenceUseMultimodal() },
    { value: 'embedding', label: $LL.inferenceUseEmbedding() },
  ])
</script>

<AppToolbar title={title ?? undefined}>
  {#snippet actions()}
    {#if page === 'models'}
      <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void recommend()} />
    {:else}
      <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} />
    {/if}
  {/snippet}
</AppToolbar>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection>
      <SidebarItem label={$LL.inferenceThisMachine()} icon="memory" active={page === 'overview'} onclick={() => (page = 'overview')} />
      <SidebarItem label={$LL.inferenceModels()} icon="neurology" active={page === 'models'} onclick={() => (page = 'models')} />
    </SidebarSection>
    <SidebarSection title={$LL.inferenceEngines()}>
      {#each engines as f (f.engine)}
        <SidebarItem
          label={ENGINE_NAMES[f.engine]}
          icon={f.blocked ? 'block' : 'deployed_code'}
          active={page === f.engine}
          onclick={() => {
            preset = null
            page = f.engine
          }}
        />
      {/each}
    </SidebarSection>
  {/snippet}

  <div class="mx-auto max-w-[920px] space-y-[13px] px-(--content-pad) pb-[21px]">
    {#if error}
      <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} /><p class="break-all">{error}</p></Card>
    {/if}

    {#if !view}
      {#if !error}<div class="grid place-items-center py-[55px]"><Spinner /></div>{/if}
    {:else if page === 'overview'}
      {@const hw = view.hardware}
      <Group title={$LL.inferenceThisMachine()}>
        <Row label={$LL.inferenceSystem()} value={`${hw.os} · ${hw.arch}`} mono />
        <Row label={$LL.inferenceMemory()} value={mibAsGib(hw.memoryMib)} />
        {#each hw.gpus as g, i (i)}
          <Row
            label={g.name}
            sub={g.compute ? $LL.inferenceCompute({ cc: (g.compute / 10).toFixed(1) }) : undefined}
            value={g.memoryMib ? mibAsGib(g.memoryMib) : g.vendor}
          />
        {:else}
          <Row label={$LL.inferenceGpu()} value={$LL.inferenceNoGpu()} />
        {/each}
        {#if hw.os === 'linux'}
          <Row label="Docker" value={hw.docker ? (hw.nvidiaContainers ? $LL.inferenceDockerGpu() : $LL.inferenceDockerCpu()) : $LL.inferenceNoDocker()} />
        {/if}
      </Group>

      <Group title={$LL.inferenceEngines()}>
        {#each engines as f, i (f.engine)}
          {@const st = stateOf(f)}
          <Row
            label={ENGINE_NAMES[f.engine]}
            sub={f.blocked ? undefined : [i === 0 ? $LL.inferenceBestHere() : f.backend.toUpperCase(), f.cpuBecause ? blockedText(f.cpuBecause) : ''].filter(Boolean).join(' · ')}
            onclick={() => setUp(f.engine)}
          >
            <Badge tone={st.tone}>{st.text}</Badge>
          </Row>
        {/each}
      </Group>
      <p class="px-[2px] text-[12px] text-(--text-tertiary)">{$LL.inferenceAgentNote()}</p>
    {:else if page === 'models'}
      <div class="flex flex-wrap items-end gap-[11px]">
        <Select class="w-[200px]" label={$LL.inferenceUseCase()} options={useCases} bind:value={useCase} onchange={() => void recommend()} />
        <div class="flex items-center gap-[9px] pb-[7px] text-[13px]">
          <Switch label={$LL.inferenceAllPublishers()} checked={allPublishers} onchange={(on) => { allPublishers = on; void recommend() }} />
          <span>{$LL.inferenceAllPublishers()}</span>
        </div>
      </div>
      {#if recs && recs.engines.length > 1 && recEngine}
        <SegmentedControl options={recs.engines.map((e) => ({ value: e, label: ENGINE_NAMES[e] }))} value={recEngine} onchange={(e) => (recEngine = e)} />
      {/if}
      {#if recsError}
        <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} /><p class="break-all">{recsError}</p></Card>
      {/if}
      {#if recsLoading}
        <div class="grid place-items-center py-[34px]"><Spinner /></div>
      {:else if recs && recEngine}
        {@const list = recs.candidates[recEngine] ?? []}
        <Group title={$LL.inferenceFitsWith({ engine: ENGINE_NAMES[recEngine] })}>
          {#each list as c (c.setting)}
            <Row
              label={c.name}
              sub={[
                c.paramsB ? `${c.paramsB.toFixed(1)}B` : '',
                gib(c.memoryGib),
                c.tokensPerSecond ? $LL.inferenceTokensPerSecond({ n: Math.round(c.tokensPerSecond) }) : '',
                c.license ?? '',
                c.setting !== c.name ? c.setting : '',
              ].filter(Boolean).join(' · ')}
            >
              <Badge tone={c.fit === 'perfect' ? 'success' : c.fit === 'good' ? 'neutral' : 'warning'}>
                {c.fit === 'perfect' ? $LL.inferenceFitPerfect() : c.fit === 'good' ? $LL.inferenceFitGood() : $LL.inferenceFitMarginal()}
              </Badge>
              <Button size="sm" icon="play_arrow" onclick={() => run(c)}>{$LL.inferenceRun()}</Button>
            </Row>
          {:else}
            <p class="px-[13px] py-[11px] text-[13px] text-(--text-tertiary)">{$LL.inferenceNothingFits()}</p>
          {/each}
        </Group>
        <p class="px-[2px] text-[12px] text-(--text-tertiary)">{$LL.inferenceByLlmfit({ version: view.llmfit.version })}</p>
      {:else if recs}
        <p class="px-[2px] text-[13px] text-(--text-tertiary)">{$LL.inferenceNoEngine()}</p>
      {/if}
    {:else}
      {@const f = fit(page)}
      {#if f?.blocked}
        <Card class="flex items-start gap-[9px] text-[13px] text-(--text-secondary)"><Icon name="info" size={17} /><p>{blockedText(f.blocked)}</p></Card>
      {/if}

      {#if page === 'mlx'}
        {#if job}
          {#key job.id}
            <StackProgress
              {job}
              title={job.state === 'running' ? $LL.inferenceInstallingMlx() : job.state === 'succeeded' ? $LL.inferenceInstalled() : $LL.inferenceInstallFailed()}
              read={(since) => api.inferenceJob(since)}
              stop={() => api.cancelInferenceJob()}
              ondone={() => {
                job = null
                void load()
              }}
            />
          {/key}
        {:else if view.mlx && !f?.blocked}
          {@const svc = view.mlx.service}
          <Group title="MLX">
            <Row label="mlx-lm" value={view.mlx.installed ? view.mlx.version : $LL.inferenceNotInstalled()}>
              {#if !view.mlx.installed}<Button size="sm" icon="download" onclick={installMlx}>{$LL.inferenceInstall()}</Button>{/if}
            </Row>
            {#if svc.model}
              <Row label={svc.model} mono sub={svc.port ? `http://127.0.0.1:${svc.port}/v1` : undefined}>
                <Badge tone={svc.running ? 'success' : 'warning'}>{svc.running ? $LL.inferenceRunning() : $LL.inferenceStarting()}</Badge>
                <Button size="sm" variant="secondary" icon="stop" disabled={mlxBusy} onclick={stopMlx}>{$LL.inferenceStop()}</Button>
              </Row>
            {/if}
          </Group>
          {#if view.mlx.installed}
            <Group title={$LL.inferenceServe()}>
              <div class="flex flex-wrap items-end gap-[11px] px-[13px] py-[11px]">
                <Input class="min-w-[260px] flex-1" label={$LL.inferenceModel()} mono placeholder="mlx-community/Qwen3-8B-4bit" bind:value={mlxModel} />
                <Input class="w-[110px]" label={$LL.inferencePort()} mono bind:value={mlxPort} />
                <Button variant="primary" icon="play_arrow" disabled={mlxBusy || !mlxModel.trim()} onclick={startMlx}>{svc.model ? $LL.inferenceReplace() : $LL.inferenceStart()}</Button>
              </div>
              <p class="px-[13px] pb-[11px] text-[12px] text-(--text-tertiary)">{$LL.inferenceMlxNote()}</p>
            </Group>
          {/if}
        {/if}
      {:else}
        {@const s = stackOf(f)}
        {#if page === 'ollama'}
          {#each view.ollama as o (o.id)}
            {@const m = ollamaModels[o.id]}
            <Group title={o.id === 'native' ? $LL.inferenceOllamaNative() : $LL.inferenceOllamaDeployed()}>
              <Row label={o.url} mono value={o.version ?? ''} />
              {#each m?.models ?? [] as model (model.name)}
                {@const loaded = m?.running?.some((r) => r.name === model.name)}
                <Row label={model.name} mono sub={[bytes(model.size), model.details?.parameter_size, model.details?.quantization_level].filter(Boolean).join(' · ')}>
                  {#if loaded}<Badge tone="success">{$LL.inferenceLoaded()}</Badge>{/if}
                  <IconButton icon="delete" label={$LL.inferenceRemoveModel()} onclick={() => void remove(o.id, model.name)} />
                </Row>
              {/each}
              {#each view.pulls.filter((p) => p.instance === o.id && (!p.done || p.error)) as p (p.model)}
                <Row label={p.model} mono sub={p.error ?? p.status}>
                  {#if !p.done}
                    <span class="lk-num text-[12px] text-(--text-secondary)">{p.total ? `${Math.round(((p.completed ?? 0) / p.total) * 100)}%` : ''}</span>
                    <Spinner size="sm" />
                  {:else}
                    <Badge tone="danger">{$LL.inferencePullFailed()}</Badge>
                  {/if}
                </Row>
              {/each}
              <div class="flex flex-wrap items-end gap-[11px] px-[13px] py-[11px]">
                <Input class="min-w-[240px] flex-1" label={$LL.inferencePullLabel()} mono placeholder="qwen3:8b" bind:value={pullModel} />
                <Button variant="primary" icon="download" disabled={!pullModel.trim()} onclick={() => void pull(o.id)}>{$LL.inferencePull()}</Button>
              </div>
            </Group>
          {/each}
          {#if !f?.blocked && view.hardware.os === 'darwin' && !view.ollama.length}
            <Card class="flex items-start gap-[9px] text-[13px] text-(--text-secondary)"><Icon name="info" size={17} /><p>{$LL.inferenceOllamaStart()}</p></Card>
          {/if}
          {#if ollamaError}<p class="px-[2px] text-[13px] text-(--color-danger)">{ollamaError}</p>{/if}
        {/if}
        {#if s && view.hardware.os !== 'darwin' && !(page === 'ollama' && view.ollama.some((o) => o.id === 'native') && !s.stack)}
          {#key `${page}-${pageKey}`}
            <StackDetail
              stackId={s.manifest.id}
              openable={false}
              preset={preset?.engine === page && !f?.blocked ? preset.values : undefined}
              onchanged={() => void load()}
            />
          {/key}
        {/if}
      {/if}
    {/if}
  </div>
</SplitView>
