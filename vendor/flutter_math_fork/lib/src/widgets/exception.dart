/// Base class for exceptions.
abstract class FlutterMathException implements Exception {
  String get message;

  String get messageWithType;
}

/// Exceptions occured during build.
class BuildException implements FlutterMathException {
  final String message;
  final StackTrace? trace;

  const BuildException(this.message, {this.trace});

  String get messageWithType => 'Build Exception: $message';
}
