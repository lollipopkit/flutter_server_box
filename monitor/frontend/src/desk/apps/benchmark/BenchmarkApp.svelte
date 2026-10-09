<script lang="ts">
  import { AppIcon, Badge, Button, Card, Checkbox, Dialog, Icon, IconButton, Input, Select, Spinner } from '../../lk'
  import { AppToolbar } from '../../sys'
  import { api } from '../../../lib/api'
  import { benchRefusalText, benchRunErrorText } from '../../../lib/benchRefusal'
  import { fmtBytes, fmtTime } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type { BenchDetail, BenchEstimate, BenchOptions, BenchRun, BenchView } from '../../../types'

  /// The agent's own defaults, spelled here because the form starts from them
  /// rather than from whatever the last run used. Three of them differ from
  /// yabs' own, each in the direction that spends less or discloses less, and a
  /// form that remembered the previous run would repeat a Geekbench run by
  /// default.
  const DEFAULT_OPTIONS: BenchOptions = {
    disk: true,
    network: true,
    reduced_network: true,
    cpu: false,
    geekbench_version: 'v6',
    ip_info: false,
    prefer_precompiled_binaries: false,
    work_dir: '',
  }

  /// The Geekbench releases yabs can run. Mirrors `GeekbenchVersion` in
  /// `sbm_parser::bench`, so no digit this offers is one the agent would refuse.
  const GEEKBENCH_VERSIONS = ['v4', 'v5', 'v6', 'v7']

  /// How often a run that is going is re-read: the agent's own poller interval,
  /// so the page follows the state the agent maintains rather than asking for a
  /// fresher one than exists.
  const LIVE_POLL_MS = 2_000

  /// How soon to ask again when a reply already carried the end of the run.
  /// `benchmark_run` is read before the agent's own poll is folded in, so on
  /// that one reply the row still says `running` while the live state says it
  /// ended. Asking again settles the row.
  const SETTLE_POLL_MS = 300

  /// The estimate is asked for on a pause in typing rather than on every
  /// keystroke of the working directory.
  const ESTIMATE_DEBOUNCE_MS = 250

  let view = $state<BenchView | null>(null)
  let loading = $state(true)
  let error = $state('')
  /// A success worth naming, cleared by the next action.
  let notice = $state('')
  let busy = $state(false)
  let options = $state<BenchOptions>({ ...DEFAULT_OPTIONS })
  let estimate = $state<BenchEstimate | null>(null)
  let estimateFailed = $state(false)
  /// Which estimate request is the current one. See [`estimateFor`].
  let estimateSeq = 0
  /// The clock the elapsed time is drawn against. Ticked by the poll rather
  /// than by a timer of its own, so a page with no run going runs none.
  let now = $state(Date.now())
  let detail = $state<BenchDetail | null>(null)
  let detailLoading = $state(false)
  /// Which detail request is the current one. The dialog can be closed while
  /// one is in flight, and the reply would otherwise reopen it.
  let detailSeq = 0
  let confirmingStop = $state(false)
  let confirmingRemove = $state<BenchRun | undefined>(undefined)

  let pollTimer: ReturnType<typeof setTimeout> | undefined
  let estimateTimer: ReturnType<typeof setTimeout> | undefined

  /// The page belongs to one server, so a reply that arrives after the user
  /// has switched servers belongs to neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId: string | null = servers.currentId) {
    loading = true
    try {
      const next = await api.getBenchmark()
      if (stale(serverId)) return
      view = next
      now = Date.now()
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
    scheduleLive(serverId)
  }

  /// Scheduled after the reply rather than by a timer started before it, so a
  /// slow agent is asked again after the answer it gave rather than on top of
  /// it. Nothing is scheduled once no run is going.
  function scheduleLive(serverId: string | null) {
    clearTimeout(pollTimer)
    const live = view?.live
    if (!live) return
    const settled = live.answered && live.exit_code !== null
    pollTimer = setTimeout(() => void load(serverId), settled ? SETTLE_POLL_MS : LIVE_POLL_MS)
  }

  async function refresh() {
    await load()
    await estimateFor(options)
  }

  /// The estimate is a function of the options and the agent is the one that
  /// computes it, so this page never re-derives the formula.
  ///
  /// Answered without the shell grant, so a read-only page still says what a
  /// run would cost. A failure leaves the last answer on screen and marks the
  /// line rather than blanking it: the form is usable either way.
  ///
  /// Numbered, because two keystrokes are two requests and the first can come
  /// back second — the line would then describe options that are no longer on
  /// screen.
  async function estimateFor(payload: BenchOptions) {
    const seq = ++estimateSeq
    try {
      const next = await api.estimateBenchmark(payload)
      if (seq !== estimateSeq) return
      estimate = next
      estimateFailed = false
    } catch {
      if (seq !== estimateSeq) return
      estimateFailed = true
    }
  }

  /// The estimate follows the form. `supported` is read untracked because the
  /// view changes on every poll and the answer to "does this machine run yabs"
  /// does not.
  $effect(() => {
    const payload: BenchOptions = { ...options }
    clearTimeout(estimateTimer)
    if (untrack(() => view?.supported === false)) return
    estimateTimer = setTimeout(() => void estimateFor(payload), ESTIMATE_DEBOUNCE_MS)
  })

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
    return () => {
      clearTimeout(pollTimer)
      clearTimeout(estimateTimer)
    }
  })

  async function start() {
    busy = true
    error = ''
    notice = ''
    try {
      const started = await api.startBenchmark(options)
      notice = $LL.benchmarkStarted({ id: started.run.id })
      await load()
    } catch (e) {
      error = benchRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      busy = false
    }
  }

  async function stop() {
    confirmingStop = false
    busy = true
    error = ''
    notice = ''
    try {
      await api.cancelBenchmark()
      await load()
    } catch (e) {
      error = benchRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      busy = false
    }
  }

  async function remove(run: BenchRun) {
    confirmingRemove = undefined
    busy = true
    error = ''
    notice = ''
    try {
      await api.removeBenchmark(run.id)
      await load()
    } catch (e) {
      error = benchRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      busy = false
    }
  }

  /// One run in full. The two large columns are not in the listing, so this is
  /// the request that carries them.
  async function open(run: BenchRun) {
    const seq = ++detailSeq
    detailLoading = true
    detail = null
    const serverId = servers.currentId
    try {
      const next = await api.getBenchmarkRun(run.id)
      if (stale(serverId) || seq !== detailSeq) return
      detail = next
    } catch (e) {
      if (stale(serverId) || seq !== detailSeq) return
      error = benchRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      if (seq === detailSeq) detailLoading = false
    }
  }

  /// Closing the dialog also drops a reply that is still on its way.
  function closeDetail() {
    detailSeq++
    detail = null
    detailLoading = false
  }

  const supported = $derived(view?.supported === true)
  const live = $derived(view?.live)
  /// A run is going until the machine says it ended. An unanswered poll says
  /// nothing, so it leaves this true — reading it as "no run" would put the
  /// form back on screen over a run that is going perfectly well.
  const running = $derived(live !== undefined && (live.answered ? live.exit_code === null : true))
  /// The row the live state belongs to, which is where the elapsed time is
  /// counted from.
  const liveRun = $derived(view?.runs.find((run) => run.id === live?.id))
  /// The runs the history shows. A run that is going is drawn above the form
  /// instead, so it is not repeated here.
  const finished = $derived((view?.runs ?? []).filter((run) => run.status !== 'running'))

  /// Minutes and seconds, which is the range a benchmark lives in.
  function elapsedText(startedAt: string): string {
    const seconds = Math.max(0, Math.round((now - new Date(startedAt).getTime()) / 1000))
    const minutes = Math.floor(seconds / 60)
    return `${minutes}m ${String(seconds % 60).padStart(2, '0')}s`
  }

  function statusTone(status: string): 'success' | 'danger' | 'warning' | 'neutral' {
    switch (status) {
      case 'completed':
        return 'success'
      case 'failed':
        return 'danger'
      case 'cancelled':
        return 'warning'
      default:
        return 'neutral'
    }
  }

  function statusText(status: string): string {
    switch (status) {
      case 'running':
        return $LL.benchmarkStatusRunning()
      case 'completed':
        return $LL.benchmarkStatusCompleted()
      case 'failed':
        return $LL.benchmarkStatusFailed()
      case 'cancelled':
        return $LL.benchmarkStatusCancelled()
      default:
        return status
    }
  }

  /// Which phases a recorded run asked for, in the form's own words. Named by
  /// `BenchOptions`' keys, so a phase added to the model without a label is a
  /// type error rather than a row that quietly says nothing.
  const PHASE_LABELS: Record<keyof BenchOptions, () => string> = {
    disk: () => $LL.benchmarkDisk(),
    network: () => $LL.benchmarkNetwork(),
    reduced_network: () => $LL.benchmarkReducedNetwork(),
    cpu: () => $LL.benchmarkCpu(),
    geekbench_version: () => $LL.benchmarkGeekbenchVersion(),
    ip_info: () => $LL.benchmarkIpInfo(),
    prefer_precompiled_binaries: () => $LL.benchmarkPreferBinaries(),
    work_dir: () => $LL.benchmarkWorkDir(),
  }

  /// The phases, not the settings: a count of iperf locations and a Geekbench
  /// version say nothing about what a row measured.
  function phasesText(run: BenchRun): string {
    return (['disk', 'network', 'cpu', 'ip_info'] as const)
      .filter((name) => run.options?.[name] === true)
      .map((name) => PHASE_LABELS[name]())
      .join(' · ')
  }

  /// yabs' own document, drawn as it is: pretty-printed when it parses, and as
  /// the text it is when it does not. yabs assembles it with `+=` on a shell
  /// string, so a collected value containing a quote produces a document no
  /// parser accepts — and what it measured is still in there.
  const resultText = $derived.by(() => {
    const raw = detail?.result_json
    if (!raw) return { text: '', parsed: false }
    try {
      return { text: JSON.stringify(JSON.parse(raw), null, 2), parsed: true }
    } catch {
      return { text: raw, parsed: false }
    }
  })
</script>

<AppToolbar subtitle={$LL.benchmarkSubtitle()}>
  {#snippet actions()}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void refresh()} disabled={loading} />
  {/snippet}
</AppToolbar>

<main class="pane-form space-y-[13px] pb-[21px] pt-[5px]">
  {#if error}<Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card>{/if}
  {#if notice}<Card><p class="text-[13px] text-(--text-secondary)">{notice}</p></Card>{/if}

  {#if loading && !view}
    <Card class="grid place-items-center" padding="21px"><Spinner class="w-5 h-5" /></Card>
  {:else if view}
    {#if !supported}<Card><p class="text-[13px] text-(--text-secondary)">{$LL.benchmarkUnsupported()}</p></Card>{/if}

    {@const totalRuns = finished.length + (running ? 1 : 0)}
    <section class="grid grid-cols-[repeat(auto-fill,minmax(160px,1fr))] gap-[9px]" aria-label={$LL.history()}>
      {#each [
        { label: $LL.benchmarkStatusRunning(), value: running ? 1 : 0, icon: 'speed', tone: 'var(--color-accent)' },
        { label: $LL.benchmarkStatusCompleted(), value: finished.filter((run) => run.status === 'completed').length, icon: 'check', tone: 'var(--color-success)' },
        { label: $LL.benchmarkStatusFailed(), value: finished.filter((run) => run.status === 'failed').length, icon: 'error', tone: 'var(--color-danger)' },
        { label: $LL.benchmarkStatusCancelled(), value: finished.filter((run) => run.status === 'cancelled').length, icon: 'stop', tone: 'var(--color-warning)' },
      ] as stat (stat.label)}
        {@const share = totalRuns === 0 ? 0 : Math.round(stat.value / totalRuns * 100)}
        <Card variant="raised" padding="13px 15px">
          <div class="flex items-center gap-[9px]">
            <span class="flex h-7 w-7 items-center justify-center rounded-[7px] bg-(--surface-control)" style:color={stat.tone}><Icon name={stat.icon} size={17} /></span>
            <span class="text-[13px] text-(--text-secondary)">{stat.label}</span>
            <Icon name="chevron_right" size={15} class="ml-auto text-(--text-tertiary)" />
          </div>
          <p class="lk-num mt-[9px] text-[27px] font-[650] leading-none tracking-[-0.02em]">{stat.value}</p>
          <p class="mt-[7px] text-[12px] text-(--text-tertiary)">{$LL.benchmarkRunShare({ percent: share })}</p>
          <div class="mt-[7px] h-[3px] rounded-full bg-(--surface-control)"><div class="h-full rounded-full" style:background={stat.tone} style:width="{share}%"></div></div>
        </Card>
      {/each}
    </section>

    {#if running && live}
      <!-- The run that is going, above the form it came from. A second run
           cannot be started while this one is — the history's own index is what
           enforces that — so the form is not on screen to be tried. -->
      <Card>
        <div class="flex flex-wrap items-center gap-[9px]">
          <Badge tone="success" dot>{$LL.benchmarkStatusRunning()}</Badge>
          {#if liveRun}
            <span class="text-[13px]">{$LL.benchmarkProgress()}: <span class="lk-num">{elapsedText(liveRun.started_at)}</span></span>
            <span class="lk-num text-[12px] text-(--text-tertiary)">{fmtTime(liveRun.started_at)}</span>
          {/if}
          <span class="flex-1"></span>
          <Button variant="secondary" icon="stop" disabled={busy} onclick={() => (confirmingStop = true)}>{$LL.benchmarkCancel()}</Button>
        </div>

        {#if !live.answered}
          <p class="mt-[9px] flex items-center gap-[5px] text-[12px] text-(--text-secondary)">
            <Icon name="warning" size={15} />
            {$LL.benchmarkNoAnswer()}
          </p>
        {/if}

        <div class="mt-[13px]">
          <p class="mb-[5px] text-[12px] font-medium text-(--text-secondary)">{$LL.benchmarkLog()}</p>
          {#if live.log}
            <pre class="max-h-96 overflow-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] lk-mono text-[13px] break-all whitespace-pre-wrap">{live.log}</pre>
          {:else}
            <p class="text-[13px] text-(--text-secondary)">{$LL.benchmarkLogEmpty()}</p>
          {/if}
          {#if live.truncated}<p class="mt-[5px] text-[12px] text-(--text-tertiary)">{$LL.benchmarkLogTruncated()}</p>{/if}
        </div>

        {#if live.processes}
          <div class="mt-[13px]">
            <p class="mb-[5px] text-[12px] font-medium text-(--text-secondary)">{$LL.benchmarkProcesses()}</p>
            <pre class="max-h-48 overflow-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] lk-mono text-[13px] break-all whitespace-pre-wrap">{live.processes}</pre>
          </div>
        {/if}
      </Card>
    {:else if supported}
      <!-- Every phase is a choice, and the three defaults that differ from
           yabs' own say so where the choice is made rather than in a document
           nobody reads before pressing Run. -->
      <Card>
        <p class="mb-[13px] text-[15px] font-semibold">{$LL.benchmarkRun()}</p>

        <div class="grid gap-[9px]">
          <Checkbox bind:checked={options.disk}>
            <span>{$LL.benchmarkDisk()}<span class="block text-[12px] text-(--text-secondary)">{$LL.benchmarkDiskHint()}</span></span>
          </Checkbox>

          <Checkbox bind:checked={options.network}>
            <span>{$LL.benchmarkNetwork()}<span class="block text-[12px] text-(--text-secondary)">{$LL.benchmarkNetworkHint()}</span></span>
          </Checkbox>

          {#if options.network}
            <div class="ml-[21px]">
              <Checkbox bind:checked={options.reduced_network}>
                <span>{$LL.benchmarkReducedNetwork()}<span class="block text-[12px] text-(--text-secondary)">{$LL.benchmarkReducedNetworkHint()}</span></span>
              </Checkbox>
            </div>
          {/if}

          <Checkbox bind:checked={options.cpu}>
            <span>{$LL.benchmarkCpu()}<span class="block text-[12px] text-(--color-warning)">{$LL.benchmarkCpuHint()}</span></span>
          </Checkbox>

          {#if options.cpu}
            <div class="ml-[21px]">
              <Select class="w-[170px]" label={$LL.benchmarkGeekbenchVersion()} bind:value={options.geekbench_version} options={GEEKBENCH_VERSIONS.map((value) => ({ value, label: value }))} />
            </div>
          {/if}

          <Checkbox bind:checked={options.ip_info}>
            <span>{$LL.benchmarkIpInfo()}<span class="block text-[12px] text-(--text-secondary)">{$LL.benchmarkIpInfoHint()}</span></span>
          </Checkbox>

          <Checkbox bind:checked={options.prefer_precompiled_binaries}>
            <span>{$LL.benchmarkPreferBinaries()}<span class="block text-[12px] text-(--text-secondary)">{$LL.benchmarkPreferBinariesHint()}</span></span>
          </Checkbox>

          <Input bind:value={options.work_dir} label={$LL.benchmarkWorkDir()} placeholder="/root" hint={$LL.benchmarkWorkDirHint()} mono />
        </div>

        <!-- Both costs are shown before a run starts. -->
        {#if estimate}
          <div class="mt-[13px] space-y-[5px]">
            {#if estimate.system_info_only}
              <p class="text-[12px] text-(--text-secondary)">{$LL.benchmarkEstimateSystemInfo()}</p>
            {:else}
              <p class="text-[12px] text-(--text-secondary)">{$LL.benchmarkEstimate({ minutes: estimate.minutes, traffic: fmtBytes(estimate.traffic_bytes) })}</p>
              {#if estimate.required_free_bytes !== null}<p class="text-[12px] text-(--text-secondary)">{$LL.benchmarkEstimateDisk({ free: fmtBytes(estimate.required_free_bytes) })}</p>{/if}
            {/if}
          </div>
        {:else if estimateFailed}
          <p class="mt-[13px] text-[12px] text-(--text-secondary)">{$LL.benchmarkEstimateFailed()}</p>
        {/if}

        <div class="mt-[13px] flex justify-end">
          <Button variant="primary" disabled={busy} onclick={() => void start()}>
            {#if busy}<Spinner size="sm" />{/if}
            {$LL.benchmarkRun()}
          </Button>
        </div>
      </Card>
    {/if}

    <div class="flex items-center gap-[7px] pt-[5px]">
      <p class="text-[15px] font-semibold">{$LL.history()}</p>
      {#if loading}<Spinner size="sm" />{/if}
      <span class="flex-1"></span>
      <span class="lk-num text-[12px] text-(--text-tertiary)">{finished.length}</span>
    </div>

    {#if finished.length === 0}
      <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
        <Icon name="speed" size={48} weight={300} />
        <span class="text-[13px]">{$LL.benchmarkEmptyState()}</span>
      </div>
    {:else}
      <ul class="space-y-[7px]">
        {#each finished as run (run.id)}
          <li>
            <Card padding="11px 13px">
              <div class="flex min-w-0 items-center gap-[13px]">
                <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised) text-(--color-accent-text)"><Icon name="speed" size={18} /></span>
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-[7px]">
                    <Badge tone={statusTone(run.status)} dot>{statusText(run.status)}</Badge>
                    <span class="lk-num text-[13px]">{fmtTime(run.started_at, { withDate: true })}</span>
                    {#if run.exit_code !== null}<span class="lk-mono text-[12px] text-(--text-tertiary)">{$LL.benchmarkExitCode({ code: run.exit_code })}</span>{/if}
                  </div>
                  {#if phasesText(run)}<p class="text-[12px] text-(--text-tertiary)">{phasesText(run)}</p>{/if}
                  {#if run.error}<p class="text-[12px] text-(--color-danger)">{benchRunErrorText(run.error)}</p>{/if}
                  {#if !run.has_result}<p class="text-[12px] text-(--text-tertiary)">{$LL.benchmarkNoResultYet()}</p>{/if}
                </div>
                {#if run.has_result}<Button size="sm" variant="tinted" icon="article" onclick={() => void open(run)}>{$LL.benchmarkResult()}</Button>{/if}
                <IconButton icon="delete" label={$LL.benchmarkRemove()} disabled={busy} onclick={() => (confirmingRemove = run)} />
              </div>
            </Card>
          </li>
        {/each}
      </ul>
    {/if}
  {/if}
</main>

<!-- Stopping is the one thing here that cannot be undone, and the run is
     fifteen minutes of a machine's time. -->
{#if confirmingStop}
  <Dialog open title={$LL.benchmarkCancelTitle()} message={$LL.benchmarkCancelConfirm()} onclose={() => (confirmingStop = false)}>
    {#snippet icon()}<AppIcon glyph="speed" tone="amber" size={52} />{/snippet}
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} icon="stop" onclick={() => void stop()}>{$LL.benchmarkCancel()}</Button>
      <Button variant="secondary" block onclick={() => (confirmingStop = false)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if confirmingRemove !== undefined}
  <Dialog open title={$LL.benchmarkRemoveTitle()} message={$LL.benchmarkRemoveConfirm()} onclose={() => (confirmingRemove = undefined)}>
    {#snippet icon()}<AppIcon glyph="delete" tone="amber" size={52} />{/snippet}
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} onclick={() => { const run = confirmingRemove; if (run) void remove(run) }}>{$LL.benchmarkRemove()}</Button>
      <Button variant="secondary" block onclick={() => (confirmingRemove = undefined)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if detail !== null || detailLoading}
  <Dialog open wide title={$LL.benchmarkResult()} onclose={closeDetail}>
    {#snippet actions()}
      <Button variant="secondary" onclick={closeDetail}>{$LL.close()}</Button>
    {/snippet}
    {#if detailLoading}
      <Spinner class="w-5 h-5" />
    {:else if detail}
      {#if detail.result_json}
        {#if !resultText.parsed}<p class="mb-[7px] text-[12px] text-(--text-secondary)">{$LL.benchmarkResultUnparsable()}</p>{/if}
        <pre class="max-h-96 overflow-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] lk-mono text-[13px] break-all whitespace-pre-wrap">{resultText.text}</pre>
      {:else}
        <p class="text-[13px] text-(--text-secondary)">{$LL.benchmarkResultEmpty()}</p>
      {/if}
      {#if detail.log}
        <div class="mt-[13px]">
          <p class="mb-[5px] text-[12px] font-medium text-(--text-secondary)">{$LL.benchmarkLog()}</p>
          <pre class="max-h-64 overflow-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] lk-mono text-[13px] break-all whitespace-pre-wrap">{detail.log}</pre>
        </div>
      {/if}
    {/if}
  </Dialog>
{/if}
