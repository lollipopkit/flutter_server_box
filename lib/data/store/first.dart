import 'package:toolbox/core/persistant_store.dart';

/// It stores whether is the first time of some.
class FirstStore extends PersistentStore<bool> {
  /// Add Snippet `Install ServerBoxMonitor`
  late final iSSBM = StoreProperty(box, 'installMonitorSnippet', true);

  /// Show tip of suspend
  late final showSuspendTip = StoreProperty(box, 'showSuspendTip', true);
}
