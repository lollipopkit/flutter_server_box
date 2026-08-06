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

const _delimSizingEntries = {
  [
    '\\bigl',
    '\\Bigl',
    '\\biggl',
    '\\Biggl',
    '\\bigr',
    '\\Bigr',
    '\\biggr',
    '\\Biggr',
    '\\bigm',
    '\\Bigm',
    '\\biggm',
    '\\Biggm',
    '\\big',
    '\\Big',
    '\\bigg',
    '\\Bigg',
  ]: FunctionSpec(numArgs: 1, handler: _delimSizeHandler),
  ['\\right']: FunctionSpec(
    numArgs: 1,
    // greediness: 3,
    handler: _rightHandler,
  ),
  ['\\left']: FunctionSpec(
    numArgs: 1,
    // greediness: 2,
    handler: _leftHandler,
  ),
  ['\\middle']: FunctionSpec(numArgs: 1, handler: _middleHandler),
};

const _delimiterTypes = {
  '\\bigl': AtomType.open,
  '\\Bigl': AtomType.open,
  '\\biggl': AtomType.open,
  '\\Biggl': AtomType.open,
  '\\bigr': AtomType.close,
  '\\Bigr': AtomType.close,
  '\\biggr': AtomType.close,
  '\\Biggr': AtomType.close,
  '\\bigm': AtomType.rel,
  '\\Bigm': AtomType.rel,
  '\\biggm': AtomType.rel,
  '\\Biggm': AtomType.rel,
  '\\big': AtomType.ord,
  '\\Big': AtomType.ord,
  '\\bigg': AtomType.ord,
  '\\Bigg': AtomType.ord,
};

const _delimiterSizes = {
  '\\bigl': 1,
  '\\Bigl': 2,
  '\\biggl': 3,
  '\\Biggl': 4,
  '\\bigr': 1,
  '\\Bigr': 2,
  '\\biggr': 3,
  '\\Biggr': 4,
  '\\bigm': 1,
  '\\Bigm': 2,
  '\\biggm': 3,
  '\\Biggm': 4,
  '\\big': 1,
  '\\Big': 2,
  '\\bigg': 3,
  '\\Bigg': 4,
};

const delimiterCommands = [
  '(',
  '\\lparen',
  ')',
  '\\rparen',
  '[',
  '\\lbrack',
  ']',
  '\\rbrack',
  '\\{',
  '\\lbrace',
  '\\}',
  '\\rbrace',
  '\\lfloor',
  '\\rfloor',
  '\u230a',
  '\u230b',
  '\\lceil',
  '\\rceil',
  '\u2308',
  '\u2309',
  '<',
  '>',
  '\\langle',
  '\u27e8',
  '\\rangle',
  '\u27e9',
  '\\lt',
  '\\gt',
  '\\lvert',
  '\\rvert',
  '\\lVert',
  '\\rVert',
  '\\lgroup',
  '\\rgroup',
  '\u27ee',
  '\u27ef',
  '\\lmoustache',
  '\\rmoustache',
  '\u23b0',
  '\u23b1',
  '/',
  '\\backslash',
  '|',
  '\\vert',
  '\\|',
  '\\Vert',
  '\\uparrow',
  '\\Uparrow',
  '\\downarrow',
  '\\Downarrow',
  '\\updownarrow',
  '\\Updownarrow',
  '.',
];

final _delimiterSymbols = delimiterCommands
    .map((command) => texSymbolCommandConfigs[Mode.math]![command]!)
    .toList(growable: false);

String? _checkDelimiter(GreenNode delim, FunctionContext context) {
  if (delim is SymbolNode) {
    if (_delimiterSymbols.any((symbol) =>
        symbol.symbol == delim.symbol &&
        symbol.variantForm == delim.variantForm)) {
      if (delim.symbol == '<' || delim.symbol == 'lt') {
        return '\u27e8';
      } else if (delim.symbol == '>' || delim.symbol == 'gt') {
        return '\u27e9';
      } else if (delim.symbol == '.') {
        return null;
      } else {
        return delim.symbol;
      }
    } else {
      // TODO: this throw omitted the token location
      throw ParseException(
          "Invalid delimiter '${delim.symbol}' after '${context.funcName}'");
    }
  } else {
    throw ParseException("Invalid delimiter type '${delim.runtimeType}'");
  }
}

GreenNode _delimSizeHandler(TexParser parser, FunctionContext context) {
  final delimArg = parser.parseArgNode(mode: Mode.math, optional: false)!;
  final delim = _checkDelimiter(delimArg, context);
  return delim == null
      ? SpaceNode(
          height: Measurement.zero, width: Measurement.zero, mode: Mode.math)
      : SymbolNode(
          symbol: delim,
          overrideAtomType: _delimiterTypes[context.funcName],
          overrideFont: FontOptions(
              fontFamily: 'Size${_delimiterSizes[context.funcName]}'),
        );
}

class _LeftRightRightNode extends TemporaryNode {
  final String? delim;

  _LeftRightRightNode({this.delim});
}

/// KaTeX's \color command will affect the right delimiter.
/// MathJax's \color command will not affect the right delimiter.
/// Here we choose to follow MathJax's behavior because it fits out AST design
/// better. KaTeX's solution is messy.
GreenNode _rightHandler(TexParser parser, FunctionContext context) {
  final delimArg = parser.parseArgNode(mode: Mode.math, optional: false)!;
  return _LeftRightRightNode(
    delim: _checkDelimiter(delimArg, context),
  );
}

GreenNode _leftHandler(TexParser parser, FunctionContext context) {
  final leftArg = parser.parseArgNode(mode: Mode.math, optional: false)!;
  final delim = _checkDelimiter(leftArg, context);
  // Parse out the implicit body
  ++parser.leftrightDepth;
  // parseExpression stops before '\\right'
  final body = parser.parseExpression(breakOnInfix: false);
  --parser.leftrightDepth;
  // Check the next token
  parser.expect('\\right', consume: false);
  // Use parseArgNode instead of parseFunction like KaTeX
  final rightArg = parser.parseFunction(null, null, null);
  final right = assertNodeType<_LeftRightRightNode>(rightArg);

  final splittedBody = [<GreenNode>[]];
  final middles = <String?>[];
  for (final element in body) {
    if (element is _MiddleNode) {
      splittedBody.add([]);
      middles.add(element.delim == '.' ? null : element.delim);
    } else {
      splittedBody.last.add(element);
    }
  }
  return LeftRightNode(
    leftDelim: delim == '.' ? null : delim,
    rightDelim: right.delim == '.' ? null : right.delim,
    body: splittedBody
        .map((part) => part.wrapWithEquationRow())
        .toList(growable: false),
    middle: middles,
  );
}

class _MiddleNode extends TemporaryNode {
  final String? delim;

  _MiddleNode({this.delim});
}

/// Middle can only appear directly between \left and \right. Wrapping \middle
/// will cause error. This is in accordance with MathJax and different from
/// KaTeX, and is more compatible with our AST structure.
GreenNode _middleHandler(TexParser parser, FunctionContext context) {
  final delimArg = parser.parseArgNode(mode: Mode.math, optional: false)!;
  final delim = _checkDelimiter(delimArg, context);
  if (parser.leftrightDepth <= 0) {
    throw ParseException('\\middle without preceding \\left');
  }
  final contexts = parser.argParsingContexts.toList(growable: false);
  final lastContext = contexts[contexts.length - 2];
  if (lastContext.funcName != '\\left') {
    throw ParseException('\\middle must be within \\left and \\right');
  }

  return _MiddleNode(delim: delim);
}
