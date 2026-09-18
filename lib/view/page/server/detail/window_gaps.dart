/// One stretch of a chart's window that no sample falls in.
///
/// [leading] says which end it is against, which is what decides where the
/// hairline goes: a gap at the start of the window has the data on its right.
typedef WindowGap = ({int from, int to, bool leading});

/// The stretches of `from`..`to` that the samples do not cover.
///
/// The window a chart draws is the one that was *asked for*, so the samples do
/// not have to reach its ends — and where they stop is the thing worth seeing.
/// Taking the axis from the samples instead makes every window look full:
/// three stored hours drawn on a 24-hour request fill the card, and a page
/// left in the background for four minutes draws a line straight across the
/// gap.
///
/// Both tolerances exist because neither end is exact. A stored window comes
/// back bucketed, so its first and last points sit up to a bucket inside the
/// window whatever the agent kept; the live window ends whenever the last poll
/// landed, which is always a little before now. A band drawn for those is a
/// band on every chart, and a band on every chart is furniture.
///
/// [first] and [last] are the instants of the oldest and newest sample. A
/// window with no samples at all has no gaps *in* it — there is nothing to
/// place them against — and the card says so in words instead.
List<WindowGap> windowGaps({
  required int from,
  required int to,
  required int first,
  required int last,
  required int leadTolerance,
  required int trailTolerance,
}) {
  if (to <= from || last < first) return const [];
  return [
    if (first - from > leadTolerance)
      (from: from, to: first.clamp(from, to), leading: true),
    if (to - last > trailTolerance)
      (from: last.clamp(from, to), to: to, leading: false),
  ];
}
