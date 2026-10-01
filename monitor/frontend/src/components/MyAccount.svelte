<script lang="ts">
  /// The signed-in account on this agent: who it is, the role it holds, and
  /// its own password — the one thing an account that is not an
  /// administrator may change.

  import { Badge, Button, Card, Input, Spinner } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import { accessMessage } from '../lib/access'
  import { api } from '../lib/api'
  import type { Me } from '../types'

  interface Props {
    me: Me
  }

  const { me }: Props = $props()

  let current = $state('')
  let next = $state('')
  let busy = $state(false)
  let error = $state<string | null>(null)
  let done = $state(false)

  async function change(event: SubmitEvent) {
    event.preventDefault()
    done = false
    error = null
    // The agent's own rule; checked here as well so a short password is told
    // so before it travels.
    if (next.length < 8) {
      error = $LL.passwordTooShort()
      return
    }
    busy = true
    try {
      await api.changeMyPassword(current, next)
      current = ''
      next = ''
      done = true
    } catch (e) {
      error = accessMessage(e, $LL)
    } finally {
      busy = false
    }
  }
</script>

<Card class="space-y-4">
  <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.myAccount()}</h2>
  <div class="flex flex-wrap items-center gap-2 text-sm">
    <span class="font-mono">{me.username}</span>
    <span class="text-muted-fg">·</span>
    <span class="text-muted-fg">{$LL.accountRole()}</span>
    <Badge tone={me.admin ? 'success' : 'neutral'}>{me.role}</Badge>
  </div>
  <form class="space-y-3" onsubmit={change}>
    <h3 class="text-sm font-medium text-fg-strong">{$LL.changePassword()}</h3>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
      <div class="space-y-1">
        <span class="text-xs text-muted-fg">{$LL.currentPassword()}</span>
        <Input type="password" autocomplete="current-password" bind:value={current} />
      </div>
      <div class="space-y-1">
        <span class="text-xs text-muted-fg">{$LL.newPassword()}</span>
        <Input type="password" autocomplete="new-password" bind:value={next} />
      </div>
    </div>
    <Button size="sm" variant="secondary" type="submit" disabled={busy || !current || !next}>
      {#if busy}<Spinner class="w-4 h-4" />{/if}
      {$LL.changePassword()}
    </Button>
    {#if error}
      <p class="text-sm text-danger">{error}</p>
    {/if}
    {#if done}
      <p class="text-sm text-success">{$LL.passwordChanged()}</p>
    {/if}
  </form>
</Card>
