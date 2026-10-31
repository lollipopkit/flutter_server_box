<script lang="ts">
  /// A step's output, as a terminal shows it: numbered lines, errors apart,
  /// a long output folded in the middle, following the end while it runs.

  import { LL } from '../../i18n/i18n-svelte'
  import { Icon, IconButton, SegmentedControl } from '../lk'
  import type { Step } from './flowModel'
  import { termRows } from './flowModel'

  interface Props {
    step: Step | null
  }

  const { step }: Props = $props()

  let filter = $state<'all' | 'err'>('all')
  let wrap = $state(false)
  let expanded = $state(false)
  let follow = $state(true)
  let copied = $state(false)
  let box = $state<HTMLDivElement | null>(null)

  const lines = $derived(step?.output ?? [])
  const errors = $derived(lines.filter((l) => l[0] === 2).length)
  const hasErrors = $derived(errors > 0 && errors < lines.length)
  const rows = $derived(
    termRows(lines, {
      errorsOnly: filter === 'err' && hasErrors,
      expanded,
      omitted: step?.omitted ?? 0,
      omittedAt: step?.omittedAt ?? lines.length,
    }),
  )
  const total = $derived(lines.length + (step?.omitted ?? 0))
  const running = $derived(step?.state === 'running')

  // A new step starts from its top, or its end while it runs.
  let shown: string | null = null
  $effect(() => {
    const id = step?.id ?? null
    if (id === shown) return
    shown = id
    filter = 'all'
    expanded = false
    follow = true
    queueMicrotask(() => {
      if (box) box.scrollTop = running ? box.scrollHeight : 0
    })
  })
  $effect(() => {
    void rows.length
    if (follow && running && box) queueMicrotask(() => box && (box.scrollTop = box.scrollHeight))
  })

  function onscroll() {
    if (!box) return
    follow = box.scrollHeight - box.scrollTop - box.clientHeight < 24
  }

  async function copy() {
    try {
      await navigator.clipboard.writeText(lines.map((l) => l[1]).join('\n'))
      copied = true
      setTimeout(() => (copied = false), 1400)
    } catch {
      // The clipboard refused: nothing to say.
    }
  }

  function jump() {
    filter = 'all'
    expanded = true
    follow = true
    queueMicrotask(() => box && (box.scrollTop = box.scrollHeight))
  }

  const status = $derived.by(() => {
    if (!step) return { text: $LL.deskAgentNotRun(), dot: 'var(--text-disabled)', color: 'var(--text-tertiary)', pulse: false }
    if (running) return { text: $LL.deskAgentReceiving(), dot: 'var(--color-accent)', color: 'var(--text-secondary)', pulse: true }
    if (step.timedOut) return { text: $LL.deskAgentTimedOut(), dot: 'var(--color-danger)', color: 'var(--color-danger)', pulse: false }
    if (step.exitCode !== null) {
      const ok = step.exitCode === 0
      return {
        text: $LL.deskAgentExitCode({ code: step.exitCode }),
        dot: ok ? 'var(--color-success)' : 'var(--color-danger)',
        color: ok ? 'var(--text-tertiary)' : 'var(--color-danger)',
        pulse: false,
      }
    }
    return { text: $LL.deskAgentNotRun(), dot: 'var(--text-disabled)', color: 'var(--text-tertiary)', pulse: false }
  })
</script>

<div class="pane">
  <div class="head">
    <Icon name="terminal" size={17} color="var(--text-secondary)" />
    <span class="head__title">{$LL.deskAgentOutput()}</span>
    {#if total}<span class="head__count am-num">{$LL.deskAgentLines({ n: total.toLocaleString() })}</span>{/if}
    <div class="grow"></div>
    {#if hasErrors}
      <SegmentedControl
        size="sm"
        value={filter}
        options={[
          { value: 'all', label: $LL.deskAgentAll() },
          { value: 'err', label: $LL.deskAgentErrors({ n: errors }) },
        ]}
        onchange={(v) => {
          filter = v
          follow = false
          if (box) box.scrollTop = 0
        }}
      />
    {/if}
    <IconButton icon="wrap_text" label={$LL.deskAgentWrap()} size="sm" active={wrap} onclick={() => (wrap = !wrap)} />
    <IconButton icon={copied ? 'check' : 'content_copy'} label={$LL.deskAgentCopy()} size="sm" disabled={!lines.length} onclick={copy} />
  </div>
  <div class="body" bind:this={box} {onscroll}>
    {#if !lines.length && !(step?.omitted ?? 0)}
      <div class="empty">
        <Icon name="terminal" size={44} />
        <span>{$LL.deskAgentNoOutput()}</span>
      </div>
    {/if}
    <div class="lines" class:lines--wrap={wrap} class:lines--still={lines.length > 200}>
      {#each rows as r, i ('n' in r ? `l${r.n}` : `f${i}`)}
        {#if 'n' in r}
          <div class="line" class:line--err={r.line[0] === 2}>
            <span class="line__n am-num">{r.n}</span>
            <span class="line__text">{r.line[1]}</span>
          </div>
        {:else if r.fold === 'expand'}
          <button class="fold" onclick={() => ((expanded = true), (follow = false))}>
            <Icon name="unfold_more" size={15} />
            {$LL.deskAgentFolded({ n: r.count.toLocaleString() })}
          </button>
        {:else}
          <div class="fold fold--still">
            <Icon name="more_horiz" size={15} />
            {$LL.deskAgentNotKept({ n: r.count.toLocaleString() })}
          </div>
        {/if}
      {/each}
    </div>
  </div>
  <div class="foot">
    <span class="foot__dot" class:am-pulse={status.pulse} style:background={status.dot}></span>
    <span style:color={status.color}>{status.text}</span>
    {#if !follow && (running || lines.length > 120)}
      <button class="jump" onclick={jump}>
        <Icon name="vertical_align_bottom" size={14} />
        {$LL.deskAgentJumpLatest()}
      </button>
    {/if}
  </div>
</div>

<style>
  .pane {
    display: flex;
    flex-direction: column;
    min-height: 0;
    min-width: 0;
    height: 100%;
    border-radius: var(--radius-window);
    background: var(--surface-terminal);
    box-shadow:
      inset 0 0 0 0.5px var(--border-hairline),
      var(--shadow-popover);
    overflow: hidden;
  }
  .head {
    flex: none;
    display: flex;
    align-items: center;
    gap: var(--space-9);
    height: 52px;
    padding: 0 var(--space-9) 0 var(--space-17);
    border-bottom: 0.5px solid var(--border-hairline);
  }
  .head__title {
    font-size: var(--text-13);
    font-weight: 700;
  }
  .head__count {
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: nowrap;
  }
  .grow {
    flex: 1;
  }
  .body {
    flex: 1;
    min-height: 0;
    overflow: auto;
    padding: var(--space-9) 0;
    font-family: var(--font-mono);
    font-size: var(--text-12);
    line-height: 1.75;
  }
  .empty {
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-9);
    color: var(--text-tertiary);
    font-family: var(--font-ui);
    font-size: var(--text-13);
  }
  .lines {
    width: max-content;
    min-width: 100%;
  }
  .lines--wrap {
    width: auto;
  }
  .line {
    display: grid;
    grid-template-columns: 52px minmax(0, 1fr);
    animation: am-line 280ms var(--ease-standard);
  }
  .lines--still .line {
    animation: none;
  }
  .line--err {
    background: color-mix(in srgb, var(--color-danger) 9%, transparent);
  }
  .line__n {
    text-align: right;
    padding-right: var(--space-13);
    color: var(--text-disabled);
    user-select: none;
  }
  .line__text {
    padding-right: var(--space-17);
    white-space: pre;
    color: var(--text-primary);
  }
  .lines--wrap .line__text {
    white-space: pre-wrap;
    word-break: break-all;
  }
  .line--err .line__text {
    color: var(--color-danger);
  }
  .fold {
    display: flex;
    align-items: center;
    gap: var(--space-9);
    margin: var(--space-5) var(--space-13);
    padding: 0 var(--space-11);
    height: 28px;
    border: 0;
    border-radius: var(--radius-sm);
    background: var(--surface-card);
    font-family: var(--font-ui);
    font-size: var(--text-12);
    color: var(--text-secondary);
    cursor: default;
  }
  .fold:hover {
    filter: brightness(0.97);
  }
  .fold--still {
    width: max-content;
    color: var(--text-tertiary);
  }
  .foot {
    flex: none;
    display: flex;
    align-items: center;
    gap: var(--space-7);
    height: 34px;
    padding: 0 var(--space-17);
    border-top: 0.5px solid var(--border-hairline);
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }
  .foot__dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }
  .jump {
    margin-left: auto;
    display: flex;
    align-items: center;
    gap: var(--space-3);
    border: 0;
    background: transparent;
    font: inherit;
    font-size: var(--text-12);
    color: var(--color-accent-text);
    cursor: default;
    padding: 0;
  }
</style>
