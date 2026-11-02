<script lang="ts">
  /// The agent's account: its password, changed only where the account may
  /// act over this link.

  import { Button, Group, Input, Row, Spinner } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { accessMessage, whyText } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
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

{#if caps?.access?.ok === false}
  <Group title={$LL.settingsSecurity()}>
    <p class="py-[9px] text-[13px] text-(--text-secondary)">{whyText(caps.access.why, $LL)}</p>
  </Group>
{:else}
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
{/if}
