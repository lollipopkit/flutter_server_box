<script lang="ts">
  /// The account this session signed in as: who it is, its role, and its own
  /// password — the one thing an account that is not an administrator may
  /// change.

  import { LL } from '../../../i18n/i18n-svelte'
  import { AppToolbar } from '../../sys'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import MyAccount from './MyAccount.svelte'

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
</script>

<AppToolbar title={$LL.settingsAccount()} />

<main class="flex max-w-[560px] flex-col gap-[17px] pb-[21px] pl-[17px] pr-[21px] pt-[5px]">
  {#if !servers.authenticated}
    <p class="text-[13px] text-(--text-secondary)">{$LL.settingsNeedsAuth()}</p>
  {:else if caps?.me}
    <MyAccount me={caps.me} />
  {/if}
  <!-- An agent with no `me` (a watch token, or one from before roles) has no
       account to show; the server section is what it answers to. -->
</main>
