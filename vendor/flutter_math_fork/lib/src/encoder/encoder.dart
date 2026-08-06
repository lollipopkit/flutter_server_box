import '../ast/syntax_tree.dart';
import '../parser/tex/settings.dart';
import '../utils/log.dart';
import 'exception.dart';

abstract class EncodeResult {
  const EncodeResult();
  String stringify(covariant EncodeConf conf);
}

class StaticEncodeResult extends EncodeResult {
  const StaticEncodeResult(this.string);

  final String string;

  @override
  String stringify(EncodeConf conf) => string;
}

class NonStrictEncodeResult extends EncodeResult {
  final String errorCode;
  final String errorMsg;
  final EncodeResult placeHolder;

  const NonStrictEncodeResult(
    this.errorCode,
    this.errorMsg, [
    this.placeHolder = const StaticEncodeResult(''),
  ]);

  NonStrictEncodeResult.string(
    this.errorCode,
    this.errorMsg, [
    String placeHolder = '',
  ]) : this.placeHolder = StaticEncodeResult(placeHolder);

  @override
  String stringify(EncodeConf conf) {
    conf.reportNonstrict(errorCode, errorMsg);
    return placeHolder.stringify(conf);
  }
}

typedef EncoderFun<T extends GreenNode> = EncodeResult Function(T node);

typedef StrictFun = Strict Function(String errorCode, String errorMsg,
    [dynamic token]);

abstract class EncodeConf {
  final Strict strict;

  final StrictFun? strictFun;

  const EncodeConf({
    this.strict = Strict.warn,
    this.strictFun,
  });

  void reportNonstrict(String errorCode, String errorMsg, [dynamic token]) {
    final strict = this.strict != Strict.function
        ? this.strict
        : (strictFun?.call(errorCode, errorMsg, token) ?? Strict.warn);
    switch (strict) {
      case Strict.ignore:
        return;
      case Strict.error:
        throw EncoderException(
            "Nonstrict Tex encoding and strict mode is set to 'error': "
            '$errorMsg [$errorCode]',
            token);
      case Strict.warn:
        warn("Nonstrict Tex encoding and strict mode is set to 'warn': "
            '$errorMsg [$errorCode]');
        break;
      default:
        warn('Nonstrict Tex encoding and strict mode is set to '
            "unrecognized '$strict': $errorMsg [$errorCode]");
    }
  }
}
