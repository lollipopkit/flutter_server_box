<script lang="ts">
  import { AppToolbar, useLifecycle, useMenus, useWindow, WindowFooter } from '../../sys'
  import {
    Button,
    Card,
    DataTable,
    Dialog,
    Icon,
    Input,
    SearchField,
    Spinner,
    StatusBar,
    ToolbarGroup,
    type Column,
    type TableSort,
  } from '../../lk'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type { ProcessSignal, ProcessSortMode, ProcessView } from '../../../types'

  /// How often the table is read again while it is in sight and not paused.
  const REFRESH_MS = 5000

  const win = useWindow()
  let view = $state<ProcessView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  /// Set after a signal lands, cleared by the next one. A success is worth
  /// saying because the row it reports is usually gone from the next reading.
  let notice = $state('')
  /// The filter and the kernel-thread toggle are the window's own: neither is
  /// a question for the machine.
  let query = $state('')
  let search = $state<HTMLInputElement | null>(null)
  let showKernel = $state(false)
  let paused = $state(false)
  /// The order the window is asking for. Adopted from each answer, so a mode
  /// this machine cannot answer (it printed no `read` column) leaves the
  /// header and the ordering agreeing with each other rather than with the
  /// click.
  let sort = $state<ProcessSortMode | undefined>(asked())
  let ascending = $state<boolean | undefined>(undefined)

  /// The selected row's PID.
  let selected = $state<number | null>(null)
  /// The status bar asks before a signal is sent.
  let asking = $state(false)
  /// The signal that was refused for want of a different account: the
  /// password dialog is open for it.
  let pending = $state<ProcessSignal | undefined>(undefined)
  let password = $state('')
  let stopError = $state('')

  const life = useLifecycle()

  /// The order another app opened this window for (Status's CPU tile).
  function asked(): ProcessSortMode | undefined {
    const want = (win.appState as { sort?: unknown } | null)?.sort
    return want === 'cpu' || want === 'mem' ? want : undefined
  }

  /// Opened again for an order: that order, the agent's own direction.
  $effect(() => {
    const want = asked()
    if (want && want !== untrack(() => sort)) untrack(() => void load(want, undefined))
  })

  /// A reply that arrives after the desk has switched servers belongs to
  /// neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(requestedSort?: ProcessSortMode, requestedAscending?: boolean, serverId = servers.currentId) {
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

  /// Read again while the window is in sight, not paused, and no stop is
  /// being asked about (the row would move under the question).
  $effect(() => {
    if (paused || life.state === 'background' || life.state === 'suspended' || asking || pending !== undefined) return
    const t = setInterval(() => {
      if (!loading) void refresh()
    }, REFRESH_MS)
    return () => clearInterval(t)
  })

  /// The order on screen, which is what a refresh should ask for again — not
  /// the order last clicked, which a fallback may have changed.
  function refresh() {
    return load(view?.sort ?? undefined, view?.ascending ?? undefined)
  }

  /// A click on a column asks the machine for that order; the direction is
  /// the header's (the agent's own default for a new column, turned around
  /// on the same one).
  function order(next: TableSort) {
    const mode = next.key as ProcessSortMode
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
        // The agent already tried root, as `sudo -n` without a password: that
        // asking for one is the cue to ask the user, not a refusal of one.
        if (!asRoot && platform !== 'windows') {
          pending = sig
          return
        }
        stopError = $LL.powerRejected()
        return
      }
      switch (result.outcome) {
        case 'succeeded':
          notice = $LL.processKillSucceeded({ signal: signalName(sig), name: row.name })
          closeStop()
          selected = null
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

  function closeStop() {
    asking = false
    pending = undefined
    password = ''
    stopError = ''
  }

  const rows = $derived(view?.procs ?? [])
  const platform = $derived(capabilitiesStore.byServer[servers.currentId]?.platform)
  /// A signal on Windows is not a signal, so it is not named as one.
  const named = $derived(platform !== 'windows')
  const signals = $derived(view?.signals ?? [])
  const kernelThreads = $derived(rows.filter((row) => row.is_kernel_thread).length)
  const columns = $derived(view?.columns ?? null)
  /// The row a stop is about: the selection, while it is still in the table.
  const target = $derived(selected === null ? undefined : rows.find((r) => r.pid === selected))

  /// The machine's table, filtered by what the window is asking to see. Never
  /// reordered here: which order a table can answer is the agent's answer.
  const visible = $derived.by(() => {
    const needle = query.trim().toLowerCase()
    return rows.filter((row) => {
      if (!showKernel && row.is_kernel_thread) return false
      if (!needle) return true
      return (
        row.name.toLowerCase().includes(needle) ||
        row.command.toLowerCase().includes(needle) ||
        (row.user ?? '').toLowerCase().includes(needle) ||
        String(row.pid).includes(needle)
      )
    })
  })

  type Row = {
    pid: number
    name: string
    command: string
    user: string
    cpu: string
    mem: string
    rss: string
    read: string
    write: string
    threads: string
    hot: boolean
    big: boolean
  }

  const table = $derived(
    visible.map(
      (row): Row => ({
        pid: row.pid,
        name: row.name,
        command: row.command,
        user: row.user ?? '—',
        cpu: row.cpu === null ? '—' : fmtPercent(row.cpu),
        mem: row.mem === null ? '—' : fmtPercent(row.mem),
        rss: row.rss_kb === null ? '—' : fmtBytes(row.rss_kb * 1024),
        // A first reading has no speed to difference: the machine's own
        // counters are what there is to show.
        read: columns?.read_speed || columns?.write_speed ? speedText(row.read_speed) : bytesText(row.read_bytes),
        write: columns?.read_speed || columns?.write_speed ? speedText(row.write_speed) : bytesText(row.write_bytes),
        threads: row.threads === null ? '—' : String(row.threads),
        hot: (row.cpu ?? 0) >= 1,
        big: (row.mem ?? 0) >= 5,
      }),
    ),
  )

  /// The columns the machine printed and no others; a column sorts when the
  /// machine can answer that order.
  const tableColumns = $derived.by((): Column<Row>[] => {
    const can = (mode: ProcessSortMode) => view?.sorts?.includes(mode) ?? false
    const out: Column<Row>[] = [
      { key: 'name', label: $LL.processSortName(), width: 'minmax(200px,1fr)', strong: true, subKey: 'command', sortable: can('name') },
      { key: 'pid', label: $LL.processSortPid(), width: '64px', align: 'end', dim: true, sortable: can('pid'), defaultDir: -1 },
    ]
    if (columns?.user) out.push({ key: 'user', label: $LL.processSortUser(), width: '92px', dim: true, sortable: can('user') })
    if (columns?.cpu) {
      out.push({ key: 'cpu', label: $LL.processCpu(), width: '58px', align: 'end', dim: true, dimZero: true, sortable: can('cpu'), defaultDir: -1, emphasize: (r) => r.hot })
    }
    if (columns?.mem) {
      out.push({ key: 'mem', label: $LL.processMemory(), width: '64px', align: 'end', dim: true, dimZero: true, sortable: can('mem'), defaultDir: -1, emphasize: (r) => r.big })
    }
    if (columns?.rss) out.push({ key: 'rss', label: $LL.processRss(), width: '74px', align: 'end', dim: true, sortable: can('rss'), defaultDir: -1 })
    if (columns?.read_speed || columns?.write_speed || columns?.read || columns?.write) {
      out.push(
        { key: 'read', label: $LL.processSortRead(), width: '76px', align: 'end', dim: true, dimZero: true, sortable: can('read'), defaultDir: -1 },
        { key: 'write', label: $LL.processSortWrite(), width: '76px', align: 'end', dim: true, dimZero: true, sortable: can('write'), defaultDir: -1 },
      )
    }
    out.push({ key: 'threads', label: $LL.processColumnThreads(), width: '48px', align: 'end', dim: true, sortable: false })
    return out
  })

  const minWidth = $derived(tableColumns.reduce((sum, c) => sum + (parseInt(c.width ?? '0', 10) || 200), 0) + 40)

  function signalLabel(sig: ProcessSignal): string {
    const text = sig === 'kill' ? $LL.processForceKill() : $LL.processStop()
    return named ? `${text} (${signalName(sig)})` : text
  }

  function signalName(sig: ProcessSignal): string {
    return sig === 'kill' ? 'SIGKILL' : 'SIGTERM'
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

  function speedText(value: number | null): string {
    return value === null ? '—' : fmtBytesPerSec(value)
  }

  function bytesText(value: number | null): string {
    return value === null ? '—' : fmtBytes(value)
  }

  const count = $derived(rows.filter((r) => showKernel || !r.is_kernel_thread).length)
  const footText = $derived.by(() => {
    const parts = [query.trim() ? $LL.processMatching({ count: visible.length }) : $LL.processCount({ count })]
    if (view?.load) {
      parts.push($LL.processLoad({ one: view.load.one.toFixed(2), five: view.load.five.toFixed(2), fifteen: view.load.fifteen.toFixed(2) }))
    }
    parts.push(paused ? $LL.deskPaused() : $LL.deskEverySeconds({ n: REFRESH_MS / 1000 }))
    return parts.join(' · ')
  })

  useMenus(() => [
    {
      label: $LL.deskMenuEdit(),
      items: [{ label: $LL.deskFind(), icon: 'search', shortcut: '⌘F', action: () => search?.focus() }],
    },
    {
      label: $LL.deskMenuView(),
      items: [
        ...(kernelThreads > 0 ? [{ label: $LL.processShowKernelThreads(), checked: showKernel, action: () => (showKernel = !showKernel) }] : []),
        { label: paused ? $LL.deskResumeRefresh() : $LL.deskPauseRefresh(), icon: paused ? 'play_arrow' : 'pause', action: () => (paused = !paused) },
        { label: $LL.refresh(), icon: 'refresh', shortcut: '⌘R', action: () => void refresh() },
      ],
    },
  ])
</script>

<AppToolbar subtitle={view?.available ? $LL.processCount({ count }) : undefined} flush={!!view?.available}>
  {#snippet actions()}
    <SearchField bind:value={query} bind:input={search} placeholder={$LL.processSearchHint()} width={220} class="min-w-[90px]" />
    <ToolbarGroup
      items={[
        ...(kernelThreads > 0
          ? [
              {
                label: $LL.processShowKernelThreads(),
                icon: 'account_tree',
                text: $LL.processKernelThreadsShort(),
                active: showKernel,
                onclick: () => (showKernel = !showKernel),
              },
            ]
          : []),
        {
          label: paused ? $LL.deskResumeRefresh() : $LL.deskPauseRefresh(),
          icon: paused ? 'play_arrow' : 'pause',
          onclick: () => (paused = !paused),
        },
      ]}
    />
  {/snippet}
</AppToolbar>

{#if error}
  <div class="px-[17px] pb-[9px]"><Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card></div>
{/if}

{#if loading && !view}
  <div class="grid flex-1 place-items-center"><Spinner /></div>
{:else if view && !view.available}
  <div class="px-[17px] pb-[17px]">
    <Card>
      <p class="text-[13px] text-(--text-secondary)">{reasonText(view)}</p>
      {#if view.reason}
        <pre class="lk-mono mt-[9px] whitespace-pre-wrap break-all text-[12px] text-(--text-tertiary)">{view.reason}</pre>
      {/if}
    </Card>
  </div>
{:else if view}
  {#if view.issue}
    <div class="px-[17px] pb-[9px]">
      <Card>
        <p class="text-[13px] text-(--text-secondary)">{$LL.processIssue()}</p>
        <pre class="lk-mono mt-[7px] whitespace-pre-wrap break-all text-[12px] text-(--text-tertiary)">{view.issue.diagnostics}</pre>
      </Card>
    </div>
  {/if}
  <!-- One line per process, the columns the machine printed; the header
       sticks under the title bar, a narrow window scrolls sideways. -->
  <DataTable
    label={$LL.processes()}
    columns={tableColumns}
    rows={table}
    rowKey="pid"
    sort={sort ? { key: sort, dir: ascending ? 1 : -1 } : undefined}
    onsort={order}
    {selected}
    onselect={(key) => {
      selected = key as number | null
      asking = false
    }}
    {minWidth}
    empty={query ? $LL.processNoMatch() : $LL.processEmptyState()}
  />
{/if}

<WindowFooter>
  <StatusBar>
    {#if asking && target}
      <Icon name="warning" size={16} color="var(--color-danger)" />
      <span class="min-w-0 truncate text-(--text-primary)">
        {$LL.processStopAsk({ name: target.name, pid: target.pid })}
        {#if stopError}<span class="text-(--color-danger)"> {stopError}</span>{/if}
      </span>
      <span class="flex-1"></span>
      <Button variant="ghost" size="sm" onclick={closeStop}>{$LL.cancel()}</Button>
      {#each signals as sig (sig)}
        <Button variant="destructive" size="sm" disabled={busy} onclick={() => void signal(sig)}>{signalLabel(sig)}</Button>
      {/each}
    {:else}
      <span class="truncate">{notice || footText}</span>
      <span class="flex-1"></span>
      {#if busy}<Spinner size="sm" />{/if}
      {#if target}
        <span class="truncate font-semibold text-(--text-primary)">{target.name}</span>
        {#if target.killable && signals.length > 0}
          <Button variant="ghost" size="sm" class="!text-(--color-danger)" onclick={() => (asking = true)}>{$LL.processStop()}</Button>
        {/if}
      {/if}
    {/if}
  </StatusBar>
</WindowFooter>

<!-- The signal was refused for want of the account that owns the process:
     the password is the second attempt's, sent as its own field so it never
     lands in a command line. -->
{#if pending !== undefined && target}
  <Dialog open wide title={$LL.processStop()} message={$LL.processStopConfirm({ name: target.name, pid: target.pid })} onclose={closeStop}>
    {#snippet actions()}
      <!-- Without a password the retry is the `sudo -n` the agent already
           tried, so there is nothing to send until one is typed. -->
      <Button variant="primary" disabled={busy || !password} onclick={() => void signal(pending!, true)}>{$LL.processRetryAsRoot()}</Button>
      <Button variant="secondary" onclick={closeStop}>{$LL.cancel()}</Button>
    {/snippet}
    <p class="lk-mono break-all text-[12px] text-(--text-tertiary)">{target.command}</p>
    {#if stopError}<p class="mt-[9px] text-[13px] text-(--color-danger)">{stopError}</p>{/if}
    <div class="mt-[13px]">
      <Input id="process-password" label={$LL.powerPassword()} type="password" bind:value={password} />
      <p class="mt-[5px] text-[12px] text-(--text-secondary)">{$LL.powerPasswordHint()}</p>
    </div>
  </Dialog>
{/if}
