<script lang="ts">
  /// The account this session signed in as: who it is, its role, and its own
  /// password — the one thing an account that is not an administrator may
  /// change.

  import { LL } from '../../../i18n/i18n-svelte'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import MyAccount from './MyAccount.svelte'

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
</script>

<AppToolbar title={$LL.settingsAccount()} />

<main class="mx-auto max-w-3xl space-y-4 px-4 py-4 @3xl:px-6">
  {#if !servers.authenticated}
    <p class="text-sm text-muted-fg">{$LL.settingsNeedsAuth()}</p>
  {:else if caps?.me}
    <MyAccount me={caps.me} />
  {/if}
  <!-- An agent with no `me` (a watch token, or one from before roles) has no
       account to show; the server section is what it answers to. -->
</main>
