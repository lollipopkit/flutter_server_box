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

const _operatorNameEntries = {
  ['\\operatorname', '\\operatorname*']:
      FunctionSpec(numArgs: 1, handler: _operatorNameHandler),
};
GreenNode _operatorNameHandler(TexParser parser, FunctionContext context) {
  var name = parser.parseArgNode(mode: null, optional: false)!;
  final scripts =
      parser.parseScripts(allowLimits: context.funcName == '\\operatorname*');
  final body = parser.parseGroup(context.funcName,
          optional: false, greediness: 1, mode: null, consumeSpaces: true) ??
      EquationRowNode.empty();

  name = StyleNode(
    children: name.expandEquationRow(),
    optionsDiff: OptionsDiff(
      mathFontOptions: texMathFontOptions['\\mathrm'],
    ),
  );

  if (!scripts.empty) {
    if (scripts.limits == true) {
      name = scripts.superscript != null
          ? OverNode(
              base: name.wrapWithEquationRow(),
              above: scripts.superscript!,
            )
          : name;
      name = scripts.subscript != null
          ? UnderNode(
              base: name.wrapWithEquationRow(),
              below: scripts.subscript!,
            )
          : name;
    } else {
      name = MultiscriptsNode(
        base: name.wrapWithEquationRow(),
        sub: scripts.subscript,
        sup: scripts.superscript,
      );
    }
  }

  return FunctionNode(
    functionName: name.wrapWithEquationRow(),
    argument: body.wrapWithEquationRow(),
  );
}
