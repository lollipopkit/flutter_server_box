<script lang="ts">
  /// One change to the disks, asked about: what it does, for one that loses
  /// data the name typed back, and sudo's password when the agent's account
  /// needs one. Starting it hands the job to the page. Or a SMART reading
  /// (`readHealth`), which needs root as well, handed back when made.

  import { Button, Dialog, Input } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import type { HealthReading, StackJob, StorageAction } from '../../../types'

  interface Props {
    action: StorageAction | 'readHealth' | null
    title: string
    /// What it does, said plainly.
    body: string
    /// Typed back before a change that loses data; none for the others.
    confirmWord?: string
    /// A LUKS passphrase the change needs, asked before.
    passphrase?: string
    onstarted: (job: StackJob) => void
    onhealth: (reading: HealthReading) => void
    onclose: () => void
  }

  const { action, title, body, confirmWord, passphrase: luks, onstarted, onhealth, onclose }: Props = $props()

  let typed = $state('')
  let password = $state('')
  let error = $state('')
  let busy = $state(false)

  $effect(() => {
    if (action) {
      typed = ''
      error = ''
      busy = false
    }
  })

  const ready = $derived(!busy && (!confirmWord || typed.trim() === confirmWord))

  async function start() {
    if (!action) return
    busy = true
    error = ''
    try {
      if (action === 'readHealth') onhealth(await api.storageHealth(password))
      else onstarted(luks ? await api.storageAct(action, password, luks) : await api.storageAct(action, password))
    } catch (e) {
      const body = e instanceof ApiError ? (e.body as { error?: string; device?: string; why?: string } | undefined) : undefined
      switch (body?.error) {
        case 'sudo_rejected':
          error = $LL.storageSudoRejected()
          break
        case 'sudo_unavailable':
          error = $LL.storageSudoUnavailable()
          break
        case 'inUse':
          error = $LL.storageInUse({ device: body.device ?? '' })
          break
        case 'busy':
          error = $LL.storageBusy()
          break
        case 'systemMount':
          error = $LL.storageSystemMount()
          break
        case 'notMounted':
          error = $LL.storageNotMounted()
          break
        case 'invalidPassphrase':
          error = $LL.storageInvalidPassphrase()
          break
        case 'mounted':
          error = $LL.storageMountedInside()
          break
        case 'notRemovable':
          error = $LL.storageNotRemovable()
          break
        default:
          error = e instanceof Error ? e.message : String(e)
      }
      busy = false
    }
  }
</script>

<Dialog open={!!action} {title} {onclose}>
  <div class="space-y-[11px] text-left text-[13px] text-(--text-secondary)">
    <p>{body}</p>
    {#if confirmWord}
      <Input label={$LL.storageTypeToConfirm({ word: confirmWord })} mono value={typed} oninput={(e: Event) => (typed = (e.currentTarget as HTMLInputElement).value)} />
    {/if}
    <Input
      label={$LL.storageSudoPassword()}
      type="password"
      value={password}
      oninput={(e: Event) => (password = (e.currentTarget as HTMLInputElement).value)}
    />
    {#if error}<p class="text-(--color-danger)">{error}</p>{/if}
  </div>
  {#snippet actions()}
    <Button variant={confirmWord ? 'destructive' : 'primary'} block disabled={!ready} onclick={() => void start()}>{title}</Button>
    <Button variant="secondary" block onclick={onclose}>{$LL.cancel()}</Button>
  {/snippet}
</Dialog>
