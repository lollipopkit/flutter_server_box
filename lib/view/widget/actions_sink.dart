import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// Where a page hosted inside another's bar puts its buttons, instead of
/// drawing a bar of its own — the pattern `SftpPageArgs.actionsSink` started.
typedef ActionsSink = ValueNotifier<List<BarAction>>;

extension ActionsSinkX on ActionsSink {
  /// [actions] handed over after the frame: a notifier written while building
  /// tells its listeners to rebuild in the middle of a build.
  void publish(State state, List<BarAction> actions) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.mounted) value = actions;
    });
  }
}
