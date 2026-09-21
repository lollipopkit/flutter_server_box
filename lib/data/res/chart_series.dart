import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:server_box/core/color/oklch.dart';

/// Which reading a line or a bar is, as far as colour is concerned.
///
/// Six, because six is what fits around the wheel at the 60° the palette's
/// rules ask for. The app reports more kinds than this — swap, GPU, a
/// temperature — and they share these six the way the fixed palette already
/// had them share its hues: a colour here says *which reading*, and two
/// readings never drawn together can say it with the same one.
enum ChartSeries { cpu, mem, diskRead, diskWrite, netRx, netTx }

/// The six series, worked out from the colour the user picked.
///
/// The app's accent is a setting, and a chart drawn in a fixed palette beside
/// it was six colours that had nothing to do with the one the user chose. So
/// the palette is derived, in Oklch, in four steps:
///
/// 1. **The first series is the theme colour.** Its hue is kept exactly; its
///    lightness is moved to the one step this theme can be read at; and its
///    chroma is whatever survives [Oklch.fitted] there. The default seed
///    `#880E4F` asks for 0.16 and gets 0.11.
/// 2. **The other five fan out in 60° steps** from that hue, so the six fill
///    the wheel and no two land on each other.
/// 3. **Their chroma is 72% of what the first one actually got**, not of what
///    it asked for. Derived from the request, a secondary out-saturated the
///    theme colour at every hue where the anchor's own had run out of gamut —
///    which is the one thing this palette must never do. Their lightness is a
///    step down, alternating, so neighbours differ in light as well as hue.
/// 4. **Chroma is floored at [_minChroma] and capped at [_maxChroma].** The
///    floor is for a near-grey seed, which would otherwise smear all six into
///    the same grey; the cap is so a vivid one does not make a chart that is
///    painful to read a column of.
///
/// Three rules survive from the fixed palette this replaced, and the numbers
/// above are what satisfies them — see `chart_series_test.dart`, which asserts
/// them for every seed the app ships:
///
/// - **A meaning keeps its colour** within a theme: `cpu` is one colour
///   everywhere and nothing else is that colour.
/// - **A pair that is read together differs by hue *or* by light.** The pairs
///   are CPU↔memory (an overlaid chart draws both), read↔write and ↓↔↑.
/// - **Colour never carries a reading on its own.** Every series has its name
///   or its number beside it, which is what makes a derived palette safe at
///   all: the six move with the seed, so nothing can be learned by hue.
final class SeriesPalette {
  const SeriesPalette._(this._colors, this._hues);

  final List<Color> _colors;

  /// The hue each series was *built* at, which is not quite the hue of the
  /// colour that came out: fitting to the gamut and rounding to eight bits
  /// move it by a fraction of a degree. The rule about 60° is about these.
  final List<double> _hues;

  /// Never under this, or a seed with almost no colour in it yields six greys.
  static const _minChroma = 0.10;

  /// Never over this, however vivid the seed.
  static const _maxChroma = 0.17;

  /// Every series is a colour of its own, fanned around the wheel.
  ///
  /// What a single chart wants: the lines in it are told apart by colour, so
  /// each needs one.
  factory SeriesPalette.fan(Color seed, {required bool dark}) {
    final s = Oklch.of(seed);
    final asked = _clampChroma(s.c * 1.15);
    // The anchor is fitted first, and the rest are derived from what it got.
    // See step 3.
    final anchor = Oklch(dark ? 0.82 : 0.54, asked, s.h).fitted;
    final steps = dark ? const [0.70, 0.60] : const [0.64, 0.50];

    final hues = [
      s.h,
      for (var i = 1; i < ChartSeries.values.length; i++) (s.h + i * 60) % 360,
    ];
    return SeriesPalette._([
      anchor.color,
      for (var i = 1; i < ChartSeries.values.length; i++)
        Oklch(steps[i % 2], anchor.c * 0.72, hues[i]).fitted.color,
    ], hues);
  }

  static double _clampChroma(double c) =>
      math.min(_maxChroma, math.max(_minChroma, c));

  Color of(ChartSeries series) => _colors[series.index];

  /// The hue [series] was built at — see [_hues].
  double hueOf(ChartSeries series) => _hues[series.index];

  Color get cpu => _colors[0];
  Color get mem => _colors[1];
  Color get diskRead => _colors[2];
  Color get diskWrite => _colors[3];
  Color get netRx => _colors[4];
  Color get netTx => _colors[5];

  /// In [ChartSeries] order.
  List<Color> get all => List.unmodifiable(_colors);
}
