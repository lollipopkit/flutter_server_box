<script lang="ts">
  import Button from '../desk/lk/Button.svelte'
  import Dialog from '../desk/lk/Dialog.svelte'
  import Input from '../desk/lk/Input.svelte'
  import Spinner from '../desk/lk/Spinner.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { ApiError, api } from '../lib/api'
  import type { PowerAction } from '../types'

  /// Shuts down, reboots or suspends the machine: shared by Status and
  /// Settings → Server.

  interface Props {
    open: boolean
    onclose: () => void
    /// The action already picked (a Settings row's), still to be confirmed.
    initial?: PowerAction
  }

  const { open, onclose, initial }: Props = $props()

  /// Two steps on purpose: the first click picks the action, the second runs
  /// it. One click from a shutdown is one misclick from one, and the machine
  /// may be the one serving this panel.
  let pending = $state<PowerAction | null>(null)
  let password = $state('')
  let running = $state(false)
  /// Kept on screen after a refusal, so a second try is a retype rather
  /// than a reopen.
  let error = $state('')
  /// What was sent. For a shutdown or a reboot the answer can arrive before
  /// the machine goes, so this says what was asked, not what happened next.
  let sent = $state<PowerAction | null>(null)

  $effect(() => {
    if (open) {
      pending = initial ?? null
      password = ''
      running = false
      error = ''
      sent = null
    }
  })

  const powerActions: { action: PowerAction; label: () => string; icon: string }[] = [
    { action: 'shutdown', label: () => $LL.powerShutdown(), icon: 'power_settings_new' },
    { action: 'reboot', label: () => $LL.powerReboot(), icon: 'restart_alt' },
    { action: 'suspend', label: () => $LL.powerSuspend(), icon: 'bedtime' },
  ]

  const labelOf = (action: PowerAction) => powerActions.find((a) => a.action === action)?.label() ?? action

  async function run() {
    if (!pending) return
    const action = pending
    running = true
    error = ''
    try {
      const result = await api.power(action, password)
      if (result.sudo_rejected) {
        error = $LL.powerRejected()
      } else if (result.timed_out) {
        // A machine suspending under the command never answers.
        error = $LL.powerTimeout()
      } else if (result.exit_code !== 0) {
        error = result.stderr.trim() || $LL.powerFailed()
      } else {
        sent = action
      }
    } catch (err) {
      // No status at all: the agent went before it could answer, which is
      // what a shutdown or a reboot that worked looks like from here.
      if (err instanceof ApiError && err.status === undefined && action !== 'suspend') {
        sent = action
      } else {
        error = err instanceof Error ? err.message : $LL.powerFailed()
      }
    } finally {
      running = false
    }
  }
</script>

<Dialog open={open} wide title={$LL.powerControl()} onclose={onclose}>
  {#if sent}
    <p class="text-[13px] text-(--text-primary)">{$LL.powerActionSent({ action: labelOf(sent) })}</p>
  {:else}
    <div class="space-y-[13px]">
        <p class="text-[13px] text-(--text-secondary)">{$LL.powerNote()}</p>
        <div class="flex flex-wrap gap-[7px]">
          {#each powerActions as { action, label, icon } (action)}
            <Button
              variant={pending === action ? 'tinted' : 'secondary'}
              size="sm"
              disabled={running}
              icon={icon}
              onclick={() => (pending = action)}
            >{label()}</Button>
          {/each}
        </div>
        <Input label={$LL.powerPassword()} id="power-password" type="password" autocomplete="off" bind:value={password} hint={$LL.powerPasswordHint()} />
        {#if error}<p class="text-[13px] text-(--color-danger)" role="alert">{error}</p>{/if}
    </div>
  {/if}
  {#snippet actions()}
    {#if sent}
      <Button onclick={onclose}>{$LL.close()}</Button>
    {:else}
      <Button variant="ghost" onclick={onclose}>{$LL.cancel()}</Button>
      <Button
        variant={pending === 'shutdown' ? 'destructive' : 'primary'}
        disabled={!pending || running}
        icon={running ? undefined : pending === 'reboot' ? 'restart_alt' : pending === 'suspend' ? 'bedtime' : pending ? 'power_settings_new' : undefined}
        onclick={run}
      >
        {#if running}<Spinner size={16} />{/if}
        {pending ? labelOf(pending) : $LL.powerControl()}
      </Button>
    {/if}
  {/snippet}
</Dialog>
