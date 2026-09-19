import 'package:flutter/painting.dart';
import 'package:server_box/data/res/chart_series.dart';

/// The colours a reading is drawn in, wherever it is drawn.
///
/// Derived from the colour the user picked rather than fixed. The app's accent
/// is a setting, and a chart drawn in six hues chosen at build time was six
/// colours beside it that had nothing to do with it — the theme colour ended
/// up being the one colour on the page that no chart used. [SeriesPalette] is
/// the arithmetic; this is which reading gets which of its six.
///
/// **A reading's colour is not its identity, and never was.** Nothing is
/// learned from "the purple one": every series has its name or its number
/// beside it, on the card and on the page, which is what makes a palette that
/// moves with the seed safe at all. What the colour does is tell two lines of
/// *one* chart apart, and rank a row against its neighbours.
///
/// **Nine kinds share six series**, the way they already shared the fixed
/// palette's hues: swap, the network total and the battery were one teal,
/// disk usage and disk I/O one amber, the GPU and disk reads one purple. Two
/// readings never drawn on the same chart can say which they are with the same
/// colour. [SeriesPalette] holds six because six is what fits around the wheel
/// at the 60° its rules ask for.
///
/// [resolve] is what keeps this current — see its own note.
abstract final class ChartPalette {
  /// What the app opens with, and what it falls back to if the theme has not
  /// been read yet: `SettingStore.colorSeed`'s own default.
  static const _fallbackSeed = Color(0xFF880E4F);

  static SeriesPalette _series = SeriesPalette.fan(_fallbackSeed, dark: true);
  static SeriesPalette _emphasis = SeriesPalette.seedFirst(
    _fallbackSeed,
    dark: true,
  );
  static Color? _seed;
  static bool? _dark;

  /// Works the six out again, if either of the two things they depend on has
  /// changed.
  ///
  /// Called from the app's own `MaterialApp.builder`, which is below the theme
  /// — so it runs again when the seed changes, when the brightness changes,
  /// and when the system hands over a dynamic colour, which are the three
  /// things that move this palette. It runs before any page builds, which is
  /// what lets the readings themselves be read as plain statics: threading a
  /// palette through `serverCardReadings` would put a `BuildContext` into a
  /// pure function that has no other use for one.
  ///
  /// [seed] is the colour picked, not `ColorScheme.primary` — Material has
  /// already moved that one to suit its own surfaces, and the first series is
  /// supposed to *be* the theme colour.
  static void resolve(Color seed, {required bool dark}) {
    if (_seed == seed && _dark == dark) return;
    _seed = seed;
    _dark = dark;
    _series = SeriesPalette.fan(seed, dark: dark);
    _emphasis = SeriesPalette.seedFirst(seed, dark: dark);
  }

  /// The six as they stand, for a caller that wants them in order.
  static SeriesPalette get series => _series;

  /// What a reading is drawn in, given whether it is the one being watched.
  ///
  /// One function rather than the same ternary in each place that draws a
  /// reading, and that matters more here than it usually does: a card grows
  /// into the detail page, so the two have to agree exactly or a reading
  /// changes colour at the handover — which reads as the page having swapped
  /// it for a different one.
  static Color reading({required bool promoted}) =>
      promoted ? ChartPalette.promoted : ChartPalette.quiet;

  /// The one reading a card is watching, in the theme colour itself.
  ///
  /// Which reading that is, is said by the label beside it. What the colour
  /// says is that this is the one drawn in full above the rest — so it stays
  /// the theme colour when a different reading is promoted, and a screen of
  /// two dozen machines is one accent on neutrals rather than a hue per
  /// machine chosen by whatever each of them happens to be watching.
  static Color get promoted => _emphasis.of(ChartSeries.cpu);

  /// Every other reading on that card: a tint barely off grey.
  ///
  /// Still a colour rather than grey, so a bar reads as a bar. Nothing is lost
  /// by them all being the same one — each is named at the head of its own
  /// row, and what the eye is doing across them is comparing lengths.
  static Color get quiet => _emphasis.of(ChartSeries.mem);

  /// Half of a pair read together — disk read against write, ↓ against ↑ —
  /// where the colour is the only thing saying which is which.
  ///
  /// Unused on a card, where the pairs are each one row: it is the detail
  /// page that draws both lines. Kept because [quiet] is the wrong answer
  /// there and finding that out from a chart is finding it out late.
  static Color get quietPaired => _emphasis.of(ChartSeries.diskRead);

  /// Also what a promoted row and its chart are drawn in — see the home card.
  static Color get cpu => _series.cpu;

  /// The other half of the pair that shares an axis: an overlaid chart draws
  /// this under [cpu], so the two are a lightness step apart as well as 60°.
  static Color get mem => _series.mem;

  /// Never drawn beside the network, so it can have its colour.
  static Color get swap => _series.netRx;

  /// Disk *usage*, which is never drawn beside the two rates below.
  static Color get disk => _series.diskWrite;

  static Color get diskRead => _series.diskRead;
  static Color get diskWrite => _series.diskWrite;

  static Color get netRx => _series.netRx;
  static Color get netTx => _series.netTx;

  static Color get gpu => _series.diskRead;
  static Color get temp => _series.netTx;
  static Color get battery => _series.netRx;

  /// What a reading over `kServerAlertPercent` is drawn in — see
  /// [StatePalette.warn], which is the same amber for the same reason.
  static const warn = StatePalette.warn;

  /// One metric's devices — sensors, disks, interfaces — in a fixed order, so
  /// a device keeps its colour across rebuilds.
  ///
  /// Fixed where the six are not, and that is the distinction: on a chart of
  /// eight disks the colour is the only thing saying which disk a line is, so
  /// it is carrying identity rather than emphasis. Six derived series fanned
  /// 60° apart are for telling *kinds* apart against the theme; these are for
  /// telling one kind's devices apart from each other, and a palette that
  /// moved with the seed would give the same line a different colour on two
  /// machines.
  ///
  /// Long enough that two lines of one chart never share a colour; a chart
  /// that would need a seventh line says "+N more" instead.
  static const devices = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFFC084FC),
    Color(0xFF2DD4BF),
    Color(0xFF7CC4FF),
    Color(0xFFF43F5E),
  ];
}

/// What a thing that is either working or not is drawn in.
///
/// Four states, and the same four wherever the question is asked: a server in
/// a list, a systemd unit, a process, a reading against its threshold. Fixed
/// where [ChartPalette]'s six are derived, and for the reason [ChartPalette]
/// gives about its [ChartPalette.devices]: these carry meaning rather than
/// emphasis. "Running" has to stay recognisable whatever seed the user picked,
/// and a red that moved with the theme would be a warning nobody could learn.
/// Kept beside the chart colours because the two are read together on every
/// card.
abstract final class StatePalette {
  static const running = Color(0xFF22C55E);

  /// Starting, stopping, or a reading that has crossed its line: something to
  /// look at rather than something that has failed.
  static const warn = Color(0xFFF59E0B);

  static const failed = Color(0xFFEF4444);

  /// Present and doing nothing, which includes a server nobody has connected.
  static const idle = Color(0xFF9E9E9E);
}
