<script lang="ts">
  import { LL } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import AppIcon from '../lk/AppIcon.svelte'
  import Notification from '../lk/Notification.svelte'

  const desk = useDesk()
  const banner = $derived(desk.notifications?.banner ?? null)
</script>

{#if banner}
  {#key banner.id}
    <div class="absolute right-[9px] top-[39px] z-[100002] max-w-[calc(100%-18px)]">
      <Notification
        app={$LL.deskAppStatus()}
        time={$LL.deskNow()}
        title={banner.subject}
        closeLabel={$LL.deskClose()}
        onclose={() => desk.notifications?.dismissBanner()}
        onclick={() => {
          desk.notifications?.dismissBanner()
          desk.togglePanel('notifications')
        }}
      >
        {#snippet icon()}<AppIcon glyph="monitoring" tone="berry" size={34} />{/snippet}
        {banner.body}
      </Notification>
    </div>
  {/key}
{/if}
