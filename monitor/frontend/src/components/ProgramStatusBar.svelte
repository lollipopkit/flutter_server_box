<script lang="ts">
  /// One line above the terminal: the most urgent thing its programs report
  /// about themselves (OSC 7501, OSC 9;4). Nothing while they report nothing
  /// or are only idle.
  import { IconButton } from '../desk/lk'
  import { LL } from '../i18n/i18n-svelte'
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
    blocked: 'var(--color-warning)',
    error: 'var(--color-danger)',
    done: 'var(--color-success)',
    working: 'var(--color-accent)',
    idle: 'var(--text-tertiary)',
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
  <div class="flex min-w-0 items-center gap-[7px] px-[13px] py-[5px] text-[12px]" role="status" aria-live="polite">
    <span class="h-[7px] w-[7px] shrink-0 rounded-full" style:background={dot[state]}></span>
    <!-- Plain text: what a program says is never markup -->
    <span class="lk-num shrink-0 font-semibold text-(--text-primary)">
      {label(state, record)}{#if progress !== undefined}&nbsp;{progress}%{/if}
    </span>
    {#if record?.report.title ?? app}
      <span class="shrink-0 text-(--text-secondary)">{record?.report.title ?? app}</span>
    {/if}
    {#if record?.report.msg}
      <span class="truncate text-(--text-secondary)" title={record.report.msg}>{record.report.msg}</span>
    {/if}
    {#if count > 1}
      <span class="lk-num shrink-0 text-(--text-tertiary)">+{count - 1}</span>
    {/if}
    {#if record && (state === 'done' || state === 'error')}
      <span class="flex-1"></span>
      <IconButton icon="close" size="sm" label={$LL.terminalProgramDismiss()} onclick={dismiss} />
    {/if}
  </div>
{/if}
