<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import type { DeskNotification } from '../deskApi'
  import LkNotificationCenter, { type CenterNotice } from '../lk/NotificationCenter.svelte'

  const desk = useDesk()
  const list = $derived(desk.notifications?.list ?? [])
  const unread = $derived(desk.notifications?.unread ?? 0)

  $effect(() => {
    void desk.notifications?.load()
  })

  function when(n: DeskNotification) {
    const at = new Date(n.created_at)
    const today = new Date().toDateString() === at.toDateString()
    return new Intl.DateTimeFormat(
      $locale,
      today ? { hour: '2-digit', minute: '2-digit' } : { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' },
    ).format(at)
  }

  const notices = $derived(
    list.map((n): CenterNotice => {
      const from = desk.noticeSource(n)
      return {
        id: n.id,
        title: n.subject,
        text: n.body,
        time: when(n),
        glyph: from.glyph,
        tone: from.tone,
        read: n.read,
        onclick: () => {
          desk.panel = null
          desk.openNotice(n)
        },
      }
    }),
  )
</script>

<LkNotificationCenter
  title={$LL.deskNotifications()}
  {notices}
  dnd={desk.notifications?.dnd ?? false}
  ondnd={(on) => desk.notifications?.setDnd(on)}
  onclear={unread > 0 ? () => desk.notifications?.markAllRead() : undefined}
  dndLabel={$LL.deskDnd()}
  clearLabel={$LL.deskMarkAllRead()}
  emptyText={$LL.deskNoNotifications()}
  maxHeight="calc(100vh - 140px)"
/>
