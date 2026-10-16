/// Moves `id` one place among the cards currently shown, in a full order that
/// also holds hidden ones: it trades places with the next shown card in that
/// direction, so hidden cards keep their slots. The keyboard counterpart of
/// dragging a card onto its neighbour. Unchanged when there is no neighbour.
export function moveAmongVisible<T>(order: readonly T[], visible: readonly T[], id: T, delta: -1 | 1): T[] {
  const at = visible.indexOf(id)
  const neighbour = visible[at + delta]
  const next = [...order]
  if (at === -1 || neighbour === undefined) return next
  const a = next.indexOf(id)
  const b = next.indexOf(neighbour)
  if (a === -1 || b === -1) return next
  next[a] = neighbour
  next[b] = id
  return next
}
