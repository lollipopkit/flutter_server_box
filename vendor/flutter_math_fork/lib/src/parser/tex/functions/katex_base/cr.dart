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

const _crEntries = {
  ['\\cr', '\\newline']: FunctionSpec(
    numArgs: 0,
    numOptionalArgs: 1,
    allowedInText: true,
    handler: _crHandler,
  ),
};

class CrNode extends TemporaryNode {
  final bool newLine;
  final bool newRow;
  final Measurement? size;
  CrNode({
    required this.newLine,
    required this.newRow,
    this.size,
  });
}

GreenNode _crHandler(TexParser parser, FunctionContext context) {
  final size = parser.parseArgSize(optional: true);
  final newRow = context.funcName == '\\cr';
  var newLine = false;
  if (!newRow) {
    if (parser.settings.displayMode &&
        parser.settings.useStrictBehavior(
            'newLineInDisplayMode',
            'In LaTeX, \\\\ or \\newline '
                'does nothing in display mode')) {
      newLine = false;
    } else {
      newLine = true;
    }
  }
  return CrNode(newLine: newLine, newRow: newRow, size: size);
}
