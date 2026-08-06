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

const _accentEntries = {
  [
    '\\acute',
    '\\grave',
    '\\ddot',
    '\\tilde',
    '\\bar',
    '\\breve',
    '\\check',
    '\\hat',
    '\\vec',
    '\\dot',
    '\\mathring',
    '\\widecheck',
    '\\widehat',
    '\\widetilde',
    '\\overrightarrow',
    '\\overleftarrow',
    '\\Overrightarrow',
    '\\overleftrightarrow',
    // '\\overgroup',
    // '\\overlinesegment',
    '\\overleftharpoon',
    '\\overrightharpoon',

    '\\overline'
  ]: FunctionSpec(
    numArgs: 1,
    handler: _accentHandler,
  ),
  [
    "\\'",
    '\\`',
    '\\^',
    '\\~',
    '\\=',
    '\\u',
    '\\.',
    '\\"',
    '\\r',
    '\\H',
    '\\v',
    // '\\textcircled',
  ]: FunctionSpec(
    numArgs: 1,
    allowedInMath: false,
    allowedInText: true,
    handler: _textAccentHandler,
  ),
};

const nonStretchyAccents = {
  '\\acute',
  '\\grave',
  '\\ddot',
  '\\tilde',
  '\\bar',
  '\\breve',
  '\\check',
  '\\hat',
  '\\vec',
  '\\dot',
  '\\mathring',
};

const shiftyAccents = {
  '\\widehat',
  '\\widetilde',
  '\\widecheck',
};

const accentCommandMapping = {
  '\\acute': '\u00B4',
  '\\grave': '\u0060',
  '\\ddot': '\u00A8',
  '\\tilde': '\u007E',
  '\\bar': '\u00AF',
  '\\breve': '\u02D8',
  '\\check': '\u02C7',
  '\\hat': '\u005E',
  '\\vec': '\u2192',
  '\\dot': '\u02D9',
  '\\mathring': '\u02da',
  '\\widecheck': '\u02c7',
  '\\widehat': '\u005e',
  '\\widetilde': '\u007e',
  '\\overrightarrow': '\u2192',
  '\\overleftarrow': '\u2190',
  '\\Overrightarrow': '\u21d2',
  '\\overleftrightarrow': '\u2194',
  // '\\overgroup': '\u',
  // '\\overlinesegment': '\u',
  '\\overleftharpoon': '\u21bc',
  '\\overrightharpoon': '\u21c0',
  "\\'": '\u00b4',
  '\\`': '\u0060',
  '\\^': '\u005e',
  '\\~': '\u007e',
  '\\=': '\u00af',
  '\\u': '\u02d8',
  '\\.': '\u02d9',
  '\\"': '\u00a8',
  '\\r': '\u02da',
  '\\H': '\u02dd',
  '\\v': '\u02c7',
  // '\\textcircled': '\u',

  '\\overline': '\u00AF',
};

GreenNode _accentHandler(TexParser parser, FunctionContext context) {
  final base = parser.parseArgNode(mode: Mode.math, optional: false)!;

  final isStretchy = !nonStretchyAccents.contains(context.funcName);
  final isShifty = !isStretchy || shiftyAccents.contains(context.funcName);

  return AccentNode(
    base: base.wrapWithEquationRow(),
    label: accentCommandMapping[context.funcName]!,
    isStretchy: isStretchy,
    isShifty: isShifty,
  );
}

const textUnicodeAccentMapping = {
  '\\`': '\u0300',
  '\\"': '\u0308',
  '\\~': '\u0303',
  '\\=': '\u0304',
  "\\'": '\u0301',
  '\\u': '\u0306',
  '\\v': '\u030c',
  '\\^': '\u0302',
  '\\.': '\u0307',
  '\\r': '\u030a',
  '\\H': '\u030b',
  // '\\textcircled': '\u',
};
GreenNode _textAccentHandler(TexParser parser, FunctionContext context) {
  final base = parser.parseArgNode(mode: null, optional: false)!;
  if (base is SymbolNode) {
    return base.withSymbol(
      base.symbol + textUnicodeAccentMapping[context.funcName]!,
    );
  }
  if (base is EquationRowNode && base.children.length == 1) {
    final node = base.children[0];
    if (node is SymbolNode) {
      return node.withSymbol(
        node.symbol + textUnicodeAccentMapping[context.funcName]!,
      );
    }
  }
  return AccentNode(
    base: base.wrapWithEquationRow(),
    label: accentCommandMapping[context.funcName]!,
    isStretchy: false,
    isShifty: true,
  );
}
