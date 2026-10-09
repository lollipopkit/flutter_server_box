<script lang="ts">
  /// Asks the administrator's own password before a change to who can do
  /// what: every such request carries it, so that a session left open is not
  /// enough to hand out a shell.
  ///
  /// One dialog for every change. [onconfirm] does the change with the
  /// password; a rejection keeps the dialog open with the reason, so a mistyped
  /// password is retyped rather than the change started over.

  import { Button, Dialog, Input, Spinner } from '../../lk'
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

<Dialog open={open} wide title={$LL.reauthTitle()} message={message} onclose={onclose}>
  <form id="reauth-form" class="space-y-[13px]" onsubmit={submit}>
    <p class="text-[13px] text-(--text-secondary)">{$LL.reauthBody()}</p>
    <Input label={$LL.currentPassword()} type="password" autocomplete="current-password" bind:value={password} />
    {#if error}<p class="text-[13px] text-(--color-danger)" role="alert">{error}</p>{/if}
  </form>
  {#snippet actions()}
    <Button variant="secondary" type="button" onclick={onclose}>{$LL.cancel()}</Button>
    <Button type="submit" form="reauth-form" disabled={!password || busy}>
      {#if busy}<Spinner size={16} />{/if}
      {$LL.confirm()}
    </Button>
  {/snippet}
</Dialog>
