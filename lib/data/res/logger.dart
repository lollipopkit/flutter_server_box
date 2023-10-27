import 'package:logging/logging.dart';

class Loggers {
  const Loggers._();

  static final root = Logger('Root');
  static final app = Logger('App');
  static final parse = Logger('Parse');
}
