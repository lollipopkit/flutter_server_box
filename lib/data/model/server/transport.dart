import 'package:fl_lib/fl_lib.dart';

/// Which way of reaching a server is tried first.
///
/// Only meaningful when both are configured. Stored **by name**, never by
/// index: an index silently changes meaning when a case is inserted, and this
/// outlives the build that wrote it.
enum ServerTransport {
  ssh,
  monitorHttp,

  /// This device, with no connection at all — see [Spi.local]. Never stored
  /// as a preference: a local server has nothing to order.
  local;

  static ServerTransport? fromName(Object? name) =>
      ServerTransport.values.firstWhereOrNull((e) => e.name == name);
}
