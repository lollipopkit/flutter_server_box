<script lang="ts">
  /// A shell the agent runs on this machine for a target: inside a container,
  /// or an iperf client. The dialog that opens it owns the chrome.
  ///
  /// The session is the terminal endpoint's, with the target in the open
  /// frame: the agent builds the command (`docker exec`, `iperf -c …`) from
  /// it, so nothing here composes one. Offered only where the agent lists the
  /// matching feature.
  import { onMount } from 'svelte'
  import Button from '../desk/lk/Button.svelte'
  import Spinner from '../desk/lk/Spinner.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { TerminalSession, type TerminalTarget } from '../lib/terminal.svelte'
  import { terminalSurface } from '../lib/terminalSurface.svelte'
  import { mountTerminal, type TerminalHandle } from '../lib/xterm'

  interface Props {
    target: TerminalTarget
    /// Phrase the agent's refusal of a target value, from the issue code it
    /// sent. The dialog that knows the target's vocabulary passes this; a
    /// caller that does not gets the agent's own message.
    issueText?: (issue: string) => string
    /// Back to the form that named the target, offered after the agent refused
    /// one of its values: nothing ran, so there is nothing on screen to keep.
    /// Leaving this component closes the refused session.
    onedit?: () => void
  }

  const { target, issueText, onedit }: Props = $props()

  // `persist: false`: the dialog owns its own handle, and must never read or
  // write the `terminal.session` key the terminal page uses — that key is one
  // handle, so sharing it would attach this dialog to the shell the page left
  // behind.
  const session = new TerminalSession({ persist: false })
  let host = $state<HTMLDivElement | null>(null)
  let terminal: TerminalHandle | null = null
  let mounting = $state(true)
  /// The terminal failed to load (its chunk did not arrive): said instead of
  /// a spinner that never ends.
  let mountFailed = $state(false)

  /// Typing belongs in the shell, not in whichever button opened the dialog.
  /// Focused once the session is up: before that there is nothing to type at.
  $effect(() => {
    if (session.phase === 'running') terminal?.focus()
  })

  onMount(() => {
    let cancelled = false
    void (async () => {
      if (!host) return
      let mounted: TerminalHandle
      try {
        mounted = await mountTerminal(host, session)
      } catch {
        if (!cancelled) {
          mounting = false
          mountFailed = true
        }
        return
      }
      if (cancelled) {
        mounted.dispose()
        return
      }
      terminal = mounted
      mounting = false
      // The local account, with the target: the agent runs the command as its
      // own user.
      await session.start(mounted.renderer, { kind: 'local' }, target)
    })()
    return () => {
      cancelled = true
      // `close`, not `dispose`: it sends the close frame so the agent ends the
      // shell at once instead of keeping it until it times out.
      session.close()
      terminal?.dispose()
    }
  })
</script>

<div class="flex flex-col gap-[7px]">
  <!-- The container carries the terminal's own background, so the strip the
       last row does not fill is not a colour of its own. -->
  <div
    class="relative h-96 overflow-hidden rounded-[var(--radius-card)] shadow-[inset_0_0_0_0.5px_var(--border-hairline)]"
    style="background-color: {terminalSurface.current}"
  >
    <!-- Positioned rather than sized: xterm measures what it is opened into,
         and `inset-0` against a positioned parent is unambiguous. -->
    <div bind:this={host} class="absolute inset-0"></div>

    {#if mounting}
      <div class="absolute inset-0 flex items-center justify-center bg-(--surface-window)/70">
        <Spinner size={20} />
      </div>
    {/if}
    {#if session.phase === 'reconnecting'}
      <div
        class="absolute inset-0 flex items-center justify-center gap-[7px] bg-(--surface-window)/70 backdrop-blur-[1px]"
      >
        <Spinner size={20} />
        <span class="text-[13px] font-medium">{$LL.terminalReconnecting()}</span>
      </div>
    {/if}
  </div>

  {#if mountFailed}
    <p class="text-[12px] text-(--color-danger)">{$LL.terminalLoadFailed()}</p>
  {/if}
  <!-- The outage outlasted the agent's buffer, so what is on screen has a
       hole in it — the terminal page says the same. -->
  {#if session.truncated}
    <p class="text-[12px] text-(--text-tertiary)">{$LL.terminalOutputLost()}</p>
  {/if}
  {#if session.error}
    <p class="text-[12px] text-(--color-danger)">
      {session.errorCode === 'invalid_input' && session.issueCode && issueText
        ? issueText(session.issueCode)
        : session.errorCode === 'no_container_runtime'
          ? $LL.containerErrNoRuntime()
          : session.error}
    </p>
    {#if onedit && session.errorCode === 'invalid_input'}
      <Button size="sm" icon="chevron_left" onclick={onedit}>{$LL.back()}</Button>
    {/if}
  {/if}
  <!-- The command has ended; its output is still on screen above. -->
  {#if session.phase === 'closed' && session.exitStatus !== null}
    <p class="text-[12px] text-(--text-tertiary)">{$LL.targetExitStatus({ code: session.exitStatus })}</p>
  {/if}
</div>
