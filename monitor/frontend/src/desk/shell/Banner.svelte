<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import AppIcon from '../lk/AppIcon.svelte'
  import Button from '../lk/Button.svelte'
  import Notification from '../lk/Notification.svelte'
  import { panelBuild } from '../../lib/panelBuild.svelte'
  import { noticeText } from '../noticeText'

  const desk = useDesk()
  $effect(() => panelBuild.watch())
  let updateDismissed = $state(false)
  const banner = $derived(desk.notifications?.banner ?? null)
  const from = $derived(banner ? desk.noticeSource(banner) : null)
  const text = $derived(banner ? noticeText(banner, $LL, $locale) : null)
</script>

<div class="absolute right-[9px] top-[39px] z-[100002] flex max-w-[calc(100%-18px)] flex-col gap-[9px]">
{#if panelBuild.stale && !updateDismissed}
  <Notification
    app="ServerBox"
    time={$LL.deskNow()}
    title={$LL.deskPanelUpdated()}
    closeLabel={$LL.deskClose()}
    onclose={() => (updateDismissed = true)}
  >
    {#snippet icon()}<AppIcon glyph="system_update" tone="sky" size={34} />{/snippet}
    {#snippet actions()}
      <Button size="sm" icon="refresh" onclick={() => window.location.reload()}>{$LL.deskReload()}</Button>
    {/snippet}
    {$LL.deskPanelUpdatedBody()}
  </Notification>
{/if}
{#if banner}
  {#key banner.id}
    <div>
      <Notification
        app={from?.title ?? ''}
        time={$LL.deskNow()}
        title={text?.subject ?? banner.subject}
        closeLabel={$LL.deskClose()}
        onclose={() => desk.notifications?.dismissBanner()}
        onclick={() => {
          desk.notifications?.dismissBanner()
          desk.openNotice(banner)
        }}
      >
        {#snippet icon()}<AppIcon glyph={from?.glyph ?? 'info'} tone={from?.tone ?? 'sky'} size={34} />{/snippet}
        {text?.body ?? banner.body}
      </Notification>
    </div>
  {/key}
{/if}
</div>
