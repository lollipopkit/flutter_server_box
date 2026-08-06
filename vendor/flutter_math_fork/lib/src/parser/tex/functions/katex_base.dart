library katex_base;

import '../../../ast/nodes/accent.dart';
import '../../../ast/nodes/accent_under.dart';
import '../../../ast/nodes/enclosure.dart';
import '../../../ast/nodes/frac.dart';
import '../../../ast/nodes/function.dart';
import '../../../ast/nodes/left_right.dart';
import '../../../ast/nodes/multiscripts.dart';
import '../../../ast/nodes/nary_op.dart';
import '../../../ast/nodes/over.dart';
import '../../../ast/nodes/phantom.dart';
import '../../../ast/nodes/raise_box.dart';
import '../../../ast/nodes/space.dart';
import '../../../ast/nodes/sqrt.dart';
import '../../../ast/nodes/stretchy_op.dart';
import '../../../ast/nodes/style.dart';
import '../../../ast/nodes/symbol.dart';
import '../../../ast/nodes/under.dart';
import '../../../ast/options.dart';
import '../../../ast/size.dart';
import '../../../ast/style.dart';
import '../../../ast/syntax_tree.dart';
import '../../../ast/types.dart';
import '../define_environment.dart';
import '../font.dart';
import '../functions.dart';
import '../parse_error.dart';
import '../parser.dart';
import '../symbols.dart';

part 'katex_base/accent.dart';
part 'katex_base/accent_under.dart';
part 'katex_base/array.dart';
part 'katex_base/arrow.dart';
part 'katex_base/break.dart';
part 'katex_base/char.dart';
part 'katex_base/color.dart';
part 'katex_base/cr.dart';
part 'katex_base/delimsizing.dart';
part 'katex_base/enclose.dart';
part 'katex_base/environment.dart';
part 'katex_base/font.dart';
part 'katex_base/genfrac.dart';
part 'katex_base/horiz_brace.dart';
part 'katex_base/kern.dart';
part 'katex_base/math.dart';
part 'katex_base/mclass.dart';
part 'katex_base/op.dart';
part 'katex_base/operator_name.dart';
part 'katex_base/phantom.dart';
part 'katex_base/raise_box.dart';
part 'katex_base/rule.dart';
part 'katex_base/sizing.dart';
part 'katex_base/sqrt.dart';
part 'katex_base/styling.dart';
part 'katex_base/text.dart';
part 'katex_base/underover.dart';

const katexBaseFunctionEntries = {
  ..._accentEntries,
  ..._accentUnderEntries,
  ..._arrowEntries,
  ..._arrayEntries,
  ..._breakEntries,
  ..._charEntries,
  ..._colorEntries,
  ..._crEntries,
  ..._delimSizingEntries,
  ..._encloseEntries,
  ..._environmentEntries,
  ..._fontEntries,
  ..._genfracEntries,
  ..._horizBraceEntries,
  ..._kernEntries,
  ..._mathEntries,
  ..._mclassEntries,
  ..._opEntries,
  ..._operatorNameEntries,
  ..._phantomEntries,
  ..._raiseBoxEntries,
  ..._ruleEntries,
  ..._sizingEntries,
  ..._sqrtEntries,
  ..._stylingEntries,
  ..._textEntries,
  ..._underOverEntries,
};
