<script lang="ts">
  /// A shell the agent runs on this machine for a target: inside a container,
  /// or an iperf client. The dialog that opens it owns the chrome.
  ///
  /// The session is the terminal endpoint's, with the target in the open
  /// frame: the agent builds the command (`docker exec`, `iperf -c …`) from
  /// it, so nothing here composes one. Offered only where the agent lists the
  /// matching feature.
  import { onMount } from 'svelte'
  import { Spinner } from '@serverbox/webui'
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
  }

  const { target, issueText }: Props = $props()

  // `persist: false`: the dialog owns its own handle, and must never read or
  // write the `terminal.session` key the terminal page uses — that key is one
  // handle, so sharing it would attach this dialog to the shell the page left
  // behind.
  const session = new TerminalSession({ persist: false })
  let host = $state<HTMLDivElement | null>(null)
  let terminal: TerminalHandle | null = null
  let mounting = $state(true)

  /// Typing belongs in the shell, not in whichever button opened the dialog.
  /// Focused once the session is up: before that there is nothing to type at.
  $effect(() => {
    if (session.phase === 'running') terminal?.focus()
  })

  onMount(() => {
    let cancelled = false
    void (async () => {
      if (!host) return
      const mounted = await mountTerminal(host, session)
      if (cancelled) {
        mounted.dispose()
        return
      }
      terminal = mounted
      mounting = false
      // The local account, with the target: the agent runs the command as its
      // own user.
      await session.start(mounted.renderer, '', { kind: 'local' }, target)
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

<div class="space-y-2">
  <!-- The container carries the terminal's own background, so the strip the
       last row does not fill is not a colour of its own. -->
  <div
    class="relative h-96 rounded-md overflow-hidden"
    style="background-color: {terminalSurface.current}"
  >
    <!-- Positioned rather than sized: xterm measures what it is opened into,
         and `inset-0` against a positioned parent is unambiguous. -->
    <div bind:this={host} class="absolute inset-0"></div>

    {#if mounting}
      <div class="absolute inset-0 flex items-center justify-center bg-bg/70">
        <Spinner class="w-5 h-5" />
      </div>
    {/if}
    {#if session.phase === 'reconnecting'}
      <div
        class="absolute inset-0 flex items-center justify-center gap-2 bg-bg/70 backdrop-blur-[1px]"
      >
        <Spinner class="w-5 h-5" />
        <span class="text-sm text-fg-strong">{$LL.terminalReconnecting()}</span>
      </div>
    {/if}
  </div>

  {#if session.error}
    <p class="text-sm text-danger">
      {session.errorCode === 'invalid_input' && session.issueCode && issueText
        ? issueText(session.issueCode)
        : session.errorCode === 'no_container_runtime'
          ? $LL.containerErrNoRuntime()
          : session.error}
    </p>
  {/if}
  <!-- The command has ended; its output is still on screen above. -->
  {#if session.phase === 'closed' && session.exitStatus !== null}
    <p class="text-xs text-muted-fg">{$LL.targetExitStatus({ code: session.exitStatus })}</p>
  {/if}
</div>
