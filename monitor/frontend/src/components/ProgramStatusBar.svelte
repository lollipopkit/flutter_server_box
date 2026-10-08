<script lang="ts">
  /// One line above the terminal: the most urgent thing its programs report
  /// about themselves (OSC 7501, OSC 9;4). Nothing while they report nothing
  /// or are only idle.
  import { X } from '@lucide/svelte'
  import { IconButton } from '@serverbox/webui'
  import LL from '../i18n/i18n-svelte'
  import type { ProgramState, ProgramStatusRecord, ProgramStatusRecords } from '../lib/programStatus'

  let { records }: { records: ProgramStatusRecords | null } = $props()

  let headline = $state<{
    state: ProgramState
    record?: ProgramStatusRecord
    app?: string
    progress?: number
    count: number
  } | null>(null)

  $effect(() => {
    const r = records
    if (!r) {
      headline = null
      return
    }
    const update = () => {
      const state = r.state
      if (state === null || state === 'idle') {
        headline = null
        return
      }
      const record = r.latest(state)
      headline = {
        state,
        record,
        app: record ? r.appOf(record) : undefined,
        progress: record ? record.report.progress : r.progress?.percent,
        count: r.records.length,
      }
    }
    update()
    return r.subscribe(update)
  })

  const dot: Record<ProgramState, string> = {
    blocked: 'bg-warning',
    error: 'bg-danger',
    done: 'bg-success',
    working: 'bg-accent',
    idle: 'bg-faint-fg',
  }

  function label(state: ProgramState, record?: ProgramStatusRecord): string {
    switch (state) {
      case 'blocked':
        switch (record?.report.kind) {
          case 'permission':
            return $LL.terminalProgramWaitingPermission()
          case 'question':
            return $LL.terminalProgramWaitingQuestion()
          case 'auth':
            return $LL.terminalProgramWaitingAuth()
          default:
            return $LL.terminalProgramWaiting()
        }
      case 'error':
        return $LL.terminalProgramError()
      case 'done':
        return $LL.terminalProgramDone()
      default:
        return $LL.terminalProgramWorking()
    }
  }

  /// Done and failed records stay until replaced; the user can say they have
  /// seen one.
  function dismiss() {
    const record = headline?.record
    if (!records || !record) return
    records.report({ state: null, id: record.report.id })
  }
</script>

{#if headline}
  {@const { state, record, app, progress, count } = headline}
  <div
    class="flex items-center gap-2 min-w-0 text-sm"
    role="status"
    aria-live="polite"
  >
    <span class="shrink-0 w-2 h-2 rounded-full {dot[state]}"></span>
    <!-- Plain text: what a program says is never markup -->
    <span class="shrink-0 font-medium text-fg-strong">
      {label(state, record)}{#if progress !== undefined}&nbsp;{progress}%{/if}
    </span>
    {#if record?.report.title ?? app}
      <span class="shrink-0 text-muted-fg">{record?.report.title ?? app}</span>
    {/if}
    {#if record?.report.msg}
      <span class="truncate text-muted-fg" title={record.report.msg}>{record.report.msg}</span>
    {/if}
    {#if count > 1}
      <span class="shrink-0 text-faint-fg">+{count - 1}</span>
    {/if}
    {#if record && (state === 'done' || state === 'error')}
      <IconButton label={$LL.terminalProgramDismiss()} onclick={dismiss}>
        <X class="w-3.5 h-3.5" />
      </IconButton>
    {/if}
  </div>
{/if}
