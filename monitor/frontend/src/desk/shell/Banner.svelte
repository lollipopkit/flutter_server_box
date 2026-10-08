<script lang="ts">
  import { LL } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import AppIcon from '@lollipopkit/desk-ui/AppIcon.svelte'
  import Notification from '@lollipopkit/desk-ui/Notification.svelte'

  const desk = useDesk()
  const banner = $derived(desk.notifications?.banner ?? null)
  const from = $derived(banner ? desk.noticeSource(banner) : null)
</script>

{#if banner}
  {#key banner.id}
    <div class="absolute right-[9px] top-[39px] z-[100002] max-w-[calc(100%-18px)]">
      <Notification
        app={from?.title ?? ''}
        time={$LL.deskNow()}
        title={banner.subject}
        closeLabel={$LL.deskClose()}
        onclose={() => desk.notifications?.dismissBanner()}
        onclick={() => {
          desk.notifications?.dismissBanner()
          desk.openNotice(banner)
        }}
      >
        {#snippet icon()}<AppIcon glyph={from?.glyph ?? 'info'} tone={from?.tone ?? 'sky'} size={34} />{/snippet}
        {banner.body}
      </Notification>
    </div>
  {/key}
{/if}
