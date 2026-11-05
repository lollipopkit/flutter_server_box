import 'package:fl_lib/fl_lib.dart';

/// A store a restore or a sync rewrites, whose providers then read it again.
enum ReloadedStore { servers, snippets, keys, bmcCredentials, containers }

/// Tells whoever reads the stores a restore or a sync just rewrote to read
/// them again.
///
/// Said by the layer that wrote them; done by the providers, which install
/// [reload] at start (`installStoreReload`), so a store never imports them.
abstract final class StoreReload {
  static void Function(Set<ReloadedStore> rewritten)? reload;

  static void after(Set<ReloadedStore> rewritten) {
    if (rewritten.isEmpty) return;
    final reload = StoreReload.reload;
    if (reload == null) {
      Loggers.app.warning('Stores rewritten before installStoreReload: $rewritten');
      return;
    }
    reload(rewritten);
  }
}
