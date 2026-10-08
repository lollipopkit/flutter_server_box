<script lang="ts">
  /// The signed-in account on this agent: who it is, the role it holds, and
  /// its own password — the one thing an account that is not an
  /// administrator may change.

  import { Badge, Button, Group, Input, Row, Spinner } from '@lollipopkit/desk-ui'
  import { LL } from '../../../i18n/i18n-svelte'
  import { accessMessage } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import type { Me } from '../../../types'

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

<Group title={$LL.settingsPersonal()}>
  <Row label={$LL.settingsUser()} value={me.username} mono />
  <Row label={$LL.accountRole()}>
    <Badge tone={me.admin ? 'success' : 'neutral'}>{me.role}</Badge>
  </Row>
</Group>

<form onsubmit={change}>
  <Group title={$LL.settingsSecurity()}>
    <Row label={$LL.currentPassword()} sub={$LL.settingsPasswordHint()}>
      <Input class="w-[200px]" type="password" autocomplete="current-password" bind:value={current} />
    </Row>
    <Row label={$LL.newPassword()}>
      <Input class="w-[200px]" type="password" autocomplete="new-password" bind:value={next} />
    </Row>
    <Row label={$LL.changePassword()} sub={error ?? (done ? $LL.passwordChanged() : undefined)}>
      <Button size="sm" variant="secondary" type="submit" disabled={busy || !current || !next}>
        {#if busy}<Spinner size={16} />{/if}
        {$LL.settingsChange()}
      </Button>
    </Row>
  </Group>
</form>
