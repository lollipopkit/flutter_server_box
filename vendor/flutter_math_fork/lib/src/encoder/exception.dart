import '../widgets/exception.dart';

class EncoderException implements FlutterMathException {
  final String message;
  final dynamic token;

  const EncoderException(this.message, [this.token]);

  String get messageWithType => 'Encoder Exception: $message';
}
