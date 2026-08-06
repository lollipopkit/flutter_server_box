import 'size.dart';

/// Math styles for equation elements.
///
/// \displaystyle \textstyle etc.
enum MathStyle {
  display,
  displayCramped,
  text,
  textCramped,
  script,
  scriptCramped,
  scriptscript,
  scriptscriptCramped,
}

enum MathStyleDiff {
  sub,
  sup,
  fracNum,
  fracDen,
  cramp,
  text,
  uncramp,
}

MathStyle? parseMathStyle(String string) => const {
      'display': MathStyle.display,
      'displayCramped': MathStyle.displayCramped,
      'text': MathStyle.text,
      'textCramped': MathStyle.textCramped,
      'script': MathStyle.script,
      'scriptCramped': MathStyle.scriptCramped,
      'scriptscript': MathStyle.scriptscript,
      'scriptscriptCramped': MathStyle.scriptscriptCramped,
    }[string];

extension MathStyleExt on MathStyle {
  // MathStyle get pureStyle => MathStyle.values[(this.index / 2).floor()];

  bool get cramped => this.index.isEven;
  int get size => this.index ~/ 2;

  MathStyle reduce(MathStyleDiff? diff) => diff == null
      ? this
      : MathStyle.values[_reduceTable[diff.index][this.index]];

  static const _reduceTable = [
    [4, 5, 4, 5, 6, 7, 6, 7], //sup
    [5, 5, 5, 5, 7, 7, 7, 7], //sub
    [2, 3, 4, 5, 6, 7, 6, 7], //fracNum
    [3, 3, 5, 5, 7, 7, 7, 7], //fracDen
    [1, 1, 3, 3, 5, 5, 7, 7], //cramp
    [0, 1, 2, 3, 2, 3, 2, 3], //text
    [0, 0, 2, 2, 4, 4, 6, 6], //uncramp
  ];
  MathStyle sup() => this.reduce(MathStyleDiff.sup);
  MathStyle sub() => this.reduce(MathStyleDiff.sub);
  MathStyle fracNum() => this.reduce(MathStyleDiff.fracNum);
  MathStyle fracDen() => this.reduce(MathStyleDiff.fracDen);
  MathStyle cramp() => this.reduce(MathStyleDiff.cramp);
  MathStyle atLeastText() => this.reduce(MathStyleDiff.text);
  MathStyle uncramp() => this.reduce(MathStyleDiff.uncramp);

  // MathStyle atLeastText() =>
  //     this.index > MathStyle.textCramped.index ? this : MathStyle.text;

  bool operator >(MathStyle other) => this.index < other.index;
  bool operator <(MathStyle other) => this.index > other.index;
  bool operator >=(MathStyle other) => this.index <= other.index;
  bool operator <=(MathStyle other) => this.index >= other.index;
  bool isTight() => this.size >= 2;
}

extension MathStyleExtOnInt on int {
  MathStyle toMathStyle() => MathStyle.values[(this * 2).clamp(0, 6).toInt()];
}

extension MathStyleExtOnSize on MathSize {
  /// katex/src/Options.js/sizeStyleMap
  MathSize underStyle(MathStyle style) {
    if (style >= MathStyle.textCramped) {
      return this;
    }
    return MathSize.values[_sizeStyleMap[this.index][style.size - 1] - 1];
  }

  static const _sizeStyleMap = [
    [1, 1, 1],
    [2, 1, 1],
    [3, 1, 1],
    [4, 2, 1],
    [5, 2, 1],
    [6, 3, 1],
    [7, 4, 2],
    [8, 6, 3],
    [9, 7, 6],
    [10, 8, 7],
    [11, 10, 9],
  ];
}
