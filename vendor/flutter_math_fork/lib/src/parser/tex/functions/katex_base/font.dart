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

const _fontEntries = {
  [
    // styles, except \boldsymbol defined below
    '\\mathrm', '\\mathit', '\\mathbf', //'\\mathnormal',

    // families
    '\\mathbb', '\\mathcal', '\\mathfrak', '\\mathscr', '\\mathsf',
    '\\mathtt',

    // aliases, except \bm defined below
    '\\Bbb', '\\bold', '\\frak',
  ]: FunctionSpec(numArgs: 1, greediness: 2, handler: _fontHandler),
  ['\\boldsymbol', '\\bm']:
      FunctionSpec(numArgs: 1, greediness: 2, handler: _boldSymbolHandler),
  ['\\rm', '\\sf', '\\tt', '\\bf', '\\it', '\\cal']:
      FunctionSpec(numArgs: 0, allowedInText: true, handler: _textFontHandler),
};
const fontAliases = {
  '\\Bbb': '\\mathbb',
  '\\bold': '\\mathbf',
  '\\frak': '\\mathfrak',
  '\\bm': '\\boldsymbol',
};

GreenNode _fontHandler(TexParser parser, FunctionContext context) {
  final body = parser.parseArgNode(mode: null, optional: false)!;
  final func = fontAliases.containsKey(context.funcName)
      ? fontAliases[context.funcName]
      : context.funcName;
  return StyleNode(
    children: body.expandEquationRow(),
    optionsDiff: OptionsDiff(
      mathFontOptions: texMathFontOptions[func],
    ),
  );
}

GreenNode _boldSymbolHandler(TexParser parser, FunctionContext context) {
  final body = parser.parseArgNode(mode: null, optional: false)!;
  // TODO
  // amsbsy.sty's \boldsymbol uses \binrel spacing to inherit the
  // argument's bin|rel|ord status
  return StyleNode(
    children: body.expandEquationRow(),
    optionsDiff: OptionsDiff(
      mathFontOptions: texMathFontOptions['\\boldsymbol'],
    ),
  );
}

GreenNode _textFontHandler(TexParser parser, FunctionContext context) {
  final body = parser.parseExpression(
      breakOnInfix: true, breakOnTokenText: context.breakOnTokenText);
  final style = '\\math${context.funcName.substring(1)}';

  return StyleNode(
    children: body,
    optionsDiff: OptionsDiff(
      mathFontOptions: texMathFontOptions[style],
    ),
  );
}
