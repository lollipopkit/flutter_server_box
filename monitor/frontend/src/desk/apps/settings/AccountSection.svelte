<script lang="ts">
  /// The account this session signed in as: who it is, its role, its own
  /// password — the one thing an account that is not an administrator may
  /// change — and signing out of this browser.

  import { Button, Group, Row } from '@lollipopkit/desk-ui'
  import { LL } from '../../../i18n/i18n-svelte'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { displayName, servers } from '../../../lib/servers.svelte'
  import { serverNames } from '../../../lib/serverNames.svelte'
  import MyAccount from './MyAccount.svelte'
  import SettingsPage from './SettingsPage.svelte'

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  const server = $derived(serverNames.byServer[servers.currentId] ?? (servers.current ? displayName(servers.current) : ''))
</script>

<SettingsPage
  title={$LL.settingsAccount()}
  description={caps?.me ? $LL.settingsAccountDesc({ user: caps.me.username, server }) : undefined}
>
  {#if !servers.authenticated}
    <p class="text-[13px] text-(--text-secondary)">{$LL.settingsNeedsAuth()}</p>
  {:else}
    <!-- An agent with no `me` (a watch token, or one from before roles) has
         no account to show; the server section is what it answers to. -->
    {#if caps?.me}<MyAccount me={caps.me} />{/if}
    <Group>
      <Row label={$LL.logout()} sub={$LL.settingsLogoutHint()}>
        <Button size="sm" variant="destructive" onclick={() => servers.logout(servers.currentId)}>{$LL.logout()}</Button>
      </Row>
    </Group>
  {/if}
</SettingsPage>
