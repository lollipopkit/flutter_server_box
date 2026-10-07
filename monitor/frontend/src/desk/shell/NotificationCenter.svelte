<script lang="ts">
  import { Bell, CircleAlert, Info, TriangleAlert } from '@lucide/svelte'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { displayName } from '../../lib/servers.svelte'
  import { useDesk } from '../deskState.svelte'
  import type { DeskNotification } from '../deskApi'
  import PanelHead from './PanelHead.svelte'

  const desk = useDesk()
  const list = $derived(desk.notifications?.list ?? [])
  const unread = $derived(desk.notifications?.unread ?? 0)
  const serverLabel = $derived(
    serverNames.byServer[desk.entry.id] ?? (desk.entry.id === 'local' ? $LL.thisServer() : displayName(desk.entry)),
  )

  $effect(() => {
    void desk.notifications?.load()
  })

  function when(n: DeskNotification) {
    return new Intl.DateTimeFormat($locale, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(
      new Date(n.created_at),
    )
  }

  const ICON = { info: Info, warning: TriangleAlert, critical: CircleAlert }
  const TONE = { info: 'text-primary', warning: 'text-warning', critical: 'text-danger' }
</script>

<PanelHead eyebrow={serverLabel} title={$LL.deskNotifications()}>
  {#snippet aside()}
    <span class="rounded-full bg-soft px-2.5 py-1 text-[0.7rem] font-bold text-muted-fg">
      {$LL.deskUnread({ count: unread })}
    </span>
  {/snippet}
</PanelHead>

{#if unread > 0}
  <button class="desk-hover -mt-1 mb-2 self-end px-1.5 py-0.5 text-xs font-medium" onclick={() => desk.notifications?.markAllRead()}>
    {$LL.deskMarkAllRead()}
  </button>
{/if}
<div class="space-y-2">
  {#each list as n (n.id)}
    {@const Icon = ICON[n.level] ?? Info}
    <button
      class="desk-card flex w-full gap-2.5 p-2.5 text-left"
      style:border-color={n.read ? undefined : 'color-mix(in srgb, var(--desk-accent) 52%, transparent)'}
      onclick={() => {
        void desk.notifications?.markRead(n.id)
        desk.open('status')
      }}
    >
      <Icon class="mt-0.5 h-4 w-4 shrink-0 {TONE[n.level] ?? ''}" />
      <span class="min-w-0 flex-1">
        <span class="flex items-baseline justify-between gap-2">
          <span class="truncate text-[0.8rem] font-semibold">{n.subject}</span>
          <span class="desk-muted shrink-0 text-[0.65rem]">{when(n)}</span>
        </span>
        <span class="desk-muted line-clamp-2 text-xs">{n.body}</span>
      </span>
    </button>
  {:else}
    <div class="rounded-[0.74rem] border border-dashed border-line px-4 py-4">
      <p class="flex items-center gap-2 font-semibold"><Bell class="h-4 w-4" />{$LL.deskNoNotifications()}</p>
      <p class="desk-muted mt-1.5 text-[0.8rem]">{$LL.deskNoNotificationsHint()}</p>
    </div>
  {/each}
</div>
