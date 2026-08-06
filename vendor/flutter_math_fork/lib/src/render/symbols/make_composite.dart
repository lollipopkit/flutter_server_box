import 'package:flutter/widgets.dart';

import '../../ast/nodes/over.dart';
import '../../ast/nodes/style.dart';
import '../../ast/nodes/symbol.dart';
import '../../ast/options.dart';
import '../../ast/size.dart';
import '../../ast/syntax_tree.dart';
import '../../ast/types.dart';
import '../../parser/tex/font.dart';
import '../../utils/unicode_literal.dart';
import '../layout/line.dart';
import '../layout/reset_dimension.dart';
import '../layout/shift_baseline.dart';
import 'make_symbol.dart';

BuildResult makeRlapCompositeSymbol(
  String char1,
  String char2,
  AtomType type,
  Mode mode,
  MathOptions options,
) {
  final res1 = makeBaseSymbol(
      symbol: char1, atomType: type, mode: mode, options: options);
  final res2 = makeBaseSymbol(
      symbol: char2, atomType: type, mode: mode, options: options);
  return BuildResult(
    italic: res2.italic,
    options: options,
    widget: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ResetDimension(
          width: 0,
          horizontalAlignment: CrossAxisAlignment.start,
          child: res1.widget,
        ),
        res2.widget,
      ],
    ),
  );
}

BuildResult makeCompactedCompositeSymbol(
  String char1,
  String char2,
  Measurement spacing,
  AtomType type,
  Mode mode,
  MathOptions options,
) {
  final res1 = makeBaseSymbol(
      symbol: char1, atomType: type, mode: mode, options: options);
  final res2 = makeBaseSymbol(
      symbol: char2, atomType: type, mode: mode, options: options);
  final widget1 = char1 != ':'
      ? res1.widget
      : ShiftBaseline(
          relativePos: 0.5,
          offset: options.fontMetrics.axisHeight.cssEm.toLpUnder(options),
          child: res1.widget,
        );
  final widget2 = char2 != ':'
      ? res2.widget
      : ShiftBaseline(
          relativePos: 0.5,
          offset: options.fontMetrics.axisHeight.cssEm.toLpUnder(options),
          child: res2.widget,
        );
  return BuildResult(
    italic: res2.italic,
    options: options,
    widget: Line(
      children: <Widget>[
        LineElement(
          child: widget1,
          trailingMargin: spacing.toLpUnder(options),
        ),
        widget2,
      ],
    ),
  );
}

BuildResult makeDecoratedEqualSymbol(
  String symbol,
  AtomType type,
  Mode mode,
  MathOptions options,
) {
  List<String> decoratorSymbols;
  FontOptions? decoratorFont;
  MathSize decoratorSize;

  switch (symbol) {
    // case '\u2258':
    //   break;
    case '\u2259':
      decoratorSymbols = ['\u2227']; // \wedge
      decoratorSize = MathSize.tiny;
      break;
    case '\u225A':
      decoratorSymbols = ['\u2228']; // \vee
      decoratorSize = MathSize.tiny;
      break;
    case '\u225B':
      decoratorSymbols = ['\u22c6']; // \star
      decoratorSize = MathSize.scriptsize;
      break;
    case '\u225D':
      decoratorSymbols = ['d', 'e', 'f'];
      decoratorSize = MathSize.tiny;
      decoratorFont = texMathFontOptions['\\mathrm']!;
      break;
    case '\u225E':
      decoratorSymbols = ['m'];
      decoratorSize = MathSize.tiny;
      decoratorFont = texMathFontOptions['\\mathrm']!;
      break;
    case '\u225F':
      decoratorSymbols = ['?'];
      decoratorSize = MathSize.tiny;
      break;
    default:
      throw ArgumentError.value(
          unicodeLiteral(symbol), 'symbol', 'Not a decorator character');
  }

  final decorator = StyleNode(
    children: decoratorSymbols
        .map((symbol) => SymbolNode(symbol: symbol, mode: mode))
        .toList(growable: false),
    optionsDiff: OptionsDiff(
      size: decoratorSize,
      mathFontOptions: decoratorFont,
    ),
  );

  final proxyNode = OverNode(
    base: SymbolNode(symbol: '=', mode: mode, overrideAtomType: type)
        .wrapWithEquationRow(),
    above: decorator.wrapWithEquationRow(),
  );
  return SyntaxNode(parent: null, value: proxyNode, pos: 0)
      .buildWidget(options);
}
