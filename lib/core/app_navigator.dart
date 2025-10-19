import 'package:flutter/widgets.dart';

/// Global navigator access used for cross-cutting flows (e.g. dialogs).
abstract final class AppNavigator {
  static final key = GlobalKey<NavigatorState>();

  static BuildContext? get context => key.currentContext;
}
