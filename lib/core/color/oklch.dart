import 'dart:math' as math;
import 'dart:ui' show Color;

/// A colour as lightness, chroma and hue, which is what the chart palette is
/// written in.
///
/// Oklch rather than HSL because the palette's rules are about *perceived*
/// quantities and HSL's are not: two HSL colours at the same `L` are not
/// equally bright — yellow at 50% reads far lighter than blue at 50% — so a
/// rule like "a lightness step apart" means a different thing at every hue.
/// Oklch's [l] is perceptual, so one number holds across the wheel, and its
/// [c] is unbounded rather than a percentage of whatever that hue can reach.
///
/// The consequence is that a stated (l, c, h) is not always a colour a screen
/// can show — see [fitted], which is where that is dealt with.
final class Oklch {
  const Oklch(this.l, this.c, this.h);

  /// Perceived lightness, 0 (black) to 1 (white).
  final double l;

  /// Colourfulness. 0 is grey; sRGB reaches about 0.37 at its most saturated,
  /// and only at a few hues.
  final double c;

  /// Degrees around the wheel, 0-360.
  final double h;

  /// What [color] is, in these terms. Alpha is dropped.
  factory Oklch.of(Color color) {
    final rgb = _toLinear(color);
    final l = _cbrt(
      0.4122214708 * rgb.$1 + 0.5363325363 * rgb.$2 + 0.0514459929 * rgb.$3,
    );
    final m = _cbrt(
      0.2119034982 * rgb.$1 + 0.6806995451 * rgb.$2 + 0.1073969566 * rgb.$3,
    );
    final s = _cbrt(
      0.0883024619 * rgb.$1 + 0.2817188376 * rgb.$2 + 0.6299787005 * rgb.$3,
    );

    final lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;

    var hue = math.atan2(b, a) * 180 / math.pi;
    if (hue < 0) hue += 360;
    return Oklch(lightness, math.sqrt(a * a + b * b), hue);
  }

  Oklch withChroma(double c) => Oklch(l, c, h);

  /// The same lightness and hue at the most chroma sRGB can actually show.
  ///
  /// Only ever reduces. A colour asked for outside the gamut is brought back
  /// along its own hue at its own lightness, so what gives is the only one of
  /// the three the palette's rules do not depend on — the rules are "60° of
  /// hue apart" and "a lightness step apart", and clipping the channels
  /// instead would have moved both.
  ///
  /// Stepped rather than solved, and the step is the design's: a closed form
  /// for the sRGB hull in this space is not one, and 0.004 is finer than the
  /// 1/255 a channel is quantised to.
  Oklch get fitted {
    var c = this.c;
    for (var i = 0; i < 60; i++) {
      final rgb = _toLinearRgb(l, c, h);
      // A hair outside counts as inside: the far end of this walk is a value
      // that rounds to an in-range byte anyway, and a strict test spends a
      // whole step backing away from a boundary it is already on.
      if (rgb.$1 >= -0.001 &&
          rgb.$1 <= 1.001 &&
          rgb.$2 >= -0.001 &&
          rgb.$2 <= 1.001 &&
          rgb.$3 >= -0.001 &&
          rgb.$3 <= 1.001) {
        break;
      }
      c -= 0.004;
      if (c <= 0) {
        c = 0;
        break;
      }
    }
    return Oklch(l, c, h);
  }

  /// This colour, opaque. Channels are clamped, so a value that was never
  /// [fitted] answers with the nearest thing a screen can show rather than
  /// with nothing.
  Color get color {
    final rgb = _toLinearRgb(l, c, h);
    return Color.fromARGB(
      255,
      _toByte(rgb.$1),
      _toByte(rgb.$2),
      _toByte(rgb.$3),
    );
  }

  @override
  String toString() =>
      'oklch(${l.toStringAsFixed(3)} ${c.toStringAsFixed(3)} '
      '${h.toStringAsFixed(1)})';
}

/// The share of light a colour reflects, for the contrast between two of them.
///
/// WCAG's relative luminance. Used by the palette's own self-check — see
/// `chart_palette.dart` — rather than for a text contrast rule.
double relativeLuminance(Color color) {
  final rgb = _toLinear(color);
  return 0.2126 * rgb.$1 + 0.7152 * rgb.$2 + 0.0722 * rgb.$3;
}

/// How far apart two colours are in light, 1 being identical.
double contrastRatio(Color a, Color b) {
  final x = relativeLuminance(a) + 0.05;
  final y = relativeLuminance(b) + 0.05;
  return x > y ? x / y : y / x;
}

/// How far apart two hues are, never more than half the wheel.
double hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

(double, double, double) _toLinear(Color color) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return (channel(color.r), channel(color.g), channel(color.b));
}

(double, double, double) _toLinearRgb(double L, double C, double h) {
  final a = C * math.cos(h * math.pi / 180);
  final b = C * math.sin(h * math.pi / 180);

  final l = _cube(L + 0.3963377774 * a + 0.2158037573 * b);
  final m = _cube(L - 0.1055613458 * a - 0.0638541728 * b);
  final s = _cube(L - 0.0894841775 * a - 1.2914855480 * b);

  return (
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  );
}

int _toByte(double linear) {
  final v = linear <= 0.0031308
      ? linear * 12.92
      : 1.055 * math.pow(linear, 1 / 2.4) - 0.055;
  return (v.clamp(0.0, 1.0) * 255).round();
}

double _cube(double x) => x * x * x;

/// Signed: the cube root of a negative number is negative, and these are.
double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
