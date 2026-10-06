<script lang="ts">
  /// An iperf client run on the machine: a host and a port, then the terminal
  /// its output arrives on.
  ///
  /// The agent validates both values (`sbm_parser::iperf`) and builds the
  /// command, so this is a form and nothing more. The dialog is rendered by
  /// its opener only while it is open, so closing it drops the session.
  import { Button, Input, Modal } from '@serverbox/webui'
  import TargetTerminal from '../../../components/TargetTerminal.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { iperfIssueText } from '../../../lib/iperf'
  import type { TerminalTarget } from '../../../lib/terminal.svelte'

  interface Props {
    onclose: () => void
  }

  const { onclose }: Props = $props()

  let host = $state('')
  let port = $state('')
  /// The target the terminal runs, once Start was pressed. `null` while the
  /// form is showing.
  let target = $state<TerminalTarget | null>(null)

  /// The port as the wire wants it — a number. Not the range or format check:
  /// `sbm_parser::iperf` does that on the agent, and a value it refuses comes
  /// back as the translated issue below.
  const portValue = $derived(Number(port.trim()))
  const ready = $derived(
    host.trim() !== '' && port.trim() !== '' && Number.isFinite(portValue),
  )

  function start() {
    if (!ready) return
    target = { kind: 'iperf', host: host.trim(), port: portValue }
  }
</script>

<!-- As wide as the container shell's dialog: iperf's output lines wrap
     mid-word at the default width. -->
<Modal open title={$LL.iperf()} class="max-w-3xl" onclose={onclose}>
  {#if target === null}
    <div class="space-y-4">
      <div class="space-y-1">
        <span class="text-sm text-muted-fg">{$LL.iperfHost()}</span>
        <Input bind:value={host} placeholder="example.com" autocomplete="off" />
      </div>
      <div class="space-y-1">
        <span class="text-sm text-muted-fg">{$LL.iperfPort()}</span>
        <Input bind:value={port} placeholder="5201" autocomplete="off" />
      </div>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={onclose}>{$LL.cancel()}</Button>
        <Button disabled={!ready} onclick={start}>{$LL.iperfStart()}</Button>
      </div>
    </div>
  {:else}
    <!-- A refused host or port comes back to the form with what was typed;
         the refused session ends as the terminal leaves. -->
    <TargetTerminal {target} issueText={iperfIssueText} onedit={() => (target = null)} />
  {/if}
</Modal>
