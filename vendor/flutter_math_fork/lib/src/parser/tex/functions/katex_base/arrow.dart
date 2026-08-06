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

const _arrowEntries = {
  [
    '\\xleftarrow', '\\xrightarrow', '\\xLeftarrow', '\\xRightarrow',
    '\\xleftrightarrow', '\\xLeftrightarrow', '\\xhookleftarrow',
    '\\xhookrightarrow', '\\xmapsto', '\\xrightharpoondown',
    '\\xrightharpoonup', '\\xleftharpoondown', '\\xleftharpoonup',
    '\\xrightleftharpoons', '\\xleftrightharpoons', '\\xlongequal',
    '\\xtwoheadrightarrow', '\\xtwoheadleftarrow', '\\xtofrom',
    // The next 3 functions are here to support the mhchem extension.
    // Direct use of these functions is discouraged and may break someday.
    '\\xrightleftarrows', '\\xrightequilibrium', '\\xleftequilibrium',
  ]: FunctionSpec(
    numArgs: 1,
    numOptionalArgs: 1,
    handler: _arrowHandler,
  )
};

const arrowCommandMapping = {
  '\\xleftarrow': '\u2190',
  '\\xrightarrow': '\u2192',
  '\\xleftrightarrow': '\u2194',

  '\\xLeftarrow': '\u21d0',
  '\\xRightarrow': '\u21d2',
  '\\xLeftrightarrow': '\u21d4',

  '\\xhookleftarrow': '\u21a9',
  '\\xhookrightarrow': '\u21aa',

  '\\xmapsto': '\u21a6',

  '\\xrightharpoondown': '\u21c1',
  '\\xrightharpoonup': '\u21c0',
  '\\xleftharpoondown': '\u21bd',
  '\\xleftharpoonup': '\u21bc',
  '\\xrightleftharpoons': '\u21cc',
  '\\xleftrightharpoons': '\u21cb',

  '\\xlongequal': '=',

  '\\xtwoheadleftarrow': '\u219e',
  '\\xtwoheadrightarrow': '\u21a0',

  '\\xtofrom': '\u21c4',
  '\\xrightleftarrows': '\u21c4',
  '\\xrightequilibrium': '\u21cc', // Not a perfect match.
  '\\xleftequilibrium': '\u21cb', // None better available.
};

GreenNode _arrowHandler(TexParser parser, FunctionContext context) {
  final below = parser.parseArgNode(mode: null, optional: true);
  final above = parser.parseArgNode(mode: null, optional: false)!;
  return StretchyOpNode(
    above: above.wrapWithEquationRow(),
    below: below?.wrapWithEquationRow(),
    symbol: arrowCommandMapping[context.funcName] ?? context.funcName,
  );
}
