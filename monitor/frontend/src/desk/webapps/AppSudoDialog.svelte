<script lang="ts">
  /// The desk's own dialog before an installed app runs something as root:
  /// which app asks, what it says it does (its words, plain text), the name
  /// typed back for one that loses data, and sudo's password, which goes to
  /// the agent with that call or job and never to the app. A password the
  /// agent remembers may be left empty. [run] makes the request; sudo's
  /// refusal is said here and the dialog stays.

  import { Button, Checkbox, Dialog, Input } from '../lk'
  import { ApiError } from '../../lib/api'
  import { errorText } from '../../lib/errorText'
  import { LL } from '../../i18n/i18n-svelte'
  import type { SudoAsk } from '../../../../sdk/serverbox-desk/src/protocol'
  import type { SudoGiven } from './bridge.svelte'

  interface Props {
    /// The app's name as the desk shows it.
    app: string
    ask: SudoAsk | null
    remembered: boolean
    run: (given: SudoGiven) => Promise<void>
    onclose: () => void
  }

  const { app, ask, remembered, run, onclose }: Props = $props()

  let typed = $state('')
  let password = $state('')
  let remember = $state(false)
  let error = $state('')
  let busy = $state(false)

  $effect(() => {
    if (ask) {
      typed = ''
      password = ''
      // Never carried over: each dialog asks anew whether to keep the password.
      remember = false
      error = ''
      busy = false
    }
  })

  const ready = $derived(!busy && (!ask?.confirmWord || typed.trim() === ask.confirmWord))

  async function go() {
    busy = true
    error = ''
    try {
      await run({ password, remember })
    } catch (e) {
      const code = e instanceof ApiError ? e.code ?? (e.body?.error as string | undefined) : undefined
      error = code === 'sudo_rejected' ? $LL.storageSudoRejected() : code === 'sudo_unavailable' ? $LL.storageSudoUnavailable() : errorText(e)
      busy = false
    }
  }
</script>

<Dialog open={ask !== null} title={ask?.title ?? ''} {onclose}>
  <div class="space-y-[11px] text-left text-[13px] text-(--text-secondary)">
    <p class="font-medium text-(--text-primary)">{$LL.deskAppSudoAsks({ app })}</p>
    <p class="whitespace-pre-line">{ask?.body}</p>
    {#if ask?.confirmWord}
      <Input label={$LL.storageTypeToConfirm({ word: ask.confirmWord })} mono value={typed} oninput={(e: Event) => (typed = (e.currentTarget as HTMLInputElement).value)} />
    {/if}
    <Input
      label={$LL.storageSudoPassword()}
      type="password"
      hint={remembered ? $LL.deskAppSudoRemembered() : undefined}
      value={password}
      oninput={(e: Event) => (password = (e.currentTarget as HTMLInputElement).value)}
    />
    {#if password}<Checkbox bind:checked={remember} label={$LL.deskAppSudoRemember()} />{/if}
    {#if error}<p class="text-(--color-danger)">{error}</p>{/if}
  </div>
  {#snippet actions()}
    <Button variant={ask?.confirmWord ? 'destructive' : 'primary'} block disabled={!ready} onclick={() => void go()}>{ask?.title ?? ''}</Button>
    <Button variant="secondary" block onclick={onclose}>{$LL.cancel()}</Button>
  {/snippet}
</Dialog>
