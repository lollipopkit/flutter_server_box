<script lang="ts">
  /// The agent's account: its password, and signing out of this browser.

  import { Button, Group, Row } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import MyAccount from './MyAccount.svelte'
  import SettingsPage from './SettingsPage.svelte'
</script>

<SettingsPage title={$LL.settingsAccount()}>
  {#if !servers.authenticated}
    <p class="text-[13px] text-(--text-secondary)">{$LL.settingsNeedsAuth()}</p>
  {:else}
    <MyAccount />
    <Group>
      <Row label={$LL.logout()} sub={$LL.settingsLogoutHint()}>
        <Button size="sm" variant="destructive" onclick={() => servers.logout(servers.currentId)}>{$LL.logout()}</Button>
      </Row>
    </Group>
  {/if}
</SettingsPage>
