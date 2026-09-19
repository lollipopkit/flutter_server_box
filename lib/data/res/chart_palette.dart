import 'package:flutter/painting.dart';

/// The colours a reading is drawn in, wherever it is drawn.
///
/// The only fixed hues left in the app: everything else is derived from the
/// seed the user picked, and a series cannot be — CPU has to stay the same
/// colour whatever the theme, from the card on the home page to the chart on
/// the detail page.
///
/// Three rules hold this together, and each of the values below was picked to
/// satisfy them rather than because it looked right on its own:
///
/// 1. **A meaning keeps its colour.** [cpu] is one colour everywhere, and
///    nothing else is that colour.
/// 2. **A pair that is read together differs by hue *or* by lightness.** The
///    pairs are CPU↔memory (an overlaid chart draws both), read↔write and
///    ↓↔↑. Sixty degrees of hue is enough on its own; where two land closer
///    than that they are a lightness step apart instead. That is why [mem] is
///    much darker than [cpu]: they are the two that share an axis, and an
///    overlay has to read as two bands rather than as one.
/// 3. **Colour never carries a reading on its own.** Every series has its name
///    or its number beside it, so this palette is legible to someone who
///    cannot tell two of these apart, and in print.
///
/// The set this replaced broke the second rule twice: CPU `#3b82f6` and disk
/// read `#0ea5e9` were one hue step apart, and the memory green was *brighter*
/// than the CPU blue on a dark background, so an overlay was always green over
/// blue whatever the numbers said.
abstract final class ChartPalette {
  /// Also what a promoted row and its chart are drawn in — see the home card.
  static const cpu = Color(0xFF7CC4FF);

  /// Deliberately a lightness step under [cpu]: these two are the pair that
  /// shares an axis. See rule 2.
  static const mem = Color(0xFF1F9D55);

  static const swap = Color(0xFF2DD4BF);

  /// Disk *usage*, which is never drawn beside the two rates below.
  static const disk = Color(0xFFF59E0B);

  static const diskRead = Color(0xFFC084FC);
  static const diskWrite = Color(0xFFF59E0B);

  static const netRx = Color(0xFF2DD4BF);
  static const netTx = Color(0xFFF43F5E);

  static const gpu = Color(0xFFC084FC);
  static const temp = Color(0xFFEF4444);
  static const battery = Color(0xFF2DD4BF);

  /// What a reading over [kServerAlertPercent] is drawn in — see
  /// [StatePalette.warn], which is the same amber for the same reason.
  static const warn = StatePalette.warn;

  /// One metric's devices — sensors, disks, interfaces — in a fixed order, so
  /// a device keeps its colour across rebuilds.
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
/// for the reason [ChartPalette] is — "running" has to stay recognisable
/// whatever seed the user picked — and kept beside it because the two are read
/// together on every card.
abstract final class StatePalette {
  static const running = Color(0xFF22C55E);

  /// Starting, stopping, or a reading that has crossed its line: something to
  /// look at rather than something that has failed.
  static const warn = Color(0xFFF59E0B);

  static const failed = Color(0xFFEF4444);

  /// Present and doing nothing, which includes a server nobody has connected.
  static const idle = Color(0xFF9E9E9E);
}
