<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import type { DeskNotification } from '../deskApi'
  import AppIcon from '../lk/AppIcon.svelte'
  import Button from '../lk/Button.svelte'
  import Icon from '../lk/Icon.svelte'
  import Notification from '../lk/Notification.svelte'

  const desk = useDesk()
  const list = $derived(desk.notifications?.list ?? [])
  const unread = $derived(desk.notifications?.unread ?? 0)

  $effect(() => {
    void desk.notifications?.load()
  })

  function when(n: DeskNotification) {
    return new Intl.DateTimeFormat($locale, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(
      new Date(n.created_at),
    )
  }
</script>

<div class="flex items-center justify-between px-[3px] pb-[9px]">
  <h2 class="lk-caps">{$LL.deskNotifications()}</h2>
  {#if unread > 0}
    <Button variant="ghost" size="sm" onclick={() => desk.notifications?.markAllRead()}>{$LL.deskMarkAllRead()}</Button>
  {/if}
</div>
<div class="flex flex-col gap-[9px]">
  {#each list as n (n.id)}
    {@const from = desk.noticeSource(n)}
    <Notification
      class="!w-full !animate-none {n.read ? 'opacity-70' : ''}"
      app={from.title}
      time={when(n)}
      title={n.subject}
      onclick={() => desk.openNotice(n)}
    >
      {#snippet icon()}<AppIcon glyph={from.glyph} tone={from.tone} size={34} />{/snippet}
      {n.body}
    </Notification>
  {:else}
    <div class="flex flex-col items-center gap-[9px] py-[27px] text-(--text-tertiary)">
      <Icon name="notifications" size={44} weight={300} />
      <span>{$LL.deskNoNotifications()}</span>
    </div>
  {/each}
</div>
