import 'package:logging/logging.dart';

abstract final class Loggers {
  static final root = Logger('Root');
  static final app = Logger('App');
  static final parse = Logger('Parse');
}
