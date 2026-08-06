import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../ast/options.dart';
import '../../ast/size.dart';
import 'svg_geomertry.dart';
import 'svg_string.dart';

class _KatexImagesData {
  final List<String> paths;
  final double minWidth;
  final double viewBoxHeight;
  final Alignment? align;
  const _KatexImagesData(this.paths, this.minWidth, this.viewBoxHeight,
      [this.align]);
}

// \[(\[[^\]]*\]),([0-9.\s]*),([0-9.\s]*)(,? ?'[a-z]*'|)\]
// _KatexImagesData($1, $2, $3$4)
// xMinyMin -> Alignment.topLeft, xMaxyMin -> Alignment.topRight
const katexImagesData = {
  'overrightarrow':
      _KatexImagesData(['rightarrow'], 0.888, 522, Alignment.topRight),
  'overleftarrow':
      _KatexImagesData(['leftarrow'], 0.888, 522, Alignment.topLeft),
  'underrightarrow':
      _KatexImagesData(['rightarrow'], 0.888, 522, Alignment.topRight),
  'underleftarrow':
      _KatexImagesData(['leftarrow'], 0.888, 522, Alignment.topLeft),
  'xrightarrow':
      _KatexImagesData(['rightarrow'], 1.469, 522, Alignment.topRight),
  'xleftarrow': _KatexImagesData(['leftarrow'], 1.469, 522, Alignment.topLeft),
  'Overrightarrow':
      _KatexImagesData(['doublerightarrow'], 0.888, 560, Alignment.topRight),
  'xRightarrow':
      _KatexImagesData(['doublerightarrow'], 1.526, 560, Alignment.topRight),
  'xLeftarrow':
      _KatexImagesData(['doubleleftarrow'], 1.526, 560, Alignment.topLeft),
  'overleftharpoon':
      _KatexImagesData(['leftharpoon'], 0.888, 522, Alignment.topLeft),
  'xleftharpoonup':
      _KatexImagesData(['leftharpoon'], 0.888, 522, Alignment.topLeft),
  'xleftharpoondown':
      _KatexImagesData(['leftharpoondown'], 0.888, 522, Alignment.topLeft),
  'overrightharpoon':
      _KatexImagesData(['rightharpoon'], 0.888, 522, Alignment.topRight),
  'xrightharpoonup':
      _KatexImagesData(['rightharpoon'], 0.888, 522, Alignment.topRight),
  'xrightharpoondown':
      _KatexImagesData(['rightharpoondown'], 0.888, 522, Alignment.topRight),
  'xlongequal': _KatexImagesData(['longequal'], 0.888, 334, Alignment.topLeft),
  'xtwoheadleftarrow':
      _KatexImagesData(['twoheadleftarrow'], 0.888, 334, Alignment.topLeft),
  'xtwoheadrightarrow':
      _KatexImagesData(['twoheadrightarrow'], 0.888, 334, Alignment.topRight),

  'overleftrightarrow':
      _KatexImagesData(['leftarrow', 'rightarrow'], 0.888, 522),
  'overbrace':
      _KatexImagesData(['leftbrace', 'midbrace', 'rightbrace'], 1.6, 548),
  'underbrace': _KatexImagesData(
      ['leftbraceunder', 'midbraceunder', 'rightbraceunder'], 1.6, 548),
  'underleftrightarrow':
      _KatexImagesData(['leftarrow', 'rightarrow'], 0.888, 522),
  'xleftrightarrow': _KatexImagesData(['leftarrow', 'rightarrow'], 1.75, 522),
  'xLeftrightarrow':
      _KatexImagesData(['doubleleftarrow', 'doublerightarrow'], 1.75, 560),
  'xrightleftharpoons':
      _KatexImagesData(['leftharpoondownplus', 'rightharpoonplus'], 1.75, 716),
  'xleftrightharpoons':
      _KatexImagesData(['leftharpoonplus', 'rightharpoondownplus'], 1.75, 716),
  'xhookleftarrow': _KatexImagesData(['leftarrow', 'righthook'], 1.08, 522),
  'xhookrightarrow': _KatexImagesData(['lefthook', 'rightarrow'], 1.08, 522),
  'overlinesegment':
      _KatexImagesData(['leftlinesegment', 'rightlinesegment'], 0.888, 522),
  'underlinesegment':
      _KatexImagesData(['leftlinesegment', 'rightlinesegment'], 0.888, 522),
  'overgroup': _KatexImagesData(['leftgroup', 'rightgroup'], 0.888, 342),
  'undergroup':
      _KatexImagesData(['leftgroupunder', 'rightgroupunder'], 0.888, 342),
  'xmapsto': _KatexImagesData(['leftmapsto', 'rightarrow'], 1.5, 522),
  'xtofrom': _KatexImagesData(['leftToFrom', 'rightToFrom'], 1.75, 528),

  // The next three arrows are from the mhchem package.
  // In mhchem.sty, min-length is 2.0em. But these arrows might appear in the
  // document as \xrightarrow or \xrightleftharpoons. Those have
  // min-length = 1.75em, so we set min-length on these next three to match.
  'xrightleftarrows':
      _KatexImagesData(['baraboveleftarrow', 'rightarrowabovebar'], 1.75, 901),
  'xrightequilibrium': _KatexImagesData(
      ['baraboveshortleftharpoon', 'rightharpoonaboveshortbar'], 1.75, 716),
  'xleftequilibrium': _KatexImagesData(
      ['shortbaraboveleftharpoon', 'shortrightharpoonabovebar'], 1.75, 716),
};

Widget strechySvgSpan(String name, double width, MathOptions options) {
  var viewBoxWidth = 400000.0;
  if (const {'widehat', 'widecheck', 'widetilde', 'utilde'}.contains(name)) {
    double viewBoxHeight;
    String pathName;
    double height;
    final effCharNum = (width / 1.0.cssEm.toLpUnder(options)).ceil();
    if (effCharNum > 5) {
      if (name == 'widehat' || name == 'widecheck') {
        viewBoxHeight = 420;
        viewBoxWidth = 2364;
        height = 0.42;
        pathName = '${name}4';
      } else {
        viewBoxHeight = 312;
        viewBoxWidth = 2340;
        height = 0.34;
        pathName = 'tilde4';
      }
    } else {
      final imgIndex = const [1, 1, 2, 2, 3, 3][effCharNum];
      if (name == 'widehat' || name == 'widecheck') {
        viewBoxWidth = const <double>[0, 1062, 2364, 2364, 2364][imgIndex];
        viewBoxHeight = const <double>[0, 239, 300, 360, 420][imgIndex];
        height = const <double>[0, 0.24, 0.3, 0.3, 0.36, 0.42][imgIndex];
        pathName = '$name$imgIndex';
      } else {
        viewBoxWidth = const <double>[0, 600, 1033, 2339, 2340][imgIndex];
        viewBoxHeight = const <double>[0, 260, 286, 306, 312][imgIndex];
        height = const <double>[0, 0.26, 0.286, 0.3, 0.306, 0.34][imgIndex];
        pathName = 'tilde$imgIndex';
      }
    }
    height = height.cssEm.toLpUnder(options);
    return svgWidgetFromPath(
      svgPaths[pathName]!,
      Size(width, height),
      Rect.fromLTWH(0, 0, viewBoxWidth, viewBoxHeight),
      options.color,
    );
  } else {
    final data = katexImagesData[name];
    if (data == null) {
      throw ArgumentError.value(name, 'name', 'Invalid stretchy svg name');
    }
    final height = (data.viewBoxHeight / 1000).cssEm.toLpUnder(options);
    final numSvgChildren = data.paths.length;
    final actualWidth = math.max(width, data.minWidth.cssEm.toLpUnder(options));
    List<Alignment> aligns;
    List<double> widths;

    switch (numSvgChildren) {
      case 1:
        aligns = [data.align!]; // Single svg must specify their alignment
        widths = [actualWidth];
        break;
      case 2:
        aligns = const [Alignment.topLeft, Alignment.topRight];
        widths = [actualWidth / 2, actualWidth / 2];
        break;
      case 3:
        aligns = const [
          Alignment.topLeft,
          Alignment.topCenter,
          Alignment.topRight
        ];
        widths = [actualWidth / 4, actualWidth / 2, actualWidth / 4];
        break;
      default:
        throw StateError('Bug inside stretchy svg code');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(
        numSvgChildren,
        (index) => svgWidgetFromPath(
          svgPaths[data.paths[index]]!,
          Size(widths[index], height),
          Rect.fromLTWH(0, 0, viewBoxWidth, data.viewBoxHeight),
          options.color,
          align: aligns[index],
          fit: BoxFit.cover, // BoxFit.fitHeight, // For DomCanvas compatibility
        ),
        growable: false,
      ),
    );
  }
}

const stretchyCodePoint = {
  'widehat': '^',
  'widecheck': 'ˇ',
  'widetilde': '~',
  'utilde': '~',
  'overleftarrow': '\u2190',
  'underleftarrow': '\u2190',
  'xleftarrow': '\u2190',
  'overrightarrow': '\u2192',
  'underrightarrow': '\u2192',
  'xrightarrow': '\u2192',
  'underbrace': '\u23df',
  'overbrace': '\u23de',
  'overgroup': '\u23e0',
  'undergroup': '\u23e1',
  'overleftrightarrow': '\u2194',
  'underleftrightarrow': '\u2194',
  'xleftrightarrow': '\u2194',
  'Overrightarrow': '\u21d2',
  'xRightarrow': '\u21d2',
  'overleftharpoon': '\u21bc',
  'xleftharpoonup': '\u21bc',
  'overrightharpoon': '\u21c0',
  'xrightharpoonup': '\u21c0',
  'xLeftarrow': '\u21d0',
  'xLeftrightarrow': '\u21d4',
  'xhookleftarrow': '\u21a9',
  'xhookrightarrow': '\u21aa',
  'xmapsto': '\u21a6',
  'xrightharpoondown': '\u21c1',
  'xleftharpoondown': '\u21bd',
  'xrightleftharpoons': '\u21cc',
  'xleftrightharpoons': '\u21cb',
  'xtwoheadleftarrow': '\u219e',
  'xtwoheadrightarrow': '\u21a0',
  'xlongequal': '=',
  'xtofrom': '\u21c4',
  'xrightleftarrows': '\u21c4',
  'xrightequilibrium': '\u21cc', // Not a perfect match.
  'xleftequilibrium': '\u21cb', // None better available.
};
