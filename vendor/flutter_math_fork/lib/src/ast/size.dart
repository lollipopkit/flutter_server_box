//ignore_for_file: constant_identifier_names

import 'options.dart';
import 'style.dart';

// This table gives the number of TeX pts in one of each *absolute* TeX unit.
// Thus, multiplying a length by this number converts the length from units
// into pts.  Dividing the result by ptPerEm gives the number of ems
// *assuming* a font size of ptPerEm (normal size, normal style).

enum Unit {
  // https://en.wikibooks.org/wiki/LaTeX/Lengths and
  // https://tex.stackexchange.com/a/8263
  pt, // TeX point
  mm, // millimeter
  cm, // centimeter
  inches, // inch //Avoid name collision
  bp, // big (PostScript) points
  pc, // pica
  dd, // didot
  cc, // cicero (12 didot)
  nd, // new didot
  nc, // new cicero (12 new didot)
  sp, // scaled point (TeX's internal smallest unit)
  px, // \pdfpxdimen defaults to 1 bp in pdfTeX and LuaTeX

  ex, // The height of 'x'
  em, // The width of 'M', which is often the size of the font. ()
  mu,

  lp, // Flutter's logical pixel (96 lp per inch)
  cssEm, // Unit used for font metrics. Analogous to KaTeX's internal unit, but
  // always scale with options.
}

extension UnitExt on Unit {
  static const _ptPerUnit = {
    Unit.pt: 1.0,
    Unit.mm: 7227 / 2540,
    Unit.cm: 7227 / 254,
    Unit.inches: 72.27,
    Unit.bp: 803 / 800,
    Unit.pc: 12.0,
    Unit.dd: 1238 / 1157,
    Unit.cc: 14856 / 1157,
    Unit.nd: 685 / 642,
    Unit.nc: 1370 / 107,
    Unit.sp: 1 / 65536,
    // https://tex.stackexchange.com/a/41371
    Unit.px: 803 / 800,

    Unit.ex: null,
    Unit.em: null,
    Unit.mu: null,
    // https://api.flutter.dev/flutter/dart-ui/Window/devicePixelRatio.html
    // Unit.lp: 72.27 / 96,
    Unit.lp: 72.27 / 160, // This is more accurate
    // Unit.lp: 72.27 / 200,
    Unit.cssEm: null,
  };
  double? get toPt => _ptPerUnit[this];

  String get name => const {
        Unit.pt: 'pt',
        Unit.mm: 'mm',
        Unit.cm: 'cm',
        Unit.inches: 'inches',
        Unit.bp: 'bp',
        Unit.pc: 'pc',
        Unit.dd: 'dd',
        Unit.cc: 'cc',
        Unit.nd: 'nd',
        Unit.nc: 'nc',
        Unit.sp: 'sp',
        Unit.px: 'px',
        Unit.ex: 'ex',
        Unit.em: 'em',
        Unit.mu: 'mu',
        Unit.lp: 'lp',
        Unit.cssEm: 'cssEm',
      }[this]!;

  static Unit? parse(String unit) => unit.parseUnit();
}

extension UnitExtOnString on String {
  Unit? parseUnit() => const {
        'pt': Unit.pt,
        'mm': Unit.mm,
        'cm': Unit.cm,
        'inches': Unit.inches,
        'bp': Unit.bp,
        'pc': Unit.pc,
        'dd': Unit.dd,
        'cc': Unit.cc,
        'nd': Unit.nd,
        'nc': Unit.nc,
        'sp': Unit.sp,
        'px': Unit.px,
        'ex': Unit.ex,
        'em': Unit.em,
        'mu': Unit.mu,
        'lp': Unit.lp,
        'cssEm': Unit.cssEm,
      }[this];
}

class Measurement {
  final double value;
  final Unit unit;
  const Measurement({required this.value, required this.unit});

  double toLpUnder(MathOptions options) {
    if (unit == Unit.lp) return value;
    if (unit.toPt != null) {
      return value * unit.toPt! / Unit.inches.toPt! * options.logicalPpi;
    }
    switch (unit) {
      case Unit.cssEm:
        return value * options.fontSize * options.sizeMultiplier;
      // `mu` units scale with scriptstyle/scriptscriptstyle.
      case Unit.mu:
        return value *
            options.fontSize *
            options.fontMetrics.cssEmPerMu *
            options.sizeMultiplier;
      // `ex` and `em` always refer to the *textstyle* font
      // in the current size.
      case Unit.ex:
        return value *
            options.fontSize *
            options.fontMetrics.xHeight *
            options.havingStyle(options.style.atLeastText()).sizeMultiplier;
      case Unit.em:
        return value *
            options.fontSize *
            options.fontMetrics.quad *
            options.havingStyle(options.style.atLeastText()).sizeMultiplier;
      default:
        throw ArgumentError("Invalid unit: '${unit.toString()}'");
    }
  }

  double toCssEmUnder(MathOptions options) =>
      toLpUnder(options) / options.fontSize;

  @override
  String toString() => '$value${unit.name}';

  static const zero = Measurement(value: 0, unit: Unit.pt);
}

extension MeasurementExtOnNum on double {
  Measurement get pt => Measurement(value: this, unit: Unit.pt);
  Measurement get mm => Measurement(value: this, unit: Unit.mm);
  Measurement get cm => Measurement(value: this, unit: Unit.cm);
  Measurement get inches => Measurement(value: this, unit: Unit.inches);
  Measurement get bp => Measurement(value: this, unit: Unit.bp);
  Measurement get pc => Measurement(value: this, unit: Unit.pc);
  Measurement get dd => Measurement(value: this, unit: Unit.dd);
  Measurement get cc => Measurement(value: this, unit: Unit.cc);
  Measurement get nd => Measurement(value: this, unit: Unit.nd);
  Measurement get nc => Measurement(value: this, unit: Unit.nc);
  Measurement get sp => Measurement(value: this, unit: Unit.sp);
  Measurement get px => Measurement(value: this, unit: Unit.px);
  Measurement get ex => Measurement(value: this, unit: Unit.ex);
  Measurement get em => Measurement(value: this, unit: Unit.em);
  Measurement get mu => Measurement(value: this, unit: Unit.mu);
  Measurement get lp => Measurement(value: this, unit: Unit.lp);
  Measurement get cssEm => Measurement(value: this, unit: Unit.cssEm);
}

enum MathSize {
  tiny,
  size2,
  scriptsize,
  footnotesize,
  small,
  normalsize,
  large,
  Large,
  LARGE,
  huge,
  HUGE,
}

extension SizeModeExt on MathSize {
  double get sizeMultiplier => const [
        0.5,
        0.6,
        0.7,
        0.8,
        0.9,
        1.0,
        1.2,
        1.44,
        1.728,
        2.074,
        2.488,
      ][this.index];
}
