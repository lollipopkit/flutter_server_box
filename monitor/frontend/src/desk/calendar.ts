/// A month as the calendar draws it: whole weeks, Monday first, with the
/// neighbouring months' days filling the first and last week.

export interface Day {
  date: Date
  inMonth: boolean
}

export function monthGrid(year: number, month: number): Day[][] {
  const first = new Date(year, month, 1)
  // Monday = 0.
  const lead = (first.getDay() + 6) % 7
  const days = new Date(year, month + 1, 0).getDate()
  const cells = Math.ceil((lead + days) / 7) * 7
  const weeks: Day[][] = []
  for (let i = 0; i < cells; i++) {
    const date = new Date(year, month, 1 - lead + i)
    if (i % 7 === 0) weeks.push([])
    weeks[weeks.length - 1].push({ date, inMonth: date.getMonth() === month })
  }
  return weeks
}
