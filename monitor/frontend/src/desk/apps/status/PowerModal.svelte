<script lang="ts">
  import { Button, Input, Modal, Spinner } from '@serverbox/webui'
  import { CirclePower, Moon, RotateCw } from '@lucide/svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { ApiError, api } from '../../../lib/api'
  import type { PowerAction } from '../../../types'

  interface Props {
    open: boolean
    onclose: () => void
  }

  const { open, onclose }: Props = $props()

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
      pending = null
      password = ''
      running = false
      error = ''
      sent = null
    }
  })

  const actions: { action: PowerAction; label: () => string; icon: typeof CirclePower }[] = [
    { action: 'shutdown', label: () => $LL.powerShutdown(), icon: CirclePower },
    { action: 'reboot', label: () => $LL.powerReboot(), icon: RotateCw },
    { action: 'suspend', label: () => $LL.powerSuspend(), icon: Moon },
  ]

  const labelOf = (action: PowerAction) => actions.find((a) => a.action === action)?.label() ?? action

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

<Modal {open} title={$LL.powerControl()} {onclose}>
  {#if sent}
    <div class="space-y-4">
      <p class="text-sm text-fg">{$LL.powerActionSent({ action: labelOf(sent) })}</p>
      <div class="flex justify-end">
        <Button size="sm" onclick={onclose}>{$LL.close()}</Button>
      </div>
    </div>
  {:else}
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.powerNote()}</p>

      <div class="flex flex-col gap-2">
        {#each actions as { action, label, icon } (action)}
          {@const Icon = icon}
          <Button
            variant={pending === action ? 'primary' : 'secondary'}
            size="sm"
            disabled={running}
            onclick={() => (pending = action)}
          >
            <Icon class="w-4 h-4 mr-2" />
            {label()}
          </Button>
        {/each}
      </div>

      <div class="space-y-1">
        <label class="text-sm text-muted-fg" for="power-password">{$LL.powerPassword()}</label>
        <Input id="power-password" type="password" autocomplete="off" bind:value={password} />
        <p class="text-xs text-muted-fg">{$LL.powerPasswordHint()}</p>
      </div>

      {#if error}
        <p class="text-sm text-danger" role="alert">{error}</p>
      {/if}

      <div class="flex items-center justify-end gap-2 pt-2">
        <Button variant="ghost" size="sm" onclick={onclose}>{$LL.cancel()}</Button>
        <Button
          variant={pending === 'shutdown' ? 'danger' : 'primary'}
          size="sm"
          disabled={!pending || running}
          onclick={run}
        >
          {#if running}
            <Spinner size="sm" class="mr-2" />
          {/if}
          {pending ? labelOf(pending) : $LL.powerControl()}
        </Button>
      </div>
    </div>
  {/if}
</Modal>
