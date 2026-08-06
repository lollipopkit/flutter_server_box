import 'dart:convert';

import 'package:collection/collection.dart';

import '../../ast/syntax_tree.dart';
import '../../ast/types.dart';
import '../../parser/tex/functions.dart';
import '../../parser/tex/settings.dart';
import '../../utils/alpha_numeric.dart';
import '../encoder.dart';
import 'functions.dart';

final texEncodingCache = Expando<EncodeResult>('Tex encoding results');

/// Encodes [GreenNode] into TeX
class TexEncoder extends Converter<GreenNode, String> {
  @override
  String convert(GreenNode input) => input.encodeTeX();
}

extension TexEncoderExt on GreenNode {
  /// Encodes the node into TeX
  String encodeTeX({TexEncodeConf conf = const TexEncodeConf()}) =>
      encodeTex(this).stringify(conf);
}

extension ListTexEncoderExt on List<GreenNode> {
  /// Encode the list of nodes into TeX
  String encodeTex() =>
      this.wrapWithEquationRow().encodeTeX(conf: TexEncodeConf().mathParam());
}

EncodeResult encodeTex(GreenNode node) {
  final cachedRes = texEncodingCache[node];
  if (cachedRes != null) return cachedRes;

  final optimization = optimizationEntries
      .firstWhereOrNull((entry) => entry.matcher.match(node));
  if (optimization != null) {
    optimization.optimize(node);
    final cachedRes = texEncodingCache[node];
    if (cachedRes != null) return cachedRes;
  }

  final type = node.runtimeType;
  final encoderFunction = encoderFunctions[type];
  if (encoderFunction == null) {
    return NonStrictEncodeResult('unknown node type',
        'Unrecognized node type $type encountered during encoding');
  }

  final encodeResult = encoderFunction(node);
  texEncodingCache[node] = encodeResult;
  return encodeResult;
}

class TexEncodeConf extends EncodeConf {
  final Mode mode;
  final bool removeRowBracket;

  const TexEncodeConf({
    this.mode = Mode.math,
    this.removeRowBracket = false,
    Strict strict = Strict.warn,
    StrictFun? strictFun,
  }) : super(strict: strict, strictFun: strictFun);

  static const mathConf = TexEncodeConf();
  static const mathParamConf = TexEncodeConf(removeRowBracket: true);
  static const textConf = TexEncodeConf(mode: Mode.text);
  static const textParamConf =
      TexEncodeConf(mode: Mode.text, removeRowBracket: true);

  TexEncodeConf math() {
    if (mode == Mode.math && !removeRowBracket) return this;
    return copyWith(mode: Mode.math, removeRowBracket: false);
  }

  TexEncodeConf mathParam() {
    if (mode == Mode.math && removeRowBracket) return this;
    return copyWith(mode: Mode.math, removeRowBracket: true);
  }

  TexEncodeConf text() {
    if (mode == Mode.text && !removeRowBracket) return this;
    return copyWith(mode: Mode.text, removeRowBracket: false);
  }

  TexEncodeConf textParam() {
    if (mode == Mode.text && removeRowBracket) return this;
    return copyWith(mode: Mode.text, removeRowBracket: true);
  }

  TexEncodeConf param() {
    if (removeRowBracket) return this;
    return copyWith(removeRowBracket: true);
  }

  TexEncodeConf ord() {
    if (!removeRowBracket) return this;
    return copyWith(removeRowBracket: false);
  }

  TexEncodeConf copyWith({
    Mode? mode,
    bool? removeRowBracket,
    Strict? strict,
    StrictFun? strictFun,
  }) =>
      TexEncodeConf(
        mode: mode ?? this.mode,
        removeRowBracket: removeRowBracket ?? this.removeRowBracket,
        strict: strict ?? this.strict,
        strictFun: strictFun ?? this.strictFun,
      );
}

String _handleArg(dynamic arg, EncodeConf conf) {
  if (arg == null) return '';
  if (arg is EncodeResult) {
    return arg.stringify(conf);
  }
  if (arg is GreenNode) {
    return encodeTex(arg).stringify(conf);
  }
  if (arg is String) return arg;
  return arg.toString();
}

String _handleAndWrapArg(dynamic arg, EncodeConf conf) {
  final string = _handleArg(arg, conf);
  return string.length == 1 || _isSingleSymbol(arg) ? string : '{$string}';
}

bool _isSingleSymbol(dynamic arg) {
  while (true) {
    if (arg is TransparentTexEncodeResult && arg.children.length == 1) {
      arg = arg.children.first;
    } else if (arg is EquationRowTexEncodeResult && arg.children.length == 1) {
      arg = arg.children.first;
    } else if (arg is EquationRowNode && arg.children.length == 1) {
      arg = arg.children.first;
    } else {
      break;
    }
  }
  if (arg is String) return true;
  if (arg is StaticEncodeResult) return true;
  return false;
}

class TexCommandEncodeResult extends EncodeResult {
  final String command;

  /// Accepted type: [Null], [String], [EncodeResult], [GreenNode]
  final List<dynamic> args;

  late final FunctionSpec spec = functions[command]!;

  final int? _numArgs;
  late final int numArgs = _numArgs ?? spec.numArgs;

  final int? _numOptionalArgs;
  late final int numOptionalArgs = _numOptionalArgs ?? spec.numOptionalArgs;

  late final List<Mode?> argModes = spec.argModes ??
      List.filled(numArgs + numOptionalArgs, null, growable: false);

  TexCommandEncodeResult({
    required this.command,
    required this.args,
    int? numArgs,
    int? numOptionalArgs,
  })  : _numArgs = numArgs,
        _numOptionalArgs = numOptionalArgs;

  @override
  String stringify(TexEncodeConf conf) {
    assert(this.numArgs >= this.numOptionalArgs);
    if (!spec.allowedInMath && conf.mode == Mode.math) {
      conf.reportNonstrict('command mode mismatch',
          'Text-only command $command occured in math encoding enviroment');
    }
    if (!spec.allowedInText && conf.mode == Mode.text) {
      conf.reportNonstrict('command mode mismatch',
          'Math-only command $command occured in text encoding environment');
    }
    final argString = Iterable.generate(
      numArgs + numOptionalArgs,
      (index) {
        final mode = argModes[index] ?? conf.mode;
        final string = _handleArg(args[index],
            mode == Mode.math ? conf.mathParam() : conf.textParam());
        if (index < numOptionalArgs) {
          return string.isEmpty ? '' : '[$string]';
        } else {
          return '{$string}'; // TODO optimize
        }
      },
    ).join();

    if (argString.isNotEmpty && (argString[0] == '[' || argString[0] == '{')) {
      return '$command$argString';
    } else {
      return '$command $argString';
    }
  }
}

extension TexEncoderJoinerExt on Iterable<String> {
  String texJoin() {
    final iterator = this.iterator..moveNext();
    final length = this.length;
    return Iterable.generate(length, (index) {
      if (index == length - 1) return iterator.current;
      final current = iterator.current;
      final next = (iterator..moveNext()).current;
      if (current.length == 1 ||
          (next.isNotEmpty && !isAlphaNumericUnit(next[0]) && next[0] != '*') ||
          (current.isNotEmpty && current[current.length - 1] == '\}')) {
        return current;
      }
      return '$current ';
    }).join();
  }
}

class EquationRowTexEncodeResult extends EncodeResult {
  final List<dynamic> children;

  const EquationRowTexEncodeResult(this.children);

  @override
  String stringify(TexEncodeConf conf) {
    final content = Iterable.generate(children.length, (index) {
      final dynamic child = children[index];
      if (index == children.length - 1 && child is TexModeCommandEncodeResult) {
        return _handleArg(child, conf.param());
      }
      return _handleArg(child, conf.ord());
    }).texJoin();
    if (conf.removeRowBracket == true) {
      return content;
    } else {
      return '{$content}';
    }
  }
}

class TransparentTexEncodeResult extends EncodeResult {
  final List<dynamic> children;

  const TransparentTexEncodeResult(this.children);

  @override
  String stringify(TexEncodeConf conf) =>
      children.map((dynamic child) => _handleArg(child, conf.ord())).texJoin();
}

class ModeDependentEncodeResult extends EncodeResult {
  final dynamic text;

  final dynamic math;

  const ModeDependentEncodeResult({this.text, this.math});

  @override
  String stringify(TexEncodeConf conf) =>
      _handleArg(conf.mode == Mode.math ? math : text, conf);

  static String _handleArg(dynamic arg, TexEncodeConf conf) {
    if (arg == null) return '';
    if (arg is GreenNode) return arg.encodeTeX(conf: conf);
    if (arg is EncodeResult) return arg.stringify(conf);
    return arg.toString();
  }
}

class TexModeCommandEncodeResult extends EncodeResult {
  final String command;

  final List<dynamic> children;

  const TexModeCommandEncodeResult(
      {required this.command, required this.children});

  @override
  String stringify(TexEncodeConf conf) {
    final content = Iterable.generate(children.length, (index) {
      final dynamic child = children[index];
      if (index == children.length - 1 && child is TexModeCommandEncodeResult) {
        return _handleArg(child, conf.param());
      }
      return _handleArg(child, conf.ord());
    }).texJoin();
    if (conf.removeRowBracket == true) {
      return '$command $content';
    } else {
      return '{$command $content}';
    }
  }
}

class TexMultiscriptEncodeResult extends EncodeResult {
  final dynamic base;
  final dynamic sub;
  final dynamic sup;
  final dynamic presub;
  final dynamic presup;

  const TexMultiscriptEncodeResult({
    required this.base,
    this.sub,
    this.sup,
    this.presub,
    this.presup,
  });

  @override
  String stringify(TexEncodeConf conf) {
    if (conf.mode != Mode.math) {
      conf.reportNonstrict('command mode mismatch',
          'Sub/sup scripts occured in text encoding environment');
    }
    if (presub != null || presup != null) {
      conf.reportNonstrict(
        'imprecise encoding',
        'Prescripts are not supported in vanilla KaTeX',
      );
    }
    return [
      if (presub != null || presup != null) '{}',
      if (presub != null) ...[
        '_',
        _handleAndWrapArg(presub, conf.param()),
      ],
      if (presup != null) ...[
        '^',
        _handleAndWrapArg(presup, conf.param()),
      ],
      _handleAndWrapArg(base, conf.param()),
      if (sub != null) ...[
        '_',
        _handleAndWrapArg(sub, conf.param()),
      ],
      if (sup != null) ...[
        '^',
        _handleAndWrapArg(sup, conf.param()),
      ],
    ].texJoin();
  }
}
