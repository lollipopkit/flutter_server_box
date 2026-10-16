<script lang="ts">
  /// Where web apps are installed from: the App Store, on an agent that
  /// deploys them.

  import { AppIcon, Group, Row } from '../../lk'
  import { useWindow } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'

  const win = useWindow()
  const offered = $derived(capabilitiesStore.byServer[servers.currentId]?.features?.includes('stacks') === true)
</script>

{#if offered}
  <Group>
    <Row label={$LL.storeTitle()} sub={$LL.storeLinkSub()} onclick={() => win.open('serverbox.store')}>
      {#snippet leading()}<AppIcon glyph="storefront" tone="berry" size={26} />{/snippet}
    </Row>
  </Group>
{/if}
