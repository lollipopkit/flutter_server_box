import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../font/metrics/font_metrics.dart';
import 'font_metrics.dart';
import 'size.dart';
import 'style.dart';
import 'syntax_tree.dart';

/// Options for equation element rendering.
///
/// Every [GreenNode] is rendered with an [MathOptions]. It controls their size,
/// color, font, etc.
///
/// [MathOptions] is immutable. Each modification returns a new instance of
/// [MathOptions].
class MathOptions {
  /// The style used to render the math node.
  ///
  /// For displayed equations, use [MathStyle.display].
  ///
  /// For in-line equations, use [MathStyle.text].
  final MathStyle style;

  /// Text color.
  final Color color;

  /// Real size applied to equation elements under current style.
  late final MathSize size = sizeUnderTextStyle.underStyle(style);

  /// Declared size for equation elements.
  ///
  /// User declared size such as \tiny \Huge. The real size applied to equation
  /// elements also depends on current style.
  final MathSize sizeUnderTextStyle;

  /// Font options for text mode.
  ///
  /// Text-mode font options will merge on top of each other. And they will be
  /// reset if any math-mode font style is declared
  final FontOptions? textFontOptions;

  /// Font options for math mode.
  ///
  /// Math-mode font options will override each other.
  final FontOptions? mathFontOptions;

  /// Size multiplier applied to equation elements.
  late final double sizeMultiplier = this.size.sizeMultiplier;

  // final double maxSize;
  // final num minRuleThickness; //???
  // final bool isBlank;

  /// Font metrics under current size.
  late final FontMetrics fontMetrics = getGlobalMetrics(size);

  /// Font size under current size.
  ///
  /// This is the font size passed to Flutter's [RichText] widget to build math
  /// symbols.
  final double fontSize;

  /// {@template flutter_math_fork.math_options.logicalPpi}
  /// Logical pixels per inch on screen.
  ///
  /// This parameter decides how big 1 inch is rendered on the screen. Affects
  /// the size of all equation elements whose size uses an absolute unit (e.g.
  /// pt, cm, inch).
  /// {@endtemplate}
  final double logicalPpi;

  MathOptions._({
    required this.fontSize,
    required this.logicalPpi,
    required this.style,
    this.color = Colors.black,
    this.sizeUnderTextStyle = MathSize.normalsize,
    this.textFontOptions,
    this.mathFontOptions,
    // required this.maxSize,
    // required this.minRuleThickness,
  });

  /// Factory constructor for [MathOptions].
  ///
  /// If [fontSize] is null, then [MathOptions.defaultFontSize] will be used.
  ///
  /// If [logicalPpi] is null, then it will scale with [fontSize]. The default
  /// value for [MathOptions.defaultFontSize] is
  /// [MathOptions.defaultLogicalPpi].
  factory MathOptions({
    MathStyle style = MathStyle.display,
    Color color = Colors.black,
    MathSize sizeUnderTextStyle = MathSize.normalsize,
    FontOptions? textFontOptions,
    FontOptions? mathFontOptions,
    double? fontSize,
    double? logicalPpi,
    // required this.maxSize,
    // required this.minRuleThickness,
  }) {
    final effectiveFontSize = fontSize ??
        (logicalPpi == null
            ? _defaultPtPerEm / Unit.lp.toPt!
            : defaultFontSizeFor(logicalPpi: logicalPpi));
    final effectiveLogicalPPI =
        logicalPpi ?? defaultLogicalPpiFor(fontSize: effectiveFontSize);
    return MathOptions._(
      fontSize: effectiveFontSize,
      logicalPpi: effectiveLogicalPPI,
      style: style,
      color: color,
      sizeUnderTextStyle: sizeUnderTextStyle,
      mathFontOptions: mathFontOptions,
      textFontOptions: textFontOptions,
    );
  }

  static const _defaultLpPerPt = 72.27 / 160;

  static const _defaultPtPerEm = 10;

  /// Default value for [logicalPpi] is 160.
  ///
  /// The value 160 comes from the definition of an Android dp.
  ///
  /// Though Flutter provies a reference value for its logical pixel of
  /// [38 lp/cm](https://api.flutter.dev/flutter/dart-ui/Window/devicePixelRatio.html).
  /// However this value is simply too off from the scale so we use 160 lp/in.
  static const defaultLogicalPpi = 72.27 / _defaultLpPerPt;

  /// Default logical pixel count for 1 em is 1600/72.27.
  ///
  /// By default 1 em = 10 pt. 1 inch = 72.27 pt.
  ///
  /// See also [MathOptions.defaultLogicalPpi].
  static const defaultFontSize = _defaultPtPerEm / _defaultLpPerPt;

  /// Default value for [logicalPpi] when [fontSize] has been set.
  static double defaultLogicalPpiFor({required double fontSize}) =>
      fontSize * Unit.inches.toPt! / _defaultPtPerEm;

  /// Default value for [fontSize] when [logicalPpi] has been set.
  static double defaultFontSizeFor({required double logicalPpi}) =>
      _defaultPtPerEm / Unit.inches.toPt! * logicalPpi;

  /// Default options for displayed equations
  static final displayOptions = MathOptions._(
    fontSize: defaultFontSize,
    logicalPpi: defaultLogicalPpi,
    style: MathStyle.display,
  );

  /// Default options for in-line equations
  static final textOptions = MathOptions._(
    fontSize: defaultFontSize,
    logicalPpi: defaultLogicalPpi,
    style: MathStyle.text,
  );

  /// Returns [MathOptions] with given [MathStyle]
  MathOptions havingStyle(MathStyle style) {
    if (this.style == style) return this;
    return this.copyWith(
      style: style,
    );
  }

  /// Returns [MathOptions] with their styles set to cramped (e.g. textCramped)
  MathOptions havingCrampedStyle() {
    if (this.style.cramped) return this;
    return this.copyWith(
      style: style.cramp(),
    );
  }

  /// Returns [MathOptions] with their user-declared size set to given size
  MathOptions havingSize(MathSize size) {
    if (this.size == size && this.sizeUnderTextStyle == size) return this;
    return this.copyWith(
      style: style.atLeastText(),
      sizeUnderTextStyle: size,
    );
  }

  /// Returns [MathOptions] with size reset to [MathSize.normalsize] and given
  /// style. If style is not given, then the current style will be increased to
  /// at least [MathStyle.text]
  MathOptions havingStyleUnderBaseSize(MathStyle? style) {
    style = style ?? this.style.atLeastText();
    if (this.sizeUnderTextStyle == MathSize.normalsize && this.style == style) {
      return this;
    }
    return this.copyWith(
      style: style,
      sizeUnderTextStyle: MathSize.normalsize,
    );
  }

  /// Returns [MathOptions] with size reset to [MathSize.normalsize]
  MathOptions havingBaseSize() {
    if (this.sizeUnderTextStyle == MathSize.normalsize) return this;
    return this.copyWith(
      sizeUnderTextStyle: MathSize.normalsize,
    );
  }

  /// Returns [MathOptions] with given text color
  MathOptions withColor(Color color) {
    if (this.color == color) return this;
    return this.copyWith(color: color);
  }

  /// Returns [MathOptions] with current text-mode font options merged with
  /// given font differences
  MathOptions withTextFont(PartialFontOptions font) => this.copyWith(
        mathFontOptions: null,
        textFontOptions:
            (this.textFontOptions ?? FontOptions()).mergeWith(font),
      );

  /// Returns [MathOptions] with given math font
  MathOptions withMathFont(FontOptions font) {
    if (font == this.mathFontOptions) return this;
    return this.copyWith(mathFontOptions: font);
  }

  /// Utility method copyWith
  MathOptions copyWith({
    MathStyle? style,
    Color? color,
    MathSize? sizeUnderTextStyle,
    FontOptions? textFontOptions,
    FontOptions? mathFontOptions,
    // double maxSize,
    // num minRuleThickness,
  }) =>
      MathOptions._(
        fontSize: this.fontSize,
        logicalPpi: this.logicalPpi,
        style: style ?? this.style,
        color: color ?? this.color,
        sizeUnderTextStyle: sizeUnderTextStyle ?? this.sizeUnderTextStyle,
        textFontOptions: textFontOptions ?? this.textFontOptions,
        mathFontOptions: mathFontOptions ?? this.mathFontOptions,
        // maxSize: maxSize ?? this.maxSize,
        // minRuleThickness: minRuleThickness ?? this.minRuleThickness,
      );

  /// Merge an [OptionsDiff] into current [MathOptions]
  MathOptions merge(OptionsDiff partialOptions) {
    var res = this;
    if (partialOptions.size != null) {
      res = res.havingSize(partialOptions.size!);
    }
    if (partialOptions.style != null) {
      res = res.havingStyle(partialOptions.style!);
    }
    if (partialOptions.color != null) {
      res = res.withColor(partialOptions.color!);
    }
    // if (partialOptions.phantom == true) {
    //   res = res.withPhantom();
    // }
    if (partialOptions.textFontOptions != null) {
      res = res.withTextFont(partialOptions.textFontOptions!);
    }
    if (partialOptions.mathFontOptions != null) {
      res = res.withMathFont(partialOptions.mathFontOptions!);
    }
    return res;
  }
}

/// Difference between the current [MathOptions] and the desired [MathOptions].
///
/// This is used to declaratively describe the modifications to [MathOptions].
class OptionsDiff {
  /// Override [MathOptions.style]
  final MathStyle? style;

  /// Override declared size.
  final MathSize? size;

  /// Override text color.
  final Color? color;

  /// Merge font differences into text-mode font options.
  final PartialFontOptions? textFontOptions;

  /// Override math-mode font.
  final FontOptions? mathFontOptions;

  const OptionsDiff({
    this.style,
    this.color,
    this.size,
    // this.phantom,
    this.textFontOptions,
    this.mathFontOptions,
  });

  /// Whether this diff has no effect.
  bool get isEmpty =>
      style == null &&
      color == null &&
      size == null &&
      textFontOptions == null &&
      mathFontOptions == null;

  /// Strip the style change.
  OptionsDiff removeStyle() {
    if (style == null) return this;
    return OptionsDiff(
      color: this.color,
      size: this.size,
      textFontOptions: this.textFontOptions,
      mathFontOptions: this.mathFontOptions,
    );
  }

  /// Strip math font changes.
  OptionsDiff removeMathFont() {
    if (mathFontOptions == null) return this;
    return OptionsDiff(
      color: this.color,
      size: this.size,
      style: this.style,
      textFontOptions: this.textFontOptions,
    );
  }
}

/// Options for font selection.
class FontOptions {
  /// Font family. E.g. Main, Math, Sans-Serif, etc.
  final String fontFamily;

  /// Font weight. Bold or normal.
  final FontWeight fontWeight;

  /// Font weight. Italic or normal.
  final FontStyle fontShape;

  /// Fallback font options if a character cannot be found in this font.
  final List<FontOptions> fallback;

  const FontOptions({
    this.fontFamily = 'Main',
    this.fontWeight = FontWeight.normal,
    this.fontShape = FontStyle.normal,
    this.fallback = const [],
  });

  /// Complete font name. Used to index [CharacterMetrics].
  String get fontName {
    final postfix = '${fontWeight == FontWeight.bold ? 'Bold' : ''}'
        '${fontShape == FontStyle.italic ? "Italic" : ""}';
    return '$fontFamily-${postfix.isEmpty ? "Regular" : postfix}';
  }

  /// Utility method.
  FontOptions copyWith({
    String? fontFamily,
    FontWeight? fontWeight,
    FontStyle? fontShape,
    List<FontOptions>? fallback,
  }) =>
      FontOptions(
        fontFamily: fontFamily ?? this.fontFamily,
        fontWeight: fontWeight ?? this.fontWeight,
        fontShape: fontShape ?? this.fontShape,
        fallback: fallback ?? this.fallback,
      );

  /// Merge a font difference into current font.
  FontOptions mergeWith(PartialFontOptions? value) {
    if (value == null) return this;
    return copyWith(
      fontFamily: value.fontFamily,
      fontWeight: value.fontWeight,
      fontShape: value.fontShape,
    );
  }

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is FontOptions &&
        o.fontFamily == fontFamily &&
        o.fontWeight == fontWeight &&
        o.fontShape == fontShape &&
        listEquals(o.fallback, fallback);
  }

  @override
  int get hashCode =>
      hashValues(fontFamily.hashCode, fontWeight.hashCode, fontShape.hashCode);
}

/// Difference between the current [FontOptions] and the desired [FontOptions].
///
/// This is used to declaratively describe the modifications to [FontOptions].
class PartialFontOptions {
  /// Override font family.
  final String? fontFamily;

  /// Override font weight.
  final FontWeight? fontWeight;

  /// Override font style.
  final FontStyle? fontShape;

  const PartialFontOptions({
    this.fontFamily,
    this.fontWeight,
    this.fontShape,
  });

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is PartialFontOptions &&
        o.fontFamily == fontFamily &&
        o.fontWeight == fontWeight &&
        o.fontShape == fontShape;
  }

  @override
  int get hashCode =>
      hashValues(fontFamily.hashCode, fontWeight.hashCode, fontShape.hashCode);
}
