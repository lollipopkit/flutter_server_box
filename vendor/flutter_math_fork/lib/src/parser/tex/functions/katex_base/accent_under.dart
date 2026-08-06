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

const _accentUnderEntries = {
  [
    '\\underleftarrow',
    '\\underrightarrow',
    '\\underleftrightarrow',
    '\\undergroup',
    // '\\underlinesegment': ,
    '\\utilde',

    '\\underline'
  ]: FunctionSpec(numArgs: 1, handler: _accentUnderHandler),
};

const accentUnderMapping = {
  '\\underleftarrow': '\u2190',
  '\\underrightarrow': '\u2192',
  '\\underleftrightarrow': '\u2194',
  '\\undergroup': '\u23e0',
  // '\\underlinesegment',
  '\\utilde': '\u007e',

  '\\underline': '\u00af'
};

GreenNode _accentUnderHandler(TexParser parser, FunctionContext context) {
  final base = parser.parseArgNode(mode: null, optional: false)!;
  return AccentUnderNode(
    base: base.wrapWithEquationRow(),
    label: accentUnderMapping[context.funcName]!,
  );
}
