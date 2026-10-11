<script lang="ts">
  /// One change to the shares, asked about: what it does and sudo's password
  /// when the agent's account needs one. [run] makes it; a refusal is said
  /// here and the dialog stays.

  import { Button, Dialog, Input } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { ApiError } from '../../../lib/api'

  interface Props {
    open: boolean
    title: string
    body: string
    run: (sudoPassword: string) => Promise<void>
    onclose: () => void
  }

  const { open, title, body, run, onclose }: Props = $props()

  let password = $state('')
  let error = $state('')
  let busy = $state(false)

  $effect(() => {
    if (open) {
      error = ''
      busy = false
    }
  })

  function said(e: unknown): string {
    const b = e instanceof ApiError ? (e.body as { error?: string; path?: string; detail?: string } | undefined) : undefined
    switch (b?.error) {
      case 'sudo_rejected':
        return $LL.storageSudoRejected()
      case 'sudo_unavailable':
        return $LL.storageSudoUnavailable()
      case 'notAFolder':
        return $LL.sharingNotAFolder({ path: b.path ?? '' })
      case 'refused':
        return $LL.sharingRefused({ detail: b.detail ?? '' })
      case 'duplicate':
        return $LL.sharingDuplicate()
      case 'invalidName':
        return $LL.sharingInvalidName()
      case 'invalidPath':
        return $LL.sharingInvalidPath()
      case 'invalidClient':
        return $LL.sharingInvalidClient()
      case 'invalidPassword':
        return $LL.sharingInvalidPassword()
      case 'busy':
        return $LL.storageBusy()
      default:
        return b?.detail || (e instanceof Error ? e.message : String(e))
    }
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
    <Input label={$LL.storageSudoPassword()} type="password" value={password} oninput={(e: Event) => (password = (e.currentTarget as HTMLInputElement).value)} />
    {#if error}<p class="text-(--color-danger)">{error}</p>{/if}
  </div>
  {#snippet actions()}
    <Button block disabled={busy} onclick={() => void go()}>{title}</Button>
    <Button variant="secondary" block onclick={onclose}>{$LL.cancel()}</Button>
  {/snippet}
</Dialog>
