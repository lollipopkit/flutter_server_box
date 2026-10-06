<script lang="ts">
  import { ChevronLeft, ChevronRight } from '@lucide/svelte'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { monthGrid } from '../calendar'

  const today = new Date()
  let shown = $state(new Date(today.getFullYear(), today.getMonth(), 1))
  const weeks = $derived(monthGrid(shown.getFullYear(), shown.getMonth()))
  const title = $derived(new Intl.DateTimeFormat($locale, { year: 'numeric', month: 'long' }).format(shown))
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

<div class="p-3">
  <div class="mb-2 flex items-center justify-between">
    <span class="text-sm font-semibold">{title}</span>
    <div class="flex">
      <button class="desk-hover grid h-6 w-6 place-items-center" aria-label={$LL.deskPrevious()} onclick={() => step(-1)}>
        <ChevronLeft class="h-4 w-4" />
      </button>
      <button class="desk-hover grid h-6 w-6 place-items-center" aria-label={$LL.deskNext()} onclick={() => step(1)}>
        <ChevronRight class="h-4 w-4" />
      </button>
    </div>
  </div>
  <div class="grid grid-cols-7 gap-0.5 text-center text-xs">
    {#each weekdays as d, i (i)}
      <span class="desk-muted py-1 font-semibold">{d}</span>
    {/each}
    {#each weeks.flat() as day (day.date.toISOString())}
      <span
        class="grid h-7 place-items-center rounded-full tabular-nums"
        class:opacity-35={!day.inMonth}
        class:desk-selected={isToday(day.date)}
      >
        {day.date.getDate()}
      </span>
    {/each}
  </div>
</div>
