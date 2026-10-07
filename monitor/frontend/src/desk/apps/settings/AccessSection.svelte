<script lang="ts">
  /// Who can do what on this agent: the accounts and roles, managed here by
  /// an administrator only. Every change is re-authenticated.

  import { LL } from '../../../i18n/i18n-svelte'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import AccessAdmin from './AccessAdmin.svelte'

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  // Accounts and roles exist only on an agent that reports who is asking:
  // without `me` (a watch token, an agent from before roles) there is
  // nothing to manage here, whatever `isAdmin` assumes for other gates.
  const admin = $derived(caps?.me?.admin === true)

  /// A change to accounts or roles can change this session's own access, so
  /// what the agent says this session may do is asked again.
  function refreshAccess() {
    capabilitiesStore.clear(servers.currentId)
    void capabilitiesStore.ensure(servers.currentId)
  }
</script>

<!-- The sidebar offers this section only where it is allowed; the check is
     repeated here so a window restored with `access` shows nothing. -->
{#if admin}
  <AppToolbar title={$LL.settingsAccess()} />

  <main class="mx-auto max-w-[560px] space-y-[13px] px-[21px] pb-[21px] pt-[4px]">
    <AccessAdmin onchanged={refreshAccess} />
  </main>
{/if}
