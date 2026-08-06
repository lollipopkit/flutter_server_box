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

import '../../../ast/nodes/equation_array.dart';
import '../../../ast/nodes/left_right.dart';
import '../../../ast/nodes/matrix.dart';
import '../../../ast/nodes/space.dart';
import '../../../ast/nodes/style.dart';
import '../../../ast/nodes/symbol.dart';
import '../../../ast/options.dart';
import '../../../ast/size.dart';
import '../../../ast/style.dart';
import '../../../ast/syntax_tree.dart';
import '../../../ast/types.dart';
import '../define_environment.dart';
import '../functions/katex_base.dart';
import '../macros.dart';
import '../parse_error.dart';
import '../parser.dart';
import 'array.dart';

const eqnArrayEntries = {
  [
    'cases',
    'dcases',
    'rcases',
    'drcases',
  ]: EnvSpec(
    numArgs: 0,
    handler: _casesHandler,
  ),
  ['aligned']: EnvSpec(
    numArgs: 0,
    handler: _alignedHandler,
  ),
  // ['gathered']: EnvSpec(numArgs: 0, handler: _gatheredHandler),
  ['alignedat']: EnvSpec(numArgs: 1, handler: _alignedAtHandler),
};

GreenNode _casesHandler(TexParser parser, EnvContext context) {
  final body = parseEqnArray(
    parser,
    concatRow: (cells) {
      final children = [
        SpaceNode.alignerOrSpacer(),
        if (cells.length >= 1) ...cells[0].children,
        if (cells.length > 1) SpaceNode.alignerOrSpacer(),
        if (cells.length > 1)
          SpaceNode(height: Measurement.zero, width: 1.0.em, mode: Mode.math),
      ];
      for (var i = 1; i < cells.length; i++) {
        children.add(SpaceNode.alignerOrSpacer());
        children.addAll(cells[i].children);
        children.add(SpaceNode.alignerOrSpacer());
      }
      if (context.envName == 'dcases' || context.envName == 'drcases') {
        return EquationRowNode(children: [
          StyleNode(
            optionsDiff: OptionsDiff(style: MathStyle.display),
            children: children,
          )
        ]);
      } else {
        return EquationRowNode(children: children);
      }
    },
  );
  if (context.envName == 'rcases' || context.envName == 'drcases') {
    return LeftRightNode(
      leftDelim: null,
      rightDelim: '}',
      body: [body.wrapWithEquationRow()],
    );
  } else {
    return LeftRightNode(
      leftDelim: '{',
      rightDelim: null,
      body: [body.wrapWithEquationRow()],
    );
  }
}

GreenNode _alignedHandler(TexParser parser, EnvContext context) =>
    parseEqnArray(
      parser,
      addJot: true,
      concatRow: (cells) {
        final expanded = cells
            .expand((cell) => [...cell.children, SpaceNode.alignerOrSpacer()])
            .toList(growable: true);
        return EquationRowNode(children: expanded);
      },
    );

// GreenNode _gatheredHandler(TexParser parser, EnvContext context) {}

GreenNode _alignedAtHandler(TexParser parser, EnvContext context) {
  final arg = parser.parseArgNode(mode: null, optional: false);
  final numNode = assertNodeType<EquationRowNode>(arg);
  final string = numNode.children
      .map((e) => assertNodeType<SymbolNode>(e).symbol)
      .join('');
  final cols = int.tryParse(string);
  if (cols == null) {
    throw ParseException('Invalid argument for environment: alignedat');
  }
  return parseEqnArray(
    parser,
    addJot: true,
    concatRow: (cells) {
      if (cells.length > 2 * cols) {
        throw ParseException('Too many math in a row: '
            'expected ${2 * cols}, but got ${cells.length}');
      }
      final expanded = cells
          .expand((cell) => [...cell.children, SpaceNode.alignerOrSpacer()])
          .toList(growable: true);
      return EquationRowNode(children: expanded);
    },
  );
}

EquationArrayNode parseEqnArray(
  TexParser parser, {
  bool addJot = false,
  required EquationRowNode Function(List<EquationRowNode> cells) concatRow,
}) {
  // Parse body of array with \\ temporarily mapped to \cr
  parser.macroExpander.beginGroup();
  parser.macroExpander.macros.set('\\\\', MacroDefinition.fromString('\\cr'));

  // Get current arraystretch if it's not set by the environment
  double? arrayStretch = 1.0;
  // if (arrayStretch == null) {
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
  // }

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

    final cell = cellBody.wrapWithEquationRow();
    row.add(cell);

    final next = parser.fetch().text;
    if (next == '&') {
      parser.consume();
    } else if (next == '\\end') {
      // Arrays terminate newlines with `\crcr` which consumes a `\cr` if
      // the last line is empty.
      // NOTE: Currently, `cell` is the last item added into `row`.
      if (row.length == 1 && cell is StyleNode && cell.children.isEmpty) {
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

  final rows = body.map<EquationRowNode>(concatRow).toList();

  return EquationArrayNode(
    arrayStretch: arrayStretch,
    hlines: hLinesBeforeRow,
    rowSpacings: rowGaps,
    addJot: addJot,
    body: rows,
  );
}
