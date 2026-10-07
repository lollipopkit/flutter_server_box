<script lang="ts">
  import { ChevronLeft, ChevronRight } from '@lucide/svelte'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { monthGrid } from '../calendar'
  import PanelHead from './PanelHead.svelte'

  const today = new Date()
  let shown = $state(new Date(today.getFullYear(), today.getMonth(), 1))
  const weeks = $derived(monthGrid(shown.getFullYear(), shown.getMonth()))
  const title = $derived(new Intl.DateTimeFormat($locale, { year: 'numeric', month: 'long' }).format(shown))
  const todayLabel = $derived(
    new Intl.DateTimeFormat($locale, { weekday: 'long', month: 'long', day: 'numeric' }).format(today),
  )
  const weekdays = $derived(
    // 2023-01-02 was a Monday.
    Array.from({ length: 7 }, (_, i) =>
      new Intl.DateTimeFormat($locale, { weekday: 'narrow' }).format(new Date(2023, 0, 2 + i)),
    ),
  )

  function step(months: number) {
    shown = new Date(shown.getFullYear(), shown.getMonth() + months, 1)
  }

  function isToday(d: Date) {
    return d.toDateString() === today.toDateString()
  }
</script>

<PanelHead eyebrow={$LL.deskCalendar()} {title} subtitle={todayLabel}>
  {#snippet aside()}
    <div class="flex gap-1">
      <button class="desk-card grid h-7 w-7 place-items-center" aria-label={$LL.deskPrevious()} onclick={() => step(-1)}>
        <ChevronLeft class="h-4 w-4" />
      </button>
      <button class="desk-card grid h-7 w-7 place-items-center" aria-label={$LL.deskNext()} onclick={() => step(1)}>
        <ChevronRight class="h-4 w-4" />
      </button>
    </div>
  {/snippet}
</PanelHead>

<div class="grid grid-cols-7 gap-1.5 text-center text-[0.8rem]">
  {#each weekdays as d, i (i)}
    <span class="desk-muted pb-0.5 text-xs font-semibold">{d}</span>
  {/each}
  {#each weeks.flat() as day (day.date.toISOString())}
    <span
      class="grid h-10 place-items-center rounded-[0.6rem] border font-semibold tabular-nums"
      class:day-out={!day.inMonth}
      class:border-line={!isToday(day.date)}
      class:desk-chosen={isToday(day.date)}
      class:border-transparent={isToday(day.date)}
      aria-current={isToday(day.date) ? 'date' : undefined}
    >
      {day.date.getDate()}
    </span>
  {/each}
</div>

<style>
  .day-out {
    background: hsl(var(--ink) / 0.06);
    color: hsl(var(--ink) / 0.4);
  }
</style>
