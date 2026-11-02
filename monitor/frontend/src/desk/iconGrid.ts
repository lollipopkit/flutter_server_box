/// Where the desk's icons go: a grid laid out from the top-right corner, down
/// each column then leftwards, as on a Mac. An icon with a cell keeps it;
/// the rest fill the free cells in order.

import type { DeskIcon } from './deskApi'

export const CELL = { width: 104, height: 100, margin: 12 }

export interface PlacedIcon {
  icon: DeskIcon
  x: number
  y: number
}

export function placeIcons(icons: DeskIcon[], area: { width: number; height: number }): PlacedIcon[] {
  const rows = Math.max(1, Math.floor((area.height - CELL.margin) / CELL.height))
  const cols = Math.max(1, Math.floor((area.width - CELL.margin) / CELL.width))
  const taken = new Set<string>()
  const cellOf = new Map<string, [number, number]>()
  // Cells asked for first, so a later icon cannot take one an earlier asked for.
  for (const icon of icons) {
    if (icon.col == null || icon.row == null) continue
    const col = Math.min(icon.col, cols - 1)
    const row = Math.min(icon.row, rows - 1)
    const key = `${col}:${row}`
    if (taken.has(key)) continue
    taken.add(key)
    cellOf.set(icon.id, [col, row])
  }
  let next = 0
  for (const icon of icons) {
    if (cellOf.has(icon.id)) continue
    while (taken.has(`${Math.floor(next / rows)}:${next % rows}`)) next++
    const cell: [number, number] = [Math.floor(next / rows), next % rows]
    taken.add(`${cell[0]}:${cell[1]}`)
    cellOf.set(icon.id, cell)
  }
  return icons.map((icon) => {
    const [col, row] = cellOf.get(icon.id)!
    return {
      icon,
      x: area.width - CELL.margin - (col + 1) * CELL.width,
      y: CELL.margin + row * CELL.height,
    }
  })
}
