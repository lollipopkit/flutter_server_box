// The MIT License (MIT)
//
// Copyright (c) 2013-2019 Khan Academy and other contributors
// Copyright (c) 2020 znjameswu <znjameswu@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

part of katex_base;

const _genfracEntries = {
  [
    '\\cfrac', '\\dfrac', '\\frac', '\\tfrac',
    '\\dbinom', '\\binom', '\\tbinom',
    '\\\\atopfrac', // can’t be entered directly
    '\\\\bracefrac', '\\\\brackfrac', // ditto
  ]: FunctionSpec<GreenNode>(
    numArgs: 2,
    greediness: 2,
    handler: _fracHandler,
  ),

  // Infix generalized fractions -- these are not rendered directly, but
  // replaced immediately by one of the variants above.
  ['\\over', '\\choose', '\\atop', '\\brace', '\\brack']:
      FunctionSpec<GreenNode>(
    numArgs: 0,
    infix: true,
    handler: _overHandler,
  ),

  ['\\genfrac']: FunctionSpec<GreenNode>(
    numArgs: 6,
    greediness: 6,
    handler: _genfracHandler,
  ),

  // \above is an infix fraction that also defines a fraction bar size.
  ['\\above']: FunctionSpec<GreenNode>(
    numArgs: 1,
    infix: true,
    handler: _aboveHandler,
  ),

  ['\\\\abovefrac']: FunctionSpec(
    numArgs: 3,
    handler: _aboveFracHandler,
  ),
};

GreenNode _fracHandler(TexParser parser, FunctionContext context) {
  final numer = parser.parseArgNode(mode: null, optional: false)!;
  final denom = parser.parseArgNode(mode: null, optional: false)!;
  return _internalFracHandler(
    funcName: context.funcName,
    numer: numer.wrapWithEquationRow(),
    denom: denom.wrapWithEquationRow(),
  );
}

GreenNode _internalFracHandler({
  required String funcName,
  required EquationRowNode numer,
  required EquationRowNode denom,
}) {
  bool hasBarLine;
  String? leftDelim;
  String? rightDelim;
  MathStyle? size;

  switch (funcName) {
    case '\\cfrac':
    case '\\dfrac':
    case '\\frac':
    case '\\tfrac':
      hasBarLine = true;
      break;
    case '\\\\atopfrac':
      hasBarLine = false;
      break;
    case '\\dbinom':
    case '\\binom':
    case '\\tbinom':
      hasBarLine = false;
      leftDelim = '(';
      rightDelim = ')';
      break;
    case '\\\\bracefrac':
      hasBarLine = false;
      leftDelim = '{';
      rightDelim = '}';
      break;
    case '\\\\brackfrac':
      hasBarLine = false;
      leftDelim = '[';
      rightDelim = ']';
      break;
    default:
      throw ParseException('Unrecognized genfrac command');
  }
  switch (funcName) {
    case '\\cfrac':
    case '\\dfrac':
    case '\\dbinom':
      size = MathStyle.display;
      break;
    case '\\tfrac':
    case '\\tbinom':
      size = MathStyle.text;
      break;
  }
  GreenNode res = FracNode(
    numerator: numer,
    denominator: denom,
    barSize: hasBarLine ? null : Measurement.zero,
    continued: funcName == '\\cfrac',
  );
  if (leftDelim != null || rightDelim != null) {
    res = LeftRightNode(
      body: [res.wrapWithEquationRow()],
      leftDelim: leftDelim,
      rightDelim: rightDelim,
    );
  }
  if (size != null) {
    res = StyleNode(
      children: [res],
      optionsDiff: OptionsDiff(style: size),
    );
  }
  return res;
}

GreenNode _overHandler(TexParser parser, FunctionContext context) {
  String replaceWith;
  switch (context.funcName) {
    case '\\over':
      replaceWith = '\\frac';
      break;
    case '\\choose':
      replaceWith = '\\binom';
      break;
    case '\\atop':
      replaceWith = '\\\\atopfrac';
      break;
    case '\\brace':
      replaceWith = '\\\\bracefrac';
      break;
    case '\\brack':
      replaceWith = '\\\\brackfrac';
      break;
    default:
      throw ArgumentError('Unrecognized infix genfrac command');
  }
  final numerBody = context.infixExistingArguments;
  final denomBody = parser.parseExpression(
    breakOnTokenText: context.breakOnTokenText,
    infixArgumentMode: true,
  );
  return _internalFracHandler(
    funcName: replaceWith,
    numer: numerBody.wrapWithEquationRow(),
    denom: denomBody.wrapWithEquationRow(),
  );
}

GreenNode _genfracHandler(TexParser parser, FunctionContext context) {
  final leftDelimArg = parser.parseArgNode(mode: Mode.math, optional: false)!;
  final rightDelimArg = parser.parseArgNode(mode: Mode.math, optional: false)!;
  final barSize = parser.parseArgSize(optional: false)!;
  final styleArg = parser.parseArgNode(mode: Mode.text, optional: false)!;
  final numer = parser.parseArgNode(mode: Mode.math, optional: false)!;
  final denom = parser.parseArgNode(mode: Mode.math, optional: false)!;

  final leftDelimNode = leftDelimArg is EquationRowNode
      ? leftDelimArg.children.length == 1
          ? leftDelimArg.children.first
          : null
      : leftDelimArg;
  final rightDelimNode = rightDelimArg is EquationRowNode
      ? rightDelimArg.children.length == 1
          ? rightDelimArg.children.first
          : null
      : rightDelimArg;

  final leftDelim =
      (leftDelimNode is SymbolNode && leftDelimNode.atomType == AtomType.open)
          ? leftDelimNode.symbol
          : null;

  final rightDelim = (rightDelimNode is SymbolNode &&
          rightDelimNode.atomType == AtomType.close)
      ? rightDelimNode.symbol
      : null;

  int? style;
  if (styleArg.expandEquationRow().isNotEmpty) {
    final textOrd = assertNodeType<SymbolNode>(styleArg.expandEquationRow()[0]);
    style = int.tryParse(textOrd.symbol);
  }

  GreenNode res = FracNode(
    numerator: numer.wrapWithEquationRow(),
    denominator: denom.wrapWithEquationRow(),
    barSize: barSize,
  );

  if (leftDelim != null || rightDelim != null) {
    res = LeftRightNode(
      body: [res.wrapWithEquationRow()],
      leftDelim: leftDelim,
      rightDelim: rightDelim,
    );
  }

  if (style != null) {
    res = StyleNode(
      children: [res],
      optionsDiff: OptionsDiff(style: style.toMathStyle()),
    );
  }
  return res;
}

GreenNode _aboveHandler(TexParser parser, FunctionContext context) {
  final numerBody = context.infixExistingArguments;
  final barSize = parser.parseArgSize(optional: false);
  final denomBody = parser.parseExpression(
    breakOnTokenText: context.breakOnTokenText,
    infixArgumentMode: true,
  );
  return FracNode(
    numerator: numerBody.wrapWithEquationRow(),
    denominator: denomBody.wrapWithEquationRow(),
    barSize: barSize,
  );
}

GreenNode _aboveFracHandler(TexParser parser, FunctionContext context) {
  final numer = parser.parseArgNode(mode: Mode.math, optional: false)!;
  final barSize = parser.parseArgSize(optional: false)!;
  final denom = parser.parseArgNode(mode: Mode.math, optional: false)!;

  return FracNode(
    numerator: numer.wrapWithEquationRow(),
    denominator: denom.wrapWithEquationRow(),
    barSize: barSize,
  );
}
