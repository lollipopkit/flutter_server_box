<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Select, Spinner } from '@serverbox/webui'
  import { CircleAlert, RefreshCw, Square, Trash } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { api } from '../lib/api'
  import { benchRefusalText, benchRunErrorText } from '../lib/benchRefusal'
  import { fmtBytes, fmtTime } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type { BenchDetail, BenchEstimate, BenchOptions, BenchRun, BenchView } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

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

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
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
  const editable = $derived(view?.editable === true)
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

<PageHeader
  title={$LL.benchmark()}
  subtitle={$LL.benchmarkSubtitle()}
  containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet tabs()}
    <FeatureTabs active="benchmark" />
  {/snippet}

  {#snippet actions()}
    <IconButton label={$LL.refresh()} onclick={() => void refresh()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
  {#if error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}

  {#if notice}
    <Card>
      <p class="text-sm text-muted-fg">{notice}</p>
    </Card>
  {/if}

  {#if loading && !view}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if view}
    {#if !supported}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.benchmarkUnsupported()}</p>
      </Card>
    {:else if !editable}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.benchmarkReadOnly()}</p>
      </Card>
    {/if}

    {#if running && live}
      <!-- The run that is going, above the form it came from. A second run
           cannot be started while this one is — the history's own index is what
           enforces that — so the form is not on screen to be tried. -->
      <Card class="space-y-3">
        <div class="flex flex-wrap items-center gap-3">
          <Badge tone="neutral">{$LL.benchmarkStatusRunning()}</Badge>
          {#if liveRun}
            <span class="text-sm text-fg">
              {$LL.benchmarkProgress()}: {elapsedText(liveRun.started_at)}
            </span>
            <span class="text-xs text-muted-fg">{fmtTime(liveRun.started_at)}</span>
          {/if}
          <span class="flex-1"></span>
          {#if editable}
            <Button variant="secondary" disabled={busy} onclick={() => (confirmingStop = true)}>
              <Square class="w-4 h-4" />
              {$LL.benchmarkCancel()}
            </Button>
          {/if}
        </div>

        {#if !live.answered}
          <p class="flex items-center gap-1.5 text-xs text-muted-fg">
            <CircleAlert class="w-3.5 h-3.5 shrink-0" />
            {$LL.benchmarkNoAnswer()}
          </p>
        {/if}

        <div class="space-y-1">
          <p class="text-xs font-medium text-muted-fg">{$LL.benchmarkLog()}</p>
          {#if live.log}
            <pre
              class="max-h-96 overflow-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-fg">{live.log}</pre>
          {:else}
            <p class="text-sm text-muted-fg">{$LL.benchmarkLogEmpty()}</p>
          {/if}
          {#if live.truncated}
            <p class="text-xs text-muted-fg">{$LL.benchmarkLogTruncated()}</p>
          {/if}
        </div>

        {#if live.processes}
          <div class="space-y-1">
            <p class="text-xs font-medium text-muted-fg">{$LL.benchmarkProcesses()}</p>
            <pre
              class="max-h-48 overflow-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-muted-fg">{live.processes}</pre>
          </div>
        {/if}
      </Card>
    {:else if supported}
      <!-- Every phase is a choice, and the three defaults that differ from
           yabs' own say so where the choice is made rather than in a document
           nobody reads before pressing Run. -->
      <Card class="space-y-4">
        <p class="text-sm font-medium text-fg-strong">{$LL.benchmarkRun()}</p>

        <div class="space-y-3">
          <label class="flex items-start gap-2 text-sm text-fg">
            <input type="checkbox" class="mt-0.5" bind:checked={options.disk} />
            <span>
              {$LL.benchmarkDisk()}
              <span class="block text-xs text-muted-fg">{$LL.benchmarkDiskHint()}</span>
            </span>
          </label>

          <label class="flex items-start gap-2 text-sm text-fg">
            <input type="checkbox" class="mt-0.5" bind:checked={options.network} />
            <span>
              {$LL.benchmarkNetwork()}
              <span class="block text-xs text-muted-fg">{$LL.benchmarkNetworkHint()}</span>
            </span>
          </label>

          {#if options.network}
            <label class="ml-6 flex items-start gap-2 text-sm text-fg">
              <input type="checkbox" class="mt-0.5" bind:checked={options.reduced_network} />
              <span>
                {$LL.benchmarkReducedNetwork()}
                <span class="block text-xs text-muted-fg">{$LL.benchmarkReducedNetworkHint()}</span
                >
              </span>
            </label>
          {/if}

          <label class="flex items-start gap-2 text-sm text-fg">
            <input type="checkbox" class="mt-0.5" bind:checked={options.cpu} />
            <span>
              {$LL.benchmarkCpu()}
              <span class="block text-xs text-danger">{$LL.benchmarkCpuHint()}</span>
            </span>
          </label>

          {#if options.cpu}
            <div class="ml-6 space-y-1">
              <p class="text-xs text-muted-fg">{$LL.benchmarkGeekbenchVersion()}</p>
              <Select class="w-32" bind:value={options.geekbench_version}>
                {#each GEEKBENCH_VERSIONS as version (version)}
                  <option value={version}>{version}</option>
                {/each}
              </Select>
            </div>
          {/if}

          <label class="flex items-start gap-2 text-sm text-fg">
            <input type="checkbox" class="mt-0.5" bind:checked={options.ip_info} />
            <span>
              {$LL.benchmarkIpInfo()}
              <span class="block text-xs text-muted-fg">{$LL.benchmarkIpInfoHint()}</span>
            </span>
          </label>

          <label class="flex items-start gap-2 text-sm text-fg">
            <input
              type="checkbox"
              class="mt-0.5"
              bind:checked={options.prefer_precompiled_binaries}
            />
            <span>
              {$LL.benchmarkPreferBinaries()}
              <span class="block text-xs text-muted-fg">{$LL.benchmarkPreferBinariesHint()}</span>
            </span>
          </label>

          <div class="space-y-1">
            <p class="text-xs text-muted-fg">{$LL.benchmarkWorkDir()}</p>
            <Input bind:value={options.work_dir} placeholder="/root" />
            <p class="text-xs text-muted-fg">{$LL.benchmarkWorkDirHint()}</p>
          </div>
        </div>

        <!-- Both costs are invisible at the moment the decision is made: a disk
             test that takes three minutes is a surprise on a page with a
             spinner, and an iperf run is tens of gigabytes on a plan paid for
             by the gigabyte. -->
        {#if estimate}
          <div class="space-y-0.5">
            {#if estimate.system_info_only}
              <p class="text-xs text-muted-fg">{$LL.benchmarkEstimateSystemInfo()}</p>
            {:else}
              <p class="text-xs text-muted-fg">
                {$LL.benchmarkEstimate({
                  minutes: estimate.minutes,
                  traffic: fmtBytes(estimate.traffic_bytes),
                })}
              </p>
              {#if estimate.required_free_bytes !== null}
                <p class="text-xs text-muted-fg">
                  {$LL.benchmarkEstimateDisk({ free: fmtBytes(estimate.required_free_bytes) })}
                </p>
              {/if}
            {/if}
          </div>
        {:else if estimateFailed}
          <p class="text-xs text-muted-fg">{$LL.benchmarkEstimateFailed()}</p>
        {/if}

        <div class="flex justify-end">
          <Button disabled={busy || !editable} onclick={() => void start()}>
            {#if busy}<Spinner size="sm" />{/if}
            {$LL.benchmarkRun()}
          </Button>
        </div>
      </Card>
    {/if}

    <div class="flex items-center gap-2 pt-2">
      <p class="text-sm font-medium text-fg-strong">{$LL.history()}</p>
      {#if loading}<Spinner size="sm" />{/if}
    </div>

    {#if finished.length === 0}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.benchmarkEmpty()}</p>
      </Card>
    {:else}
      <Card class="divide-y divide-line p-0">
        {#each finished as run (run.id)}
          <div class="space-y-1 px-4 py-3">
            <div class="flex flex-wrap items-center gap-3">
              <Badge tone={statusTone(run.status)}>{statusText(run.status)}</Badge>
              <span class="text-sm text-fg-strong">
                {fmtTime(run.started_at, { withDate: true })}
              </span>
              {#if run.exit_code !== null}
                <span class="font-mono text-xs text-muted-fg">
                  {$LL.benchmarkExitCode({ code: run.exit_code })}
                </span>
              {/if}
              <span class="flex-1"></span>
              {#if run.has_result}
                <Button variant="secondary" onclick={() => void open(run)}>
                  {$LL.benchmarkResult()}
                </Button>
              {/if}
              {#if editable}
                <IconButton
                  label={$LL.benchmarkRemove()}
                  disabled={busy}
                  onclick={() => (confirmingRemove = run)}
                >
                  <Trash class="w-4 h-4" />
                </IconButton>
              {/if}
            </div>
            {#if phasesText(run)}
              <p class="text-xs text-muted-fg">{phasesText(run)}</p>
            {/if}
            {#if run.error}
              <p class="text-xs text-danger">{benchRunErrorText(run.error)}</p>
            {/if}
            {#if !run.has_result}
              <p class="text-xs text-faint-fg">{$LL.benchmarkNoResultYet()}</p>
            {/if}
          </div>
        {/each}
      </Card>
    {/if}
  {/if}
</main>

<!-- Stopping is the one thing here that cannot be undone, and the run is
     fifteen minutes of a machine's time. -->
{#if confirmingStop}
  <Modal open title={$LL.benchmarkCancel()} onclose={() => (confirmingStop = false)}>
    <div class="space-y-4">
      <p class="text-sm text-fg">{$LL.benchmarkCancelConfirm()}</p>
      <div class="flex flex-wrap justify-end gap-2">
        <Button variant="secondary" onclick={() => (confirmingStop = false)}>
          {$LL.cancel()}
        </Button>
        <Button disabled={busy} onclick={() => void stop()}>
          <Square class="w-4 h-4" />
          {$LL.benchmarkCancel()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if confirmingRemove !== undefined}
  <Modal open title={$LL.benchmarkRemove()} onclose={() => (confirmingRemove = undefined)}>
    <div class="space-y-4">
      <p class="text-sm text-fg">{$LL.benchmarkRemoveConfirm()}</p>
      <div class="flex flex-wrap justify-end gap-2">
        <Button variant="secondary" onclick={() => (confirmingRemove = undefined)}>
          {$LL.cancel()}
        </Button>
        <Button
          disabled={busy}
          onclick={() => {
            const run = confirmingRemove
            if (run) void remove(run)
          }}
        >
          {$LL.benchmarkRemove()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if detail !== null || detailLoading}
  <Modal open title={$LL.benchmarkResult()} onclose={closeDetail}>
    <div class="space-y-3">
      {#if detailLoading}
        <Spinner class="w-5 h-5" />
      {:else if detail}
        {#if detail.result_json}
          {#if !resultText.parsed}
            <p class="text-xs text-muted-fg">{$LL.benchmarkResultUnparsable()}</p>
          {/if}
          <pre
            class="max-h-96 overflow-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-fg">{resultText.text}</pre>
        {:else}
          <p class="text-sm text-muted-fg">{$LL.benchmarkResultEmpty()}</p>
        {/if}
        {#if detail.log}
          <div class="space-y-1">
            <p class="text-xs font-medium text-muted-fg">{$LL.benchmarkLog()}</p>
            <pre
              class="max-h-64 overflow-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-muted-fg">{detail.log}</pre>
          </div>
        {/if}
        <div class="flex justify-end">
          <Button variant="secondary" onclick={closeDetail}>{$LL.close()}</Button>
        </div>
      {/if}
    </div>
  </Modal>
{/if}
