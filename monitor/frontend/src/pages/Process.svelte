<script lang="ts">
  import { Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import { RefreshCw, Search, Square } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { api } from '../lib/api'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type { ProcRow, ProcessSignal, ProcessSortMode, ProcessView } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let view = $state<ProcessView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  /// Set after a signal lands, cleared by the next one. A success is worth
  /// saying because the row it reports is usually gone from the next reading.
  let notice = $state('')
  /// The filter and the kernel-thread toggle are the page's own: neither is a
  /// question for the machine, and both are undone by leaving the page.
  let query = $state('')
  let showKernel = $state(false)
  /// The order the page is asking for. Adopted from each answer, so a mode this
  /// machine cannot answer (it printed no `read` column) leaves the chips and
  /// the ordering agreeing with each other rather than with the click.
  let sort = $state<ProcessSortMode | undefined>(undefined)
  let ascending = $state<boolean | undefined>(undefined)

  /// The process whose stop is being confirmed, and the signal that was
  /// refused for want of a different account.
  let target = $state<ProcRow | undefined>(undefined)
  let pending = $state<ProcessSignal | undefined>(undefined)
  let password = $state('')
  let stopError = $state('')

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(
    requestedSort?: ProcessSortMode,
    requestedAscending?: boolean,
    serverId = servers.currentId,
  ) {
    loading = true
    error = ''
    try {
      const next = await api.getProcess(requestedSort, requestedAscending)
      if (stale(serverId)) return
      view = next
      sort = next.sort ?? undefined
      ascending = next.ascending ?? undefined
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    // Only the machine on screen re-runs this. The order is read untracked
    // because it is adopted from every answer: tracking it would make each
    // reply run another request.
    const serverId = servers.currentId
    untrack(() => void load(sort, ascending, serverId))
  })

  /// The order on screen, which is what a refresh should ask for again — not
  /// the order last clicked, which a fallback may have changed.
  function refresh() {
    return load(view?.sort ?? undefined, view?.ascending ?? undefined)
  }

  /// A tap on a chip asks for that order; a tap on the chip already chosen
  /// turns it around. The direction is left to the agent on a change of column,
  /// since each mode has its own default.
  function order(mode: ProcessSortMode) {
    if (mode === sort) void load(mode, !ascending)
    else void load(mode, undefined)
  }

  async function signal(sig: ProcessSignal, asRoot = false) {
    const row = target
    if (!row) return
    busy = true
    notice = ''
    stopError = ''
    try {
      const result = await api.signalProcess({
        pid: row.pid,
        start_id: row.start_id,
        signal: sig,
        ...(asRoot && password ? { password } : {}),
      })
      if (result.sudo_rejected) {
        stopError = $LL.powerRejected()
        return
      }
      switch (result.outcome) {
        case 'succeeded':
          notice = $LL.processKillSucceeded({ signal: signalName(sig), name: row.name })
          target = undefined
          void refresh()
          return
        case 'target_changed':
          stopError = $LL.processKillTargetChanged()
          void refresh()
          return
        case 'denied':
          // This account does not own the process. There is one way forward and
          // it is a different account, so the dialog asks for what that needs
          // rather than reporting a refusal. Windows has no sudo and no second
          // account to reach for.
          if (platform !== 'windows' && !asRoot) {
            pending = sig
            return
          }
          stopError = $LL.processKillDenied()
          return
        default:
          // What the machine said, verbatim: it is the only thing that
          // distinguishes one failure from another.
          stopError = result.stderr.trim() || $LL.processKillFailed()
      }
    } catch (e) {
      stopError = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
  }

  function openStop(row: ProcRow) {
    target = row
    pending = undefined
    password = ''
    stopError = ''
  }

  const editable = $derived(view?.editable === true)
  const rows = $derived(view?.procs ?? [])
  const platform = $derived(capabilitiesStore.byServer[servers.currentId]?.platform)
  /// A signal on Windows is not a signal, so it is not named as one.
  const named = $derived(platform !== 'windows')
  const signals = $derived(view?.signals ?? [])
  const kernelThreads = $derived(rows.filter((row) => row.is_kernel_thread).length)
  const columns = $derived(view?.columns ?? null)

  /// The machine's table, filtered by what the page is asking to see. Never
  /// reordered here: which order a table can answer is the agent's answer, and
  /// a second one computed here would disagree with the chips.
  const visible = $derived.by(() => {
    const needle = query.trim().toLowerCase()
    return rows.filter((row) => {
      if (!showKernel && row.is_kernel_thread) return false
      if (!needle) return true
      return (
        row.name.toLowerCase().includes(needle) ||
        (row.user ?? '').toLowerCase().includes(needle) ||
        String(row.pid).includes(needle)
      )
    })
  })

  /// How each order is drawn. A `Record` over every mode, so one added to the
  /// agent without a label here is a type error rather than a blank chip.
  const SORTS: Record<ProcessSortMode, () => string> = {
    cpu: () => $LL.processSortCpu(),
    mem: () => $LL.processSortMem(),
    rss: () => $LL.processSortRss(),
    read: () => $LL.processSortRead(),
    write: () => $LL.processSortWrite(),
    pid: () => $LL.processSortPid(),
    user: () => $LL.processSortUser(),
    name: () => $LL.processSortName(),
  }

  function signalLabel(sig: ProcessSignal): string {
    const text = sig === 'kill' ? $LL.processForceKill() : $LL.processStop()
    return named ? `${text} (${signalName(sig)})` : text
  }

  function signalName(sig: ProcessSignal): string {
    return sig === 'kill' ? 'SIGKILL' : 'SIGTERM'
  }

  function reading(): string {
    if (!view) return ''
    const at = new Date(view.sampled_at_millis).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    })
    return $LL.processSampledAt({ time: at, count: rows.length })
  }

  function reasonText(reason: ProcessView): string {
    switch (reason.reason_kind) {
      case 'did_not_finish':
        return $LL.processDidNotFinish()
      case 'too_large':
        return $LL.processTooLarge()
      case 'empty':
        return $LL.processEmpty()
      default:
        // What the machine said, verbatim: it is the only thing that
        // distinguishes one failure from another.
        return reason.reason ?? $LL.processUnreadable()
    }
  }

  function cpuText(row: ProcRow): string {
    return row.cpu === null ? '—' : fmtPercent(row.cpu)
  }

  function memText(row: ProcRow): string {
    return row.mem === null ? '—' : fmtPercent(row.mem)
  }

  function rssText(row: ProcRow): string {
    return row.rss_kb === null ? '—' : fmtBytes(row.rss_kb * 1024)
  }

  function speedText(value: number | null): string {
    return value === null ? '—' : fmtBytesPerSec(value)
  }

  function bytesText(value: number | null): string {
    return value === null ? '—' : fmtBytes(value)
  }

  /// How long the process has been running, at the machine's own count of it.
  /// Two units at most: a table row is not the place for a third.
  function durationText(seconds: number): string {
    const days = Math.floor(seconds / 86_400)
    const hours = Math.floor((seconds % 86_400) / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    if (days > 0) return `${days}d ${hours}h`
    if (hours > 0) return `${hours}h ${minutes}m`
    if (minutes > 0) return `${minutes}m`
    return `${seconds}s`
  }
</script>

<PageHeader title={$LL.processes()} subtitle={reading()} containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full" {onback}>
  {#snippet tabs()}
    <FeatureTabs active="process" />
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
  {:else if view && !view.available}
    <Card class="space-y-2">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
      {#if view.reason}
        <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.reason}</pre>
      {/if}
    </Card>
  {:else if view}
    {#if !editable}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.processReadOnly()}</p>
      </Card>
    {/if}

    <Card class="space-y-3">
      <div class="flex flex-wrap items-center gap-2">
        <div class="relative flex-1 min-w-48">
          <Search class="pointer-events-none absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-faint-fg" />
          <Input class="pl-8" bind:value={query} placeholder={$LL.processSearchHint()} />
        </div>
        {#if kernelThreads > 0}
          <label class="flex items-center gap-2 text-sm text-fg">
            <input type="checkbox" bind:checked={showKernel} />
            {$LL.processKernelThreads({ count: kernelThreads })}
          </label>
        {/if}
      </div>

      <!-- The orders this machine can answer, in the agent's own order. Which
           ones those are depends on the columns it printed, so the list is not
           written here. -->
      <div class="flex flex-wrap items-center gap-1">
        {#each view.sorts as mode (mode)}
          {@const chosen = mode === sort}
          <button
            class="inline-flex items-center gap-1 rounded border px-2 py-1 text-xs transition-colors {chosen
              ? 'border-primary text-fg-strong'
              : 'border-line text-muted-fg hover:text-fg'}"
            aria-current={chosen ? 'true' : undefined}
            onclick={() => order(mode)}
          >
            {SORTS[mode]()}
            {#if chosen}
              <span class="text-faint-fg">{ascending ? '↑' : '↓'}</span>
            {/if}
          </button>
        {/each}
        {#if view.load}
          <span class="ml-auto text-xs text-faint-fg">
            {$LL.processLoad({
              one: view.load.one.toFixed(2),
              five: view.load.five.toFixed(2),
              fifteen: view.load.fifteen.toFixed(2),
            })}
          </span>
        {/if}
      </div>
    </Card>

    {#if view.issue}
      <Card class="space-y-1">
        <p class="text-sm text-muted-fg">{$LL.processIssue()}</p>
        <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.issue.diagnostics}</pre>
      </Card>
    {/if}

    {#if visible.length === 0}
      <Card>
        <p class="text-sm text-muted-fg">
          {query ? $LL.processNoMatch() : $LL.processNone()}
        </p>
      </Card>
    {:else}
      <Card class="divide-y divide-line p-0">
        {#each visible as row (row.pid)}
          <div class="px-4 py-3 space-y-1">
            <div class="flex items-center gap-3">
              <span class="text-sm font-medium text-fg-strong truncate">{row.name}</span>
              {#if row.user}
                <span class="text-xs text-muted-fg shrink-0">{row.user}</span>
              {/if}
              <span class="text-xs font-mono text-faint-fg shrink-0">PID {row.pid}</span>
              <span class="flex-1"></span>
              {#if editable && row.killable && signals.length > 0}
                <IconButton label={$LL.processStop()} disabled={busy} onclick={() => openStop(row)}>
                  <Square class="w-4 h-4" />
                </IconButton>
              {/if}
            </div>
            <p class="text-xs text-muted-fg truncate font-mono" title={row.command}>{row.command}</p>
            <p class="text-xs text-faint-fg">
              {#if columns?.cpu}
                {$LL.processCpu()}: {cpuText(row)}
              {/if}
              {#if columns?.mem}
                · {$LL.processMemory()}: {memText(row)}
              {/if}
              {#if columns?.rss}
                · {$LL.processRss()}: {rssText(row)}
              {/if}
              {#if columns?.read_speed || columns?.write_speed}
                · R {speedText(row.read_speed)} W {speedText(row.write_speed)}
              {:else if columns?.read || columns?.write}
                <!-- The first reading has nothing to difference against, so the
                     machine's own counters are what there is to show. -->
                · R {bytesText(row.read_bytes)} W {bytesText(row.write_bytes)}
              {/if}
              {#if row.threads !== null}
                · {$LL.processThreads({ count: row.threads })}
              {/if}
              {#if row.elapsed_seconds !== null}
                · {durationText(row.elapsed_seconds)}
              {/if}
            </p>
          </div>
        {/each}
      </Card>
    {/if}

    {#if busy}
      <div class="flex items-center gap-2 text-xs text-muted-fg">
        <Spinner size="sm" />
      </div>
    {/if}
  {/if}
</main>

<!-- Stopping a process is the one thing here that cannot be undone, so it is
     asked about — and the answer says which signal, because the difference
     between a graceful stop and a force kill is the whole of what the choice
     means. -->
{#if target !== undefined}
  <Modal open title={$LL.processStop()} onclose={() => (target = undefined)}>
    <div class="space-y-4">
      <div class="space-y-1">
        <p class="text-sm text-fg">
          {$LL.processStopConfirm({ name: target.name, pid: target.pid })}
        </p>
        <p class="text-xs text-muted-fg font-mono break-all">{target.command}</p>
      </div>

      {#if stopError}
        <p class="text-sm text-danger">{stopError}</p>
      {/if}

      {#if pending !== undefined}
        <!-- The signal was refused for want of the account that owns the
             process. The password is the second attempt's, sent as its own
             field so it never lands in a command line. -->
        <div class="space-y-1">
          <label class="text-sm text-muted-fg" for="process-password">{$LL.powerPassword()}</label>
          <Input id="process-password" type="password" bind:value={password} />
          <p class="text-xs text-muted-fg">{$LL.powerPasswordHint()}</p>
        </div>
        <div class="flex justify-end gap-2">
          <Button variant="secondary" onclick={() => (target = undefined)}>{$LL.cancel()}</Button>
          <Button disabled={busy} onclick={() => void signal(pending!, true)}>
            {$LL.processRetryAsRoot()}
          </Button>
        </div>
      {:else}
        <div class="flex flex-wrap justify-end gap-2">
          <Button variant="secondary" onclick={() => (target = undefined)}>{$LL.cancel()}</Button>
          {#each signals as sig (sig)}
            <Button disabled={busy} onclick={() => void signal(sig)}>{signalLabel(sig)}</Button>
          {/each}
        </div>
      {/if}
    </div>
  </Modal>
{/if}
