/// Window geometry on the desk, in CSS pixels: pure functions, so the window
/// manager and its tests share one answer to "where may a window be".

export interface Rect {
  x: number
  y: number
  width: number
  height: number
}

export interface Size {
  width: number
  height: number
}

/// The area windows live in: below the menubar, above the dock.
export interface Area {
  width: number
  height: number
  top: number
  bottom: number
}

/// Edges a resize handle moves.
export type Edge = 'n' | 's' | 'e' | 'w' | 'ne' | 'nw' | 'se' | 'sw'

/// Where a dragged window lands when let go there: half the area, or all of it.
export type SnapZone = 'left' | 'right' | 'max'

/// How much of a window must stay on the area so its title bar can be taken.
export const KEEP_VISIBLE = 64
/// Below this width the desk shows one window at a time, full screen.
export const COMPACT_WIDTH = 860
/// How near an edge the pointer must be for a drag to snap there.
export const SNAP_EDGE = 6

export function usable(area: Area): Rect {
  return {
    x: 0,
    y: area.top,
    width: area.width,
    height: Math.max(0, area.height - area.top - area.bottom),
  }
}

/// [rect] made to fit [area]: no smaller than [min], no larger than the area,
/// and with enough of it on the area to be taken by its title bar.
export function clamp(rect: Rect, area: Area, min: Size): Rect {
  const space = usable(area)
  const width = Math.round(Math.min(Math.max(rect.width, min.width), space.width))
  const height = Math.round(Math.min(Math.max(rect.height, min.height), space.height))
  const x = Math.round(Math.min(Math.max(rect.x, KEEP_VISIBLE - width), space.width - KEEP_VISIBLE))
  // The title bar never goes under the menubar or below the area.
  const y = Math.round(Math.min(Math.max(rect.y, space.y), space.y + space.height - KEEP_VISIBLE / 2))
  return { x, y, width, height }
}

/// Where a new window of [size] opens: centred, stepped down and right for
/// each window already open, so none hides another's title bar exactly.
export function cascade(open: number, size: Size, area: Area): Rect {
  const space = usable(area)
  const width = Math.min(size.width, space.width)
  const height = Math.min(size.height, space.height)
  const step = 28 * (open % 8)
  return {
    x: Math.round(space.x + (space.width - width) / 2 + step),
    y: Math.round(space.y + Math.max(0, (space.height - height) / 3) + step),
    width,
    height,
  }
}

/// The rect a window covers when snapped to [zone].
/// The gap a snapped or maximised window keeps from the screen's sides and
/// from its neighbour (the design system's 7px inset).
export const SNAP_GUTTER = 7

export function snapRect(zone: SnapZone, area: Area): Rect {
  const space = usable(area)
  const g = SNAP_GUTTER
  if (zone === 'max') return { x: g, y: space.y, width: space.width - 2 * g, height: space.height }
  const half = Math.round(space.width / 2)
  return zone === 'left'
    ? { x: g, y: space.y, width: half - g - Math.floor(g / 2), height: space.height }
    : { x: half + Math.ceil(g / 2), y: space.y, width: space.width - half - g - Math.ceil(g / 2), height: space.height }
}

/// The zone a drag let go at ([x], [y], the pointer) snaps to, if any: the
/// top edge maximises, a side edge takes that half.
export function snapZoneAt(x: number, y: number, area: Area): SnapZone | null {
  if (y <= area.top + SNAP_EDGE) return 'max'
  if (x <= SNAP_EDGE) return 'left'
  if (x >= area.width - SNAP_EDGE) return 'right'
  return null
}

/// [start] resized by dragging [edge] by ([dx], [dy]), never below [min]: the
/// opposite edge stays where it was.
export function resize(start: Rect, edge: Edge, dx: number, dy: number, min: Size): Rect {
  let { x, y, width, height } = start
  if (edge.includes('e')) width = Math.max(min.width, start.width + dx)
  if (edge.includes('s')) height = Math.max(min.height, start.height + dy)
  if (edge.includes('w')) {
    width = Math.max(min.width, start.width - dx)
    x = start.x + start.width - width
  }
  if (edge.includes('n')) {
    height = Math.max(min.height, start.height - dy)
    y = start.y + start.height - height
  }
  return { x, y, width, height }
}

/// Where a window restored from a snap goes while being dragged: its old size,
/// under the pointer at the same fraction of its width it was taken at.
export function unsnapUnder(pointerX: number, pointerY: number, snapped: Rect, restore: Size): Rect {
  const fraction = snapped.width > 0 ? (pointerX - snapped.x) / snapped.width : 0.5
  return {
    x: Math.round(pointerX - restore.width * fraction),
    y: Math.round(pointerY - 16),
    width: restore.width,
    height: restore.height,
  }
}
