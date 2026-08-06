import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ast/options.dart';
import '../ast/style.dart';
import '../ast/syntax_tree.dart';
import '../ast/tex_break.dart';
import '../parser/tex/parse_error.dart';
import '../parser/tex/parser.dart';
import '../parser/tex/settings.dart';
import 'exception.dart';
import 'mode.dart';
import 'selectable.dart';

typedef OnErrorFallback = Widget Function(FlutterMathException errmsg);

/// Static, non-selectable widget for equations.
///
/// Sample usage:
///
/// ```dart
/// Math.tex(
///   r'\frac a b\sqrt[3]{n}',
///   mathStyle: MathStyle.display,
///   textStyle: TextStyle(fontSize: 42),
/// )
/// ```
///
/// Compared to [SelectableMath], [Math] will offer a significant performance
/// advantage. So if no selection capability is needed or the equation counts
/// on the same screen is huge, it's preferable to use [Math].
class Math extends StatelessWidget {
  /// Math widget default constructor
  ///
  /// Requires either a parsed [ast] or a [parseError].
  ///
  /// See [Math] for its member documentation
  const Math({
    Key? key,
    this.ast,
    this.mathStyle = MathStyle.display,
    this.logicalPpi,
    this.onErrorFallback = defaultOnErrorFallback,
    this.options,
    this.parseError,
    this.textScaleFactor,
    this.textStyle,
  })  : assert(ast != null || parseError != null),
        super(key: key);

  /// The equation to display.
  ///
  /// It can be null only when [parseError] is not null.
  final SyntaxTree? ast;

  /// {@template flutter_math_fork.widgets.math.options}
  /// Equation style.
  ///
  /// Choose [MathStyle.display] for displayed equations and [MathStyle.text]
  /// for in-line equations.
  ///
  /// Will be overruled if [options] is present.
  /// {@endtemplate}
  final MathStyle mathStyle;

  /// {@template flutter_math_fork.widgets.math.logicalPpi}
  /// {@macro flutter_math_fork.math_options.logicalPpi}
  ///
  /// If set to null, the effective [logicalPpi] will scale with
  /// [TextStyle.fontSize]. You can obtain the default scaled value by
  /// [MathOptions.defaultLogicalPpiFor].
  ///
  /// Will be overruled if [options] is present.
  ///
  /// {@endtemplate}
  final double? logicalPpi;

  /// {@template flutter_math_fork.widgets.math.onErrorFallback}
  /// Fallback widget when there are uncaught errors during parsing or building.
  ///
  /// Will be invoked when:
  ///
  /// * [parseError] is not null.
  /// * [SyntaxTree.buildWidget] throw an error.
  ///
  /// Either case, this fallback function is invoked in build functions. So use
  /// with care.
  /// {@endtemplate}
  final OnErrorFallback onErrorFallback;

  /// {@template flutter_math_fork.widgets.math.options}
  /// Overriding [MathOptions] to build the AST.
  ///
  /// Will overrule [mathStyle] and [textStyle] if not null.
  /// {@endtemplate}
  final MathOptions? options;

  /// {@template flutter_math_fork.widgets.math.parseError}
  /// Errors generated during parsing.
  ///
  /// If not null, the [onErrorFallback] widget will be presented.
  /// {@endtemplate}
  final ParseException? parseError;

  /// {@macro flutter.widgets.editableText.textScaleFactor}
  final double? textScaleFactor;

  /// {@template fluttermath.widgets.math.textStyle}
  /// The style for rendered math analogous to [Text.style].
  ///
  /// Can controll the size of the equation via [TextStyle.fontSize]. It can
  /// also affect the font weight and font shape of the equation.
  ///
  /// If set to null, `DefaultTextStyle` from the context will be used.
  ///
  /// Will be overruled if [options] is present.
  /// {@endtemplate}
  final TextStyle? textStyle;

  /// Math builder using a TeX string
  ///
  /// {@template flutter_math_fork.widgets.math.tex_builder}
  /// [expression] will first be parsed under [settings]. Then the acquired
  /// [SyntaxTree] will be built under a specific options. If [ParseException]
  /// is thrown or a build error occurs, [onErrorFallback] will be displayed.
  ///
  /// You can control the options via [mathStyle] and [textStyle].
  /// {@endtemplate}
  ///
  /// See alse:
  ///
  /// * [Math.mathStyle]
  /// * [Math.textStyle]
  factory Math.tex(
    String expression, {
    Key? key,
    MathStyle mathStyle = MathStyle.display,
    TextStyle? textStyle,
    OnErrorFallback onErrorFallback = defaultOnErrorFallback,
    TexParserSettings settings = const TexParserSettings(),
    double? textScaleFactor,
    MathOptions? options,
  }) {
    SyntaxTree? ast;
    ParseException? parseError;
    try {
      ast = SyntaxTree(greenRoot: TexParser(expression, settings).parse());
    } on ParseException catch (e) {
      parseError = e;
    } on Object catch (e) {
      parseError = ParseException('Unsanitized parse exception detected: $e.'
          'Please report this error with correponding input.');
    }
    return Math(
      key: key,
      ast: ast,
      parseError: parseError,
      options: options,
      onErrorFallback: onErrorFallback,
      mathStyle: mathStyle,
      textScaleFactor: textScaleFactor,
      textStyle: textStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (parseError != null) {
      return onErrorFallback(parseError!);
    }

    var options = this.options;
    if (options == null) {
      var effectiveTextStyle = textStyle;
      if (effectiveTextStyle == null || effectiveTextStyle.inherit) {
        effectiveTextStyle =
            DefaultTextStyle.of(context).style.merge(textStyle);
      }
      if (MediaQuery.boldTextOf(context)) {
        effectiveTextStyle = effectiveTextStyle
            .merge(const TextStyle(fontWeight: FontWeight.bold));
      }

      final textScaleFactor =
          this.textScaleFactor ?? MediaQuery.textScaleFactorOf(context);

      options = MathOptions(
        style: mathStyle,
        fontSize: effectiveTextStyle.fontSize! * textScaleFactor,
        mathFontOptions: effectiveTextStyle.fontWeight != FontWeight.normal && effectiveTextStyle.fontWeight != null
            ? FontOptions(fontWeight: effectiveTextStyle.fontWeight!)
            : null,
        logicalPpi: logicalPpi,
        color: effectiveTextStyle.color!,
      );
    }

    Widget child;

    try {
      child = ast!.buildWidget(options);
    } on BuildException catch (e) {
      return onErrorFallback(e);
    } on Object catch (e) {
      return onErrorFallback(
          BuildException('Unsanitized build exception detected: $e.'
              'Please report this error with correponding input.'));
    }

    return Provider.value(
      value: FlutterMathMode.view,
      child: child,
    );
  }

  /// Default fallback function for [Math], [SelectableMath]
  static Widget defaultOnErrorFallback(FlutterMathException error) =>
      SelectableText(error.messageWithType);

  /// Line breaking results using standard TeX-style line breaking.
  ///
  /// This function will return a list of `Math` widget along with a list of
  /// line breaking penalties.
  ///
  /// {@template flutter_math_fork.widgets.math.tex_break}
  ///
  /// This function will break the equation into pieces according to TeX spec
  /// **as much as possible** (some exceptions exist when `enforceNoBreak: true`
  /// ). Then, you can assemble the pieces in whatever way you like. The most
  /// simple way is to put the parts inside a `Wrap`.
  ///
  /// If you wish to implement a custom line breaking policy to manage the
  /// penalties, you can access the penalties in `BreakResult.penalties`. The
  /// values in `BreakResult.penalties` represent the line-breaking penalty
  /// generated at the right end of each `BreakResult.parts`. Note that
  /// `\nobreak` or `\penalty<number>=10000>` are left unbroken by default, you
  /// need to supply `enforceNoBreak: false` into `Math.texBreak` to expose
  /// those break points and their penalties.
  ///
  /// {@endtemplate}
  BreakResult<Math> texBreak({
    int relPenalty = 500,
    int binOpPenalty = 700,
    bool enforceNoBreak = true,
  }) {
    final ast = this.ast;
    if (ast == null || parseError != null) {
      return BreakResult(parts: [this], penalties: [10000]);
    }
    final astBreakResult = ast.texBreak(
      relPenalty: relPenalty,
      binOpPenalty: binOpPenalty,
      enforceNoBreak: enforceNoBreak,
    );
    return BreakResult(
      parts: astBreakResult.parts
          .map((part) => Math(
                ast: part,
                mathStyle: this.mathStyle,
                logicalPpi: this.logicalPpi,
                onErrorFallback: this.onErrorFallback,
                options: this.options,
                parseError: this.parseError,
                textScaleFactor: this.textScaleFactor,
                textStyle: this.textStyle,
              ))
          .toList(growable: false),
      penalties: astBreakResult.penalties,
    );
  }
}
