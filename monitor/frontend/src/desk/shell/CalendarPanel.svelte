<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { monthGrid } from '../calendar'
  import IconButton from '../lk/IconButton.svelte'

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

<div class="lk-ctile lk-ctile--col">
  <div class="flex items-center justify-between">
    <span class="text-[15px] font-semibold">{title}</span>
    <div class="flex">
      <IconButton icon="chevron_left" label={$LL.deskPrevious()} size="sm" onclick={() => step(-1)} />
      <IconButton icon="chevron_right" label={$LL.deskNext()} size="sm" onclick={() => step(1)} />
    </div>
  </div>
  <div class="grid grid-cols-7 gap-[3px] text-center text-[12px]">
    {#each weekdays as d, i (i)}
      <span class="lk-caps py-[3px]">{d}</span>
    {/each}
    {#each weeks.flat() as day (day.date.toISOString())}
      <span
        class="lk-num grid h-[30px] place-items-center rounded-full text-[13px]"
        class:out={!day.inMonth}
        class:today={isToday(day.date)}
        aria-current={isToday(day.date) ? 'date' : undefined}
      >
        {day.date.getDate()}
      </span>
    {/each}
  </div>
</div>

<style>
  .out {
    color: var(--text-disabled);
  }
  .today {
    background: var(--color-accent);
    color: var(--text-on-accent);
    font-weight: var(--weight-semibold);
  }
</style>
