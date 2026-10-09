<script lang="ts">
  /// One step of a task, in the middle of the flow view: what the model said
  /// about it, its command, and what it waits on the account for — a plan to
  /// confirm, a password, a choice, a command that cannot be undone.

  import { LL } from '../../i18n/i18n-svelte'
  import Markdown from '../../components/Markdown.svelte'
  import { Button, Checkbox, Icon, Input, Textarea } from '../lk'
  import type { Answer, FlowStatus, Pending } from '../../lib/agentApi'
  import { duration } from './agentView'
  import type { Step } from './flowModel'

  interface Props {
    step: Step
    /// What the task waits on, when it is this step.
    pending: Pending | null
    status: FlowStatus
    onanswer: (answer: Answer) => Promise<void>
    /// Sends what the account typed to change the plan: the answer to a plan
    /// waiting for confirmation, a new turn otherwise.
    onreply: (text: string) => Promise<void>
    /// Goes back to the timeline; the task keeps running.
    onbackground: () => void
    /// Asks the model to try again.
    onretry: () => void
  }

  const { step, pending, status, onanswer, onreply, onbackground, onretry }: Props = $props()

  let password = $state('')
  let remember = $state(true)
  let typed = $state('')
  let busy = $state(false)
  let error = $state<string | null>(null)
  /// The plan is being changed in words, under it.
  let editing = $state(false)
  let change = $state('')

  // What was typed belongs to what was asked.
  let askedId: string | null = null
  $effect(() => {
    const id = pending?.id ?? null
    if (id === askedId) return
    askedId = id
    password = ''
    typed = ''
    error = null
  })

  const waiting = $derived(pending && step.state === 'waiting' ? pending : null)
  const running = $derived(step.state === 'running')

  async function send(answer: Omit<Answer, 'id'>) {
    if (!waiting || busy) return
    busy = true
    error = null
    try {
      await onanswer({ id: waiting.id, ...answer })
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
  }

  async function sendChange() {
    const text = change.trim()
    if (!text || busy) return
    busy = true
    error = null
    try {
      await onreply(text)
      change = ''
      editing = false
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
  }

  function submitPassword() {
    if (!password) {
      error = $LL.deskAgentEnterPassword()
      return
    }
    void send({ action: 'password', password, remember })
  }

  const summary = $derived(
    step.kind === 'thinking' ? step.summary : step.summary || (waiting?.summary ?? ''),
  )
  const cmdLabel = $derived(
    running ? $LL.deskAgentCmdRunning() : step.state === 'done' || step.state === 'failed' ? $LL.deskAgentCmdRan() : step.state === 'cancelled' ? $LL.deskAgentCmdWould() : $LL.deskAgentCmdWill(),
  )
  const plan = $derived(waiting?.steps?.length ? waiting.steps : step.plan)
  const note = $derived.by(() => {
    if (step.state !== 'done') return null
    if (step.kind === 'plan') return step.by === 'auto' ? $LL.deskAgentApprovedAuto() : step.by === 'bypass' ? $LL.deskAgentApprovedBypass() : $LL.deskAgentApproved()
    if (step.kind === 'ask' && step.answer) return $LL.deskAgentChose({ answer: step.answer })
    if (step.kind === 'command' && step.exitCode === 0)
      return step.durationMs !== null && step.durationMs >= 1000
        ? `${$LL.deskAgentExitCode({ code: 0 })} · ${duration($LL, step.durationMs / 1000)}`
        : $LL.deskAgentExitCode({ code: 0 })
    return null
  })
  const failure = $derived.by(() => {
    if (step.state !== 'failed') return null
    if (step.error) return { title: $LL.deskAgentFailed(), detail: step.error }
    if (step.timedOut) return { title: $LL.deskAgentTimedOut(), detail: step.command ?? '' }
    const last = step.output.filter((l) => l[0] === 2).at(-1)?.[1] ?? step.output.at(-1)?.[1] ?? ''
    return { title: step.exitCode === null ? $LL.deskAgentFailed() : $LL.deskAgentExitCode({ code: step.exitCode }), detail: last }
  })
</script>

<div class="body">
  {#if summary || step.kind === 'thinking'}
    <div class="say">
      <div class="orb" class:orb--live={running}>
        <Icon name="auto_awesome" size={16} fill color="var(--color-accent-text)" />
      </div>
      <div class="say__text">
        {#if summary}<Markdown text={summary} />{:else}<span class="am-shimmer">{$LL.deskAgentThinking()}</span>{/if}
      </div>
    </div>
  {/if}

  {#if step.command && step.kind === 'command'}
    <div class="block">
      <div class="am-label">{cmdLabel}{step.sudo ? ' · sudo' : ''}</div>
      <div class="cmd"><span class="cmd__prompt">$</span><span class="cmd__text">{step.command}</span></div>
    </div>
  {/if}

  {#if step.kind === 'memory'}
    <div class="block">
      <div class="am-label">{$LL.deskAgentMemoryFile()}</div>
      <div class="cmd"><span class="cmd__text">{step.title}</span></div>
    </div>
  {/if}

  {#if running && step.kind === 'command'}
    <div class="card">
      <div class="plain">
        <Icon name="progress_activity" size={16} color="var(--color-accent-text)" class="am-spin" />
        <span class="am-shimmer">{$LL.deskAgentRunningPlain()}</span>
      </div>
      <div class="leave">
        <Icon name="notifications" size={16} color="var(--text-tertiary)" />
        <span class="leave__text">{$LL.deskAgentCanLeave()}</span>
        <Button size="sm" variant="secondary" onclick={onbackground}>{$LL.deskAgentInBackground()}</Button>
      </div>
    </div>
  {/if}

  {#if waiting?.kind === 'confirm'}
    <div class="block block--wide">
      <div class="am-label">{$LL.deskAgentPlan()}</div>
      <div class="plan">
        {#each plan as p, i (i)}
          <div class="plan__row" class:plan__row--rule={i > 0}>
            <span class="plan__n am-num">{i + 1}</span>
            <span class="plan__text">
              {p.text}
              {#if p.command}<code class="plan__cmd">{p.command}</code>{/if}
            </span>
          </div>
        {/each}
      </div>
      <div class="actions">
        <Button variant="primary" icon="play_arrow" disabled={busy} onclick={() => send({ action: 'run' })}>{$LL.deskAgentRun()}</Button>
        <Button variant="secondary" icon="edit" disabled={busy || editing} onclick={() => (editing = true)}>{$LL.deskAgentChangePlan()}</Button>
        <Button variant="ghost" disabled={busy} onclick={() => send({ action: 'cancel' })}>{$LL.deskAgentCancel()}</Button>
      </div>
    </div>
  {/if}

  {#if waiting?.kind === 'sudo'}
    <div class="card card--form">
      <div class="lock">
        <div class="lock__icon"><Icon name="lock" size={18} fill color="var(--color-warning)" /></div>
        <div class="lock__text">
          <span class="lock__title">{$LL.deskAgentRootNeeded()}</span>
          <span class="lock__note">{$LL.deskAgentRootOnly()}</span>
        </div>
      </div>
      <Input
        type="password"
        label={$LL.deskAgentPasswordOf({ user: waiting.user ?? 'root' })}
        icon="key"
        autocomplete="off"
        bind:value={password}
        error={error ?? (waiting.error === 'wrongPassword' ? $LL.deskAgentWrongPassword() : undefined)}
        hint={$LL.deskAgentPasswordHint()}
        onkeydown={(e: KeyboardEvent) => {
          if (e.key === 'Enter') submitPassword()
        }}
      />
      <Checkbox bind:checked={remember} label={$LL.deskAgentRemember()} />
      <div class="actions">
        <Button variant="primary" icon="lock_open" disabled={busy} onclick={submitPassword}>{$LL.deskAgentAuthorize()}</Button>
        <Button variant="ghost" disabled={busy} onclick={() => send({ action: 'cancel' })}>{$LL.deskAgentCancel()}</Button>
      </div>
    </div>
  {/if}

  {#if waiting?.kind === 'clarify'}
    <div class="block">
      <div class="am-label">{$LL.deskAgentPickOne()}</div>
      <div class="options">
        {#each waiting.options ?? [] as o, i (i)}
          <button class="option" disabled={busy} onclick={() => send({ action: 'pick', index: i })}>
            <Icon name="radio_button_unchecked" size={18} color="var(--color-accent-text)" />
            <span class="option__label">{o.label}</span>
            {#if o.hint}<span class="option__hint am-ellipsis">{o.hint}</span>{/if}
            <span class="option__key am-num">{i + 1}</span>
          </button>
        {/each}
      </div>
      <div class="hint">{$LL.deskAgentNoneOfThese()}</div>
    </div>
  {/if}

  {#if waiting?.kind === 'danger'}
    <div class="card card--danger">
      <div class="danger__head">
        <Icon name="warning" size={18} fill color="var(--color-danger)" />
        <span class="danger__title">{$LL.deskAgentIrreversible()}</span>
      </div>
      {#if waiting.summary}<div class="danger__reason">{waiting.summary}</div>{/if}
      <Input
        label={$LL.deskAgentTypeToConfirm({ host: waiting.confirmText ?? '' })}
        placeholder={waiting.confirmText}
        mono
        autocomplete="off"
        bind:value={typed}
        error={error ?? undefined}
      />
      <div class="actions">
        <Button
          variant="destructive"
          icon="delete"
          disabled={busy || typed.trim() !== waiting.confirmText}
          onclick={() => send({ action: 'run', confirm: typed.trim() })}
        >
          {$LL.deskAgentRunAnyway()}
        </Button>
        {#each waiting.alternatives ?? [] as a, i (i)}
          <Button variant="secondary" icon="inventory_2" disabled={busy} onclick={() => send({ action: 'alternative', index: i })}>{a}</Button>
        {/each}
        <Button variant="ghost" disabled={busy} onclick={() => send({ action: 'cancel' })}>{$LL.deskAgentCancel()}</Button>
      </div>
    </div>
  {/if}

  {#if step.state === 'cancelled'}
    <div class="block block--rise">
      <div class="quiet">
        <Icon name="do_not_disturb_on" size={17} color="var(--text-tertiary)" />
        {step.kind === 'command' && step.answer ? $LL.deskAgentChose({ answer: step.answer }) : $LL.deskAgentCancelled()}
      </div>
      {#if step.plan.length}
        <div class="plan plan--struck">
          {#each step.plan as p, i (i)}
            <div class="plan__row"><span class="plan__n am-num">{i + 1}</span>{p.text}</div>
          {/each}
        </div>
        <div class="actions">
          <Button variant="ghost" icon="edit" disabled={editing} onclick={() => (editing = true)}>{$LL.deskAgentChangePlan()}</Button>
        </div>
      {/if}
    </div>
  {/if}

  {#if failure}
    <div class="block block--rise">
      <div class="fail">
        <Icon name="error" size={18} fill color="var(--color-danger)" />
        <div class="fail__text">
          <span class="fail__title">{failure.title}</span>
          {#if failure.detail}<span class="fail__detail">{failure.detail}</span>{/if}
        </div>
      </div>
      {#if status === 'failed'}
        <div class="actions">
          <Button variant="primary" icon="refresh" onclick={onretry}>{$LL.deskAgentRetry()}</Button>
          <Button variant="secondary" icon="edit" disabled={editing} onclick={() => (editing = true)}>{$LL.deskAgentChangePlan()}</Button>
        </div>
      {/if}
    </div>
  {/if}

  {#if step.state === 'pending'}
    <div class="quiet quiet--line">
      <Icon name="hourglass_empty" size={16} />
      {$LL.deskAgentQueuedNote()}
    </div>
  {/if}

  {#if note}
    <div class="note">
      <span class="am-check"><Icon name="check_circle" size={17} fill /></span>
      {note}
    </div>
  {/if}

  {#if editing}
    <div class="block block--rise">
      <Textarea
        label={$LL.deskAgentChangePlan()}
        placeholder={$LL.deskAgentChangePlanHint()}
        rows={3}
        autofocus
        bind:value={change}
        onkeydown={(e: KeyboardEvent) => {
          if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) {
            e.preventDefault()
            void sendChange()
          } else if (e.key === 'Escape') {
            e.stopPropagation()
            editing = false
          }
        }}
      />
      <div class="actions">
        <Button variant="primary" icon="arrow_upward" disabled={busy || !change.trim()} onclick={sendChange}>{$LL.deskAgentSend()}</Button>
        <Button variant="ghost" disabled={busy} onclick={() => (editing = false)}>{$LL.deskAgentCancel()}</Button>
      </div>
    </div>
  {/if}

  <!-- The model's words look as they did while it wrote them; the account's are a bubble. -->
  {#each step.chat as m, i (i)}
    {#if m.me}
      <div class="chat chat--me"><div class="chat__bubble">{m.text}</div></div>
    {:else}
      <div class="say chat">
        <div class="orb"><Icon name="auto_awesome" size={16} fill color="var(--color-accent-text)" /></div>
        <div class="say__text"><Markdown text={m.text} /></div>
      </div>
    {/if}
  {/each}

  {#if error && waiting?.kind !== 'sudo' && waiting?.kind !== 'danger'}
    <div class="quiet" style:color="var(--color-danger)">{error}</div>
  {/if}
</div>

<style>
  .body {
    display: flex;
    flex-direction: column;
    gap: var(--space-21);
  }
  .say {
    display: flex;
    gap: var(--space-13);
    align-items: flex-start;
  }
  .orb {
    flex: none;
    display: grid;
    place-items: center;
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: var(--color-accent-soft);
  }
  .orb--live {
    animation: am-breathe 2.4s ease-in-out infinite;
  }
  .say__text {
    flex: 1;
    min-width: 0;
    padding-top: var(--space-3);
    font-size: var(--text-15);
    line-height: var(--leading-body);
    text-wrap: pretty;
    white-space: pre-wrap;
  }
  .block {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
  }
  .block--wide {
    gap: var(--space-13);
  }
  .block--rise {
    gap: var(--space-13);
    animation: am-rise var(--dur-content-in) var(--ease-spring);
  }
  .cmd {
    display: flex;
    align-items: flex-start;
    gap: var(--space-9);
    padding: var(--space-9) var(--space-13);
    border-radius: var(--radius-control);
    background: var(--surface-card);
    font-family: var(--font-mono);
    font-size: var(--text-12);
    line-height: 1.6;
  }
  .cmd__prompt {
    color: var(--color-accent-text);
    font-weight: 600;
  }
  .cmd__text {
    flex: 1;
    min-width: 0;
    word-break: break-all;
    white-space: pre-wrap;
  }
  .card {
    display: flex;
    flex-direction: column;
    gap: var(--space-13);
    padding: var(--space-17) var(--space-21);
    border-radius: var(--radius-card);
    background: var(--surface-card);
  }
  .card--form {
    gap: var(--space-17);
    padding: var(--space-21);
  }
  .card--danger {
    gap: var(--space-17);
    padding: var(--space-21);
    background: var(--color-danger-soft);
  }
  .plain {
    display: flex;
    align-items: center;
    gap: var(--space-9);
    font-size: var(--text-13);
  }
  .leave {
    display: flex;
    align-items: center;
    gap: var(--space-11);
    padding-top: var(--space-11);
    border-top: 0.5px solid var(--border-hairline);
  }
  .leave__text {
    flex: 1;
    font-size: var(--text-12);
    color: var(--text-secondary);
  }
  .plan {
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-card);
    background: var(--surface-card);
    padding: var(--space-3) 0;
  }
  .plan--struck {
    background: transparent;
    box-shadow: inset 0 0 0 0.5px var(--border-hairline);
  }
  .plan__row {
    display: flex;
    align-items: baseline;
    gap: var(--space-11);
    padding: var(--space-9) var(--space-17);
    font-size: var(--text-13);
    line-height: var(--leading-snug);
  }
  .plan__row--rule {
    border-top: 0.5px solid var(--border-hairline);
  }
  .plan--struck .plan__row {
    color: var(--text-tertiary);
    text-decoration: line-through;
  }
  .plan__n {
    flex: none;
    width: 14px;
    font-size: var(--text-12);
    font-weight: 700;
    color: var(--color-accent-text);
  }
  .plan--struck .plan__n {
    color: inherit;
  }
  .plan__text {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    min-width: 0;
  }
  .plan__cmd {
    font-family: var(--font-mono);
    font-size: var(--text-12);
    color: var(--text-secondary);
    word-break: break-all;
  }
  .actions {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-7);
  }
  .lock {
    display: flex;
    align-items: center;
    gap: var(--space-11);
  }
  .lock__icon {
    display: grid;
    place-items: center;
    width: 34px;
    height: 34px;
    border-radius: var(--radius-control);
    background: var(--color-warning-soft);
  }
  .lock__text {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .lock__title {
    font-size: var(--text-15);
    font-weight: 600;
  }
  .lock__note {
    font-size: var(--text-12);
    color: var(--text-secondary);
  }
  .options {
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-card);
    background: var(--surface-card);
    padding: var(--space-5);
  }
  .option {
    display: flex;
    align-items: center;
    gap: var(--space-11);
    height: 48px;
    padding: 0 var(--space-13);
    border: 0;
    border-radius: var(--radius-control);
    background: transparent;
    font: inherit;
    text-align: left;
    cursor: default;
    color: var(--text-primary);
    transition:
      background var(--dur-fast) var(--ease-standard),
      transform var(--dur-base) var(--ease-spring-bouncy);
  }
  .option:hover {
    background: var(--surface-raised);
    box-shadow: var(--shadow-control);
  }
  .option:active {
    transform: scale(0.98);
  }
  .option__label {
    font-family: var(--font-mono);
    font-size: var(--text-13);
    font-weight: 600;
    white-space: nowrap;
  }
  .option__hint {
    font-size: var(--text-12);
    color: var(--text-secondary);
    min-width: 0;
  }
  .option__key {
    margin-left: auto;
    font-size: var(--text-11);
    color: var(--text-tertiary);
  }
  .hint {
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }
  .danger__head {
    display: flex;
    align-items: center;
    gap: var(--space-9);
  }
  .danger__title {
    font-size: var(--text-15);
    font-weight: 600;
  }
  .danger__reason {
    font-size: var(--text-13);
    color: var(--text-secondary);
    line-height: var(--leading-snug);
  }
  .quiet {
    display: flex;
    align-items: center;
    gap: var(--space-9);
    padding: var(--space-11) var(--space-13);
    border-radius: var(--radius-control);
    background: var(--surface-card);
    font-size: var(--text-13);
    color: var(--text-secondary);
  }
  .quiet--line {
    background: transparent;
    box-shadow: inset 0 0 0 0.5px var(--border-hairline);
    color: var(--text-tertiary);
  }
  .fail {
    display: flex;
    gap: var(--space-11);
    padding: var(--space-13) var(--space-17);
    border-radius: var(--radius-card);
    background: var(--color-danger-soft);
  }
  .fail__text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }
  .fail__title {
    font-size: var(--text-13);
    font-weight: 600;
  }
  .fail__detail {
    font-family: var(--font-mono);
    font-size: var(--text-12);
    color: var(--text-secondary);
    word-break: break-all;
  }
  .note {
    display: flex;
    align-items: center;
    gap: var(--space-9);
    padding: var(--space-11) var(--space-13);
    border-radius: var(--radius-control);
    background: var(--color-success-soft);
    color: var(--color-success);
    font-size: var(--text-13);
    font-weight: var(--weight-semibold);
    animation: lk-pop-in var(--dur-slow) var(--ease-spring-bouncy);
  }
  .chat {
    display: flex;
    justify-content: flex-start;
    animation: am-rise var(--dur-content-in) var(--ease-spring);
  }
  .chat--me {
    justify-content: flex-end;
  }
  .chat__bubble {
    max-width: 80%;
    padding: var(--space-9) var(--space-13);
    border-radius: var(--radius-card);
    background: var(--surface-selected);
    font-size: var(--text-13);
    line-height: var(--leading-snug);
    color: var(--text-primary);
    text-wrap: pretty;
    white-space: pre-wrap;
  }
</style>
