<script lang="ts">
  /// Asks the administrator's own password before a change to who can do
  /// what: every such request carries it, so that a session left open is not
  /// enough to hand out a shell.
  ///
  /// One dialog for every change. [onconfirm] does the change with the
  /// password; a rejection keeps the dialog open with the reason, so a mistyped
  /// password is retyped rather than the change started over.

  import { Button, Input, Modal, Spinner } from '@serverbox/webui'
  import { LL } from '../../../i18n/i18n-svelte'
  import { accessMessage } from '../../../lib/access'

  interface Props {
    open: boolean
    /// What is about to happen, said above the field.
    message?: string
    onconfirm: (password: string) => Promise<void>
    onclose: () => void
  }

  const { open, message, onconfirm, onclose }: Props = $props()

  let password = $state('')
  let busy = $state(false)
  let error = $state<string | null>(null)

  // A fresh field each time it opens: a password kept from the last change
  // would be a password sitting in memory for no reason.
  $effect(() => {
    if (open) {
      password = ''
      error = null
    }
  })

  async function submit(event: SubmitEvent) {
    event.preventDefault()
    if (!password || busy) return
    busy = true
    error = null
    try {
      await onconfirm(password)
      password = ''
      onclose()
    } catch (e) {
      error = accessMessage(e, $LL)
    } finally {
      busy = false
    }
  }
</script>

<Modal {open} title={$LL.reauthTitle()} {onclose}>
  <form class="space-y-4" onsubmit={submit}>
    {#if message}
      <p class="text-sm text-fg">{message}</p>
    {/if}
    <p class="text-sm text-muted-fg">{$LL.reauthBody()}</p>
    <div class="space-y-1">
      <span class="text-sm text-muted-fg">{$LL.currentPassword()}</span>
      <Input type="password" autocomplete="current-password" bind:value={password} />
    </div>
    {#if error}
      <p class="text-sm text-danger">{error}</p>
    {/if}
    <div class="flex justify-end gap-2">
      <Button variant="ghost" type="button" onclick={onclose}>{$LL.cancel()}</Button>
      <Button type="submit" disabled={!password || busy}>
        {#if busy}<Spinner class="w-4 h-4" />{/if}
        {$LL.confirm()}
      </Button>
    </div>
  </form>
</Modal>
