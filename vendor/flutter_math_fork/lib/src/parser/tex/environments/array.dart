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

import 'package:collection/collection.dart';

import '../../../ast/nodes/left_right.dart';
import '../../../ast/nodes/matrix.dart';
import '../../../ast/nodes/style.dart';
import '../../../ast/nodes/symbol.dart';
import '../../../ast/options.dart';
import '../../../ast/size.dart';
import '../../../ast/style.dart';
import '../../../ast/syntax_tree.dart';
import '../define_environment.dart';
import '../functions/katex_base.dart';
import '../macros.dart';
import '../parse_error.dart';
import '../parser.dart';

const arrayEntries = {
  [
    'array',
    'darray',
  ]: EnvSpec(
    numArgs: 1,
    handler: _arrayHandler,
  ),
  [
    'matrix',
    'pmatrix',
    'bmatrix',
    'Bmatrix',
    'vmatrix',
    'Vmatrix',
  ]: EnvSpec(
    numArgs: 0,
    handler: _matrixHandler,
  ),
  ['smallmatrix']: EnvSpec(numArgs: 0, handler: _smallMatrixHandler),
  ['subarray']: EnvSpec(numArgs: 1, handler: _subArrayHandler),
};

enum ColSeparationType {
  align,
  alignat,
  small,
}

List<MatrixSeparatorStyle> getHLines(TexParser parser) {
  // Return an array. The array length = number of hlines.
  // Each element in the array tells if the line is dashed.
  final hlineInfo = <MatrixSeparatorStyle>[];
  parser.consumeSpaces();
  var next = parser.fetch().text;
  while (next == '\\hline' || next == '\\hdashline') {
    parser.consume();
    hlineInfo.add(next == '\\hdashline'
        ? MatrixSeparatorStyle.dashed
        : MatrixSeparatorStyle.solid);
    parser.consumeSpaces();
    next = parser.fetch().text;
  }
  return hlineInfo;
}

/// Parse the body of the environment, with rows delimited by \\ and
/// columns delimited by &, and create a nested list in row-major order
/// with one group per cell.  If given an optional argument style
/// ('text', 'display', etc.), then each cell is cast into that style.
MatrixNode parseArray(
  TexParser parser, {
  bool hskipBeforeAndAfter = false,
  double? arrayStretch,
  List<MatrixSeparatorStyle> separators = const [],
  List<MatrixColumnAlign> colAligns = const [],
  MathStyle? style,
  bool isSmall = false,
}) {
  // Parse body of array with \\ temporarily mapped to \cr
  parser.macroExpander.beginGroup();
  parser.macroExpander.macros.set('\\\\', MacroDefinition.fromString('\\cr'));

  // Get current arraystretch if it's not set by the environment
  if (arrayStretch == null) {
    final stretch = parser.macroExpander.expandMacroAsText('\\arraystretch');
    if (stretch == null) {
      // Default \arraystretch from lttab.dtx
      arrayStretch = 1.0;
    } else {
      arrayStretch = double.tryParse(stretch);
      if (arrayStretch == null || arrayStretch < 0) {
        throw ParseException('Invalid \\arraystretch: $stretch');
      }
    }
  }

  // Start group for first cell
  parser.macroExpander.beginGroup();

  var row = <EquationRowNode>[];
  final body = [row];
  final rowGaps = <Measurement>[];
  final hLinesBeforeRow = <MatrixSeparatorStyle>[];

  // Test for \hline at the top of the array.
  hLinesBeforeRow
      .add(getHLines(parser).lastOrNull ?? MatrixSeparatorStyle.none);

  while (true) {
    // Parse each cell in its own group (namespace)
    final cellBody =
        parser.parseExpression(breakOnInfix: false, breakOnTokenText: '\\cr');
    parser.macroExpander.endGroup();
    parser.macroExpander.beginGroup();

    final cell = style == null
        ? cellBody.wrapWithEquationRow()
        : StyleNode(
            children: cellBody,
            optionsDiff: OptionsDiff(style: style),
          ).wrapWithEquationRow();
    row.add(cell);

    final next = parser.fetch().text;
    if (next == '&') {
      parser.consume();
    } else if (next == '\\end') {
      // Arrays terminate newlines with `\crcr` which consumes a `\cr` if
      // the last line is empty.
      // NOTE: Currently, `cell` is the last item added into `row`.
      if (row.length == 1 && cellBody.isEmpty) {
        body.removeLast();
      }
      if (hLinesBeforeRow.length < body.length + 1) {
        hLinesBeforeRow.add(MatrixSeparatorStyle.none);
      }
      break;
    } else if (next == '\\cr') {
      final cr = assertNodeType<CrNode>(parser.parseFunction(null, null, null));
      rowGaps.add(cr.size ?? Measurement.zero);

      // check for \hline(s) following the row separator
      hLinesBeforeRow
          .add(getHLines(parser).lastOrNull ?? MatrixSeparatorStyle.none);

      row = [];
      body.add(row);
    } else {
      throw ParseException(
          'Expected & or \\\\ or \\cr or \\end', parser.nextToken);
    }
  }

  // End cell group
  parser.macroExpander.endGroup();
  // End array group defining \\
  parser.macroExpander.endGroup();

  return MatrixNode(
    body: body,
    vLines: separators,
    columnAligns: colAligns,
    rowSpacings: rowGaps,
    arrayStretch: arrayStretch,
    hLines: hLinesBeforeRow,
    hskipBeforeAndAfter: hskipBeforeAndAfter,
    isSmall: isSmall,
  );
}

/// Decides on a style for cells in an array according to whether the given
/// environment name starts with the letter 'd'.
MathStyle _dCellStyle(String envName) =>
    envName.substring(0, 1) == 'd' ? MathStyle.display : MathStyle.text;

// const _alignMap = {
//   'c': 'center',
//   'l': 'left',
//   'r': 'right',
// };

// class ColumnConf {
//   final List<String> separators;
//   final List<_AlignSpec> aligns;
//   // final bool hskipBeforeAndAfter;
//   // final double arrayStretch;
//   ColumnConf({
//     required this.separators,
//     required this.aligns,
//     // this.hskipBeforeAndAfter = false,
//     // this.arrayStretch = 1,
//   });
// }

GreenNode _arrayHandler(TexParser parser, EnvContext context) {
  final symArg = parser.parseArgNode(mode: null, optional: false);
  final colalign = symArg is SymbolNode
      ? [symArg]
      : assertNodeType<EquationRowNode>(symArg).children;
  final separators = <MatrixSeparatorStyle>[];
  final aligns = <MatrixColumnAlign>[];
  var alignSpecified = true;
  var lastIsSeparator = false;

  for (final nde in colalign) {
    final node = assertNodeType<SymbolNode>(nde);
    final ca = node.symbol;
    switch (ca) {
      //ignore_for_file: switch_case_completes_normally
      case 'l':
      case 'c':
      case 'r':
        aligns.add(const {
          'l': MatrixColumnAlign.left,
          'c': MatrixColumnAlign.center,
          'r': MatrixColumnAlign.right,
        }[ca]!);
        if (alignSpecified) {
          separators.add(MatrixSeparatorStyle.none);
        }
        alignSpecified = true;
        lastIsSeparator = false;
        break;
      case '|':
      case ':':
        if (alignSpecified) {
          separators.add(const {
            '|': MatrixSeparatorStyle.solid,
            ':': MatrixSeparatorStyle.dashed,
          }[ca]!);
          // aligns.add(MatrixColumnAlign.center);
        }
        alignSpecified = false;
        lastIsSeparator = true;
        break;
      default:
        throw ParseException('Unknown column alignment: $ca');
    }
  }
  if (!lastIsSeparator) {
    separators.add(MatrixSeparatorStyle.none);
  }
  return parseArray(
    parser,
    separators: separators,
    colAligns: aligns,
    hskipBeforeAndAfter: true,
    style: _dCellStyle(context.envName),
  );
}

GreenNode _matrixHandler(TexParser parser, EnvContext context) {
  final delimiters = const {
    'matrix': null,
    'pmatrix': ['(', ')'],
    'bmatrix': ['[', ']'],
    'Bmatrix': ['{', '}'],
    'vmatrix': ['|', '|'],
    'Vmatrix': ['\u2223', '\u2223'],
  }[context.envName];
  final res = parseArray(
    parser,
    hskipBeforeAndAfter: false,
    style: _dCellStyle(context.envName),
  );
  return delimiters == null
      ? res
      : LeftRightNode(
          leftDelim: delimiters[0],
          rightDelim: delimiters[1],
          body: [
            [res].wrapWithEquationRow()
          ],
        );
}

GreenNode _smallMatrixHandler(TexParser parser, EnvContext context) =>
    parseArray(
      parser,
      arrayStretch: 0.5,
      style: MathStyle.script,
      isSmall: true,
    );

GreenNode _subArrayHandler(TexParser parser, EnvContext context) {
  // Parsing of {subarray} is similar to {array}
  final symArg = parser.parseArgNode(mode: null, optional: false);
  final colalign = symArg is SymbolNode
      ? [symArg]
      : assertNodeType<EquationRowNode>(symArg).children;
  // final separators = <MatrixSeparatorStyle>[];
  final aligns = <MatrixColumnAlign>[];
  for (final nde in colalign) {
    final node = assertNodeType<SymbolNode>(nde);
    final ca = node.symbol;
    if (ca == 'l' || ca == 'c') {
      aligns.add(ca == 'l' ? MatrixColumnAlign.left : MatrixColumnAlign.center);
    } else {
      throw ParseException('Unknown column alignment: $ca');
    }
  }
  if (aligns.length > 1) {
    throw ParseException('{subarray} can contain only one column');
  }
  final res = parseArray(
    parser,
    colAligns: aligns,
    hskipBeforeAndAfter: false,
    arrayStretch: 0.5,
    style: MathStyle.script,
  );
  if (res.body[0].length > 1) {
    throw ParseException('{subarray} can contain only one column');
  }
  return res;
}
