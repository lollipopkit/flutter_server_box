import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';
import 'package:server_box/data/store/schema.dart';

/// fl_lib's operation-log sync on LK Cloud, while the backup syncs there.
final lkcLog = LkcLogSync(
  client: Lkc.client,
  app: Lkc.app,
  // LK Cloud not in this build: nothing syncs there.
  enabled: Lkc.enabled ? _Readable(LkcSyncPrefs.enabled.listenable()) : ValueNotifier(false),
);

/// [on], and off while this build reads storage a newer one wrote
/// ([SchemaVersion.readsAhead]): asked again at every read, as that changes
/// only when another database is opened.
final class _Readable extends ChangeNotifier implements ValueListenable<bool> {
  _Readable(this.on) {
    on.addListener(notifyListeners);
  }

  final ValueListenable<bool> on;

  @override
  bool get value => on.value && !SchemaVersion.readsAhead;
}
