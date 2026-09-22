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
/// *one* chart apart, and two stretches of one bar.
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
  }

  /// The six as they stand, for a caller that wants them in order.
  static SeriesPalette get series => _series;

  /// What a reading is drawn in where there is nothing to tell it apart from:
  /// the icon at the head of its row, its bar, the one line of its chart. The
  /// theme colour itself.
  ///
  /// Every reading, not only the one a card is watching. The rest were a tint
  /// barely off grey, on a hue moved 100° off the theme's so as not to read as
  /// a faded version of it — and read instead as a colour that had nothing to
  /// do with the theme: olive under a pink one, beside cards whose own icons
  /// were pink. Which row is the one drawn in full is said by its surface and
  /// its glyph, and what is compared across rows is lengths.
  ///
  /// The first of [series], so a line drawn in this and a stretch of a bar
  /// drawn in [cpu] are one colour rather than two near ones.
  static Color get accent => _series.cpu;

  /// The lines of one chart, in the order they are handed out.
  ///
  /// The first is [accent]: a chart with one line is drawn in the theme
  /// colour, and one with several starts there — the write rate beside the
  /// read, the first device of six. The rest are the other five of the fan,
  /// taken from the far side of the wheel first, so that two lines are
  /// opposite hues rather than neighbours and it is the sixth that ends up
  /// 60° from the first.
  ///
  /// By position rather than by device, and derived rather than fixed. They
  /// were six colours chosen at build time, on the argument that a line's
  /// colour is its identity; but the legend under the chart names every line
  /// beside its colour, and six fixed hues were six more colours on the page
  /// with nothing to do with the theme — two of them [StatePalette]'s own red
  /// and amber, on a line that was neither failing nor over anything.
  ///
  /// As long as the most lines a chart draws; one that would need a seventh
  /// says "+N more" instead.
  static List<Color> get lines {
    final all = _series.all;
    return [for (final i in const [0, 3, 1, 4, 2, 5]) all[i]];
  }

  /// Also [accent], which is the same colour asked for by what it is for.
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
}

/// What a thing that is either working or not is drawn in.
///
/// Four states, and the same four wherever the question is asked: a server in
/// a list, a systemd unit, a process, a reading against its threshold. Fixed
/// where [ChartPalette]'s six are derived, because these carry meaning rather
/// than emphasis. "Running" has to stay recognisable whatever seed the user picked,
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
