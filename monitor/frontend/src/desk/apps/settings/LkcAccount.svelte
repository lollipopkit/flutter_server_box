<script lang="ts">
  /// The LK Cloud account the agent is signed in to: signed in with a
  /// device code the person approves in any browser, while the agent polls.

  import { onDestroy } from 'svelte'
  import { Button, Group, Row, Spinner } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { accessMessage } from '../../../lib/access'
  import { ApiError, api } from '../../../lib/api'
  import { useScope } from '../../../lib/scope.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import type { LkcState } from '../../../types'

  /// How often a waiting sign-in is asked after.
  const POLL_MS = 3000

  let info = $state<LkcState | null>(null)
  let busy = $state(false)
  let error = $state<string | null>(null)
  let timer: ReturnType<typeof setTimeout> | undefined
  const scope = useScope()

  const waiting = $derived(info?.sign_in != null && info.sign_in.failed == null)

  async function load() {
    const serverId = servers.currentId
    try {
      const next = await api.getLkc()
      if (scope.stale(serverId)) return
      info = next
      error = null
    } catch (e) {
      if (scope.stale(serverId)) return
      error = message(e)
    }
    clearTimeout(timer)
    if (waiting) timer = setTimeout(load, POLL_MS)
  }

  $effect(() => {
    void servers.currentId
    info = null
    void load()
  })
  onDestroy(() => clearTimeout(timer))

  async function act(run: () => Promise<unknown>) {
    busy = true
    let failed: string | null = null
    try {
      await run()
    } catch (e) {
      failed = message(e)
    }
    await load()
    busy = false
    if (failed) error = failed
  }

  function message(e: unknown): string {
    if (e instanceof ApiError && e.code === 'lkc_unreachable') return $LL.lkcUnreachable()
    if (e instanceof ApiError && e.code === 'lkc_refused') return $LL.lkcFailed()
    // Another sign-in was approved and is being stored.
    if (e instanceof ApiError && e.code === 'lkc_finishing') return $LL.lkcWaiting()
    return accessMessage(e, $LL)
  }

  function open(url: string) {
    window.open(url, '_blank', 'noopener,noreferrer')
  }

  function failedText(failed: NonNullable<NonNullable<LkcState['sign_in']>['failed']>): string {
    switch (failed) {
      case 'denied':
        return $LL.lkcDenied()
      case 'expired':
        return $LL.lkcExpired()
      default:
        return $LL.lkcFailed()
    }
  }
</script>

<Group title={$LL.lkc()}>
  {#if info == null}
    <Row label={$LL.lkc()} sub={error ?? undefined}>
      {#if !error}<Spinner size={16} />{/if}
    </Row>
  {:else if info.user}
    <Row label={info.user.name || info.user.id}>
      <Button size="sm" variant="secondary" disabled={busy} onclick={() => act(api.signOutLkc)}>
        {#if busy}<Spinner size={16} />{/if}
        {$LL.lkcSignOut()}
      </Button>
    </Row>
  {:else if waiting && info.sign_in}
    {@const signIn = info.sign_in}
    <Row label={$LL.lkcCode()} sub={$LL.lkcCodeHint()} value={signIn.user_code} mono />
    <Row label={$LL.lkcWaiting()} sub={error ?? undefined}>
      <div class="flex gap-2">
        <Button size="sm" variant="secondary" onclick={() => open(signIn.verification_uri_complete ?? signIn.verification_uri)}>
          {$LL.lkcOpen()}
        </Button>
        <Button size="sm" variant="secondary" disabled={busy} onclick={() => act(api.cancelLkcSignIn)}>
          {$LL.cancel()}
        </Button>
      </div>
    </Row>
  {:else}
    <Row
      label={$LL.lkcSignIn()}
      sub={error ?? (info.sign_in?.failed ? failedText(info.sign_in.failed) : $LL.lkcHint())}
    >
      <Button size="sm" variant="secondary" disabled={busy} onclick={() => act(api.startLkcSignIn)}>
        {#if busy}<Spinner size={16} />{/if}
        {$LL.lkcSignIn()}
      </Button>
    </Row>
  {/if}
</Group>
