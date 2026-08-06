
import 'package:flutter/widgets.dart';

import '../../ast/options.dart';
import '../../ast/size.dart';
import '../../ast/symbols/symbols.dart';
import '../../ast/symbols/symbols_composite.dart';
import '../../ast/symbols/symbols_extra.dart';
import '../../ast/syntax_tree.dart';
import '../../ast/types.dart';
import '../../font/metrics/font_metrics.dart';
import '../layout/reset_dimension.dart';
import 'make_composite.dart';

BuildResult makeBaseSymbol({
  required String symbol,
  bool variantForm = false,
  required AtomType atomType,
  required Mode mode,
  FontOptions? overrideFont,
  required MathOptions options,
}) {
  // First lookup the render config table. We need the information
  var symbolRenderConfig = symbolRenderConfigs[symbol];
  if (symbolRenderConfig != null) {
    if (variantForm) {
      symbolRenderConfig = symbolRenderConfig.variantForm;
    }
    final renderConfig = mode == Mode.math
        ? (symbolRenderConfig?.math ?? symbolRenderConfig?.text)
        : (symbolRenderConfig?.text ?? symbolRenderConfig?.math);
    final char = renderConfig?.replaceChar ?? symbol;

    // Only mathord and textord will be affected by user-specified fonts
    // Also, surrogate pairs will ignore any user-specified font.
    if (atomType == AtomType.ord && symbol.codeUnitAt(0) != 0xD835) {
      final useMathFont = mode == Mode.math ||
          (mode == Mode.text && options.mathFontOptions != null);
      var font = overrideFont ??
          (useMathFont ? options.mathFontOptions : options.textFontOptions);

      if (font != null) {
        var charMetrics = lookupChar(char, font, mode);

        // Some font (such as boldsymbol) has fallback options
        if (charMetrics == null) {
          for (final fallback in font.fallback) {
            charMetrics = lookupChar(char, fallback, mode);
            if (charMetrics != null) {
              font = fallback;
              break;
            }
          }
          font!;
        }

        if (charMetrics != null) {
          final italic = charMetrics.italic.cssEm.toLpUnder(options);
          return BuildResult(
            options: options,
            italic: italic,
            skew: charMetrics.skew.cssEm.toLpUnder(options),
            widget: makeChar(symbol, font, charMetrics, options,
                needItalic: mode == Mode.math),
          );
        } else if (ligatures.containsKey(symbol) &&
            font.fontFamily == 'Typewriter') {
          // Make a special case for ligatures under Typewriter font
          final expandedText = ligatures[symbol]!.split('');
          return BuildResult(
            options: options,
            widget: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: expandedText
                  .map((e) =>
                      makeChar(e, font!, lookupChar(e, font, mode), options))
                  .toList(growable: false),
            ),
            italic: 0.0,
            skew: 0.0,
          );
        }
      }
    }

    // If the code reaches here, it means we failed to find any appliable
    // user-specified font. We will use default render configs.
    final defaultFont = renderConfig?.defaultFont ?? const FontOptions();
    final characterMetrics = getCharacterMetrics(
      character: renderConfig?.replaceChar ?? symbol,
      fontName: defaultFont.fontName,
      mode: Mode.math,
    );
    final italic = characterMetrics?.italic.cssEm.toLpUnder(options) ?? 0.0;
    // fontMetricsData[defaultFont.fontName][replaceChar.codeUnitAt(0)];
    return BuildResult(
      options: options,
      widget: makeChar(char, defaultFont, characterMetrics, options,
          needItalic: mode == Mode.math),
      italic: italic,
      skew: characterMetrics?.skew.cssEm.toLpUnder(options) ?? 0.0,
    );

    // Check if it is a special symbol
  } else if (mode == Mode.math && variantForm == false) {
    if (negatedOperatorSymbols.containsKey(symbol)) {
      final chars = negatedOperatorSymbols[symbol]!;
      return makeRlapCompositeSymbol(
          chars[0], chars[1], atomType, mode, options);
    } else if (compactedCompositeSymbols.containsKey(symbol)) {
      final chars = compactedCompositeSymbols[symbol]!;
      final spacing = compactedCompositeSymbolSpacings[symbol]!;
      // final type = compactedCompositeSymbolTypes[symbol];
      return makeCompactedCompositeSymbol(
          chars[0], chars[1], spacing, atomType, mode, options);
    } else if (decoratedEqualSymbols.contains(symbol)) {
      return makeDecoratedEqualSymbol(symbol, atomType, mode, options);
    }
  }
  return BuildResult(
    options: options,
    italic: 0.0,
    skew: 0.0,
    widget: makeChar(symbol, const FontOptions(), null, options,
        needItalic: mode == Mode.math),
  );
}

Widget makeChar(String character, FontOptions font,
    CharacterMetrics? characterMetrics, MathOptions options,
    {bool needItalic = false}) {
  final charWidget = ResetDimension(
    height: characterMetrics?.height.cssEm.toLpUnder(options),
    depth: characterMetrics?.depth.cssEm.toLpUnder(options),
    child: RichText(
      text: TextSpan(
        text: character,
        style: TextStyle(
          fontFamily: 'packages/flutter_math_fork/KaTeX_${font.fontFamily}',
          fontWeight: font.fontWeight,
          fontStyle: font.fontShape,
          fontSize: 1.0.cssEm.toLpUnder(options),
          color: options.color,
        ),
      ),
      softWrap: false,
      overflow: TextOverflow.visible,
    ),
  );
  if (needItalic) {
    final italic = characterMetrics?.italic.cssEm.toLpUnder(options) ?? 0.0;
    return Padding(
      padding: EdgeInsets.only(right: italic),
      child: charWidget,
    );
  }
  return charWidget;
}

CharacterMetrics? lookupChar(String char, FontOptions font, Mode mode) =>
    getCharacterMetrics(
      character: char,
      fontName: font.fontName,
      mode: mode,
    );

final _numberDigitRegex = RegExp('[0-9]');

final _mathitLetters = {
  // "\\imath",
  'ı', // dotless i
  // "\\jmath",
  'ȷ', // dotless j
  // "\\pounds", "\\mathsterling", "\\textsterling",
  '£', // pounds symbol
};

FontOptions mathdefault(String value) {
  if (_numberDigitRegex.hasMatch(value[0]) || _mathitLetters.contains(value)) {
    return FontOptions(
      fontFamily: 'Main',
      fontShape: FontStyle.italic,
    );
  } else {
    return FontOptions(
      fontFamily: 'Math',
      fontShape: FontStyle.italic,
    );
  }
}
