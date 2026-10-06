<script lang="ts">
  import { CircleAlert, Info, TriangleAlert } from '@lucide/svelte'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { useDesk } from '../deskState.svelte'
  import type { DeskNotification } from '../deskApi'

  const desk = useDesk()
  const list = $derived(desk.notifications?.list ?? [])

  $effect(() => {
    void desk.notifications?.load()
  })

  function when(n: DeskNotification) {
    return new Intl.DateTimeFormat($locale, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(
      new Date(n.created_at),
    )
  }

  const ICON = { info: Info, warning: TriangleAlert, critical: CircleAlert }
  const TONE = { info: 'text-accent', warning: 'text-warning', critical: 'text-danger' }
</script>

<div class="flex max-h-[min(32rem,calc(100dvh-8rem))] flex-col">
  <header class="flex items-center justify-between px-3 pb-1 pt-3">
    <h3 class="text-sm font-semibold">{$LL.deskNotifications()}</h3>
    {#if (desk.notifications?.unread ?? 0) > 0}
      <button class="desk-hover px-1.5 py-0.5 text-xs" onclick={() => desk.notifications?.markAllRead()}>
        {$LL.deskMarkAllRead()}
      </button>
    {/if}
  </header>
  <div class="space-y-1.5 overflow-y-auto p-2">
    {#each list as n (n.id)}
      {@const Icon = ICON[n.level] ?? Info}
      <button
        class="desk-hover flex w-full gap-2.5 rounded-xl p-2.5 text-left"
        style:background="hsl(var(--ink) / {n.read ? 0.03 : 0.08})"
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
        {#if !n.read}<span class="mt-1.5 h-2 w-2 shrink-0 rounded-full" style:background="var(--desk-accent)"></span>{/if}
      </button>
    {:else}
      <p class="desk-muted px-2 py-8 text-center text-xs">{$LL.deskNoNotifications()}</p>
    {/each}
  </div>
</div>
