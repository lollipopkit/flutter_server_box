<script lang="ts">
  /// One change made as root, asked about: what it does, for one that loses
  /// data the name typed back, and sudo's password for the agent's account.
  /// [run] makes it; a refusal is said here and the dialog stays. sudo's own
  /// refusals and a job already running are said the same way everywhere;
  /// [refusal] words the page's own codes.

  import { Button, Dialog, Input } from '../desk/lk'
  import { ApiError } from '../lib/api'
  import { errorText } from '../lib/errorText'
  import { LL } from '../i18n/i18n-svelte'

  interface Props {
    open: boolean
    title: string
    /// What it does, said plainly.
    body: string
    /// Typed back before a change that loses data; none for the others.
    confirmWord?: string
    run: (sudoPassword: string) => Promise<void>
    /// The words for a refusal the page knows ([body] is the agent's JSON),
    /// or undefined for the shared ones.
    refusal?: (body: Record<string, unknown> & { error?: string }) => string | undefined
    onclose: () => void
  }

  const { open, title, body, confirmWord, run, refusal, onclose }: Props = $props()

  let typed = $state('')
  let password = $state('')
  let error = $state('')
  let busy = $state(false)

  $effect(() => {
    if (open) {
      typed = ''
      error = ''
      busy = false
    }
  })

  const ready = $derived(!busy && (!confirmWord || typed.trim() === confirmWord))

  function said(e: unknown): string {
    const answer = e instanceof ApiError ? (e.body as (Record<string, unknown> & { error?: string; detail?: string }) | undefined) : undefined
    if (answer) {
      const own = refusal?.(answer)
      if (own) return own
      switch (answer.error) {
        case 'sudo_rejected':
          return $LL.storageSudoRejected()
        case 'sudo_unavailable':
          return $LL.storageSudoUnavailable()
        case 'busy':
          return $LL.storageBusy()
      }
      if (typeof answer.detail === 'string' && answer.detail) return answer.detail
    }
    return errorText(e)
  }

  async function go() {
    busy = true
    error = ''
    try {
      await run(password)
    } catch (e) {
      error = said(e)
      busy = false
    }
  }
</script>

<Dialog {open} {title} {onclose}>
  <div class="space-y-[11px] text-left text-[13px] text-(--text-secondary)">
    <p>{body}</p>
    {#if confirmWord}
      <Input label={$LL.storageTypeToConfirm({ word: confirmWord })} mono value={typed} oninput={(e: Event) => (typed = (e.currentTarget as HTMLInputElement).value)} />
    {/if}
    <Input label={$LL.storageSudoPassword()} type="password" value={password} oninput={(e: Event) => (password = (e.currentTarget as HTMLInputElement).value)} />
    {#if error}<p class="text-(--color-danger)">{error}</p>{/if}
  </div>
  {#snippet actions()}
    <Button variant={confirmWord ? 'destructive' : 'primary'} block disabled={!ready} onclick={() => void go()}>{title}</Button>
    <Button variant="secondary" block onclick={onclose}>{$LL.cancel()}</Button>
  {/snippet}
</Dialog>
