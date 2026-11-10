import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';

/// fl_lib's operation-log sync on LK Cloud, while the backup syncs there.
final lkcLog = LkcLogSync(
  client: Lkc.client,
  app: Lkc.app,
  enabled: Lkc.enabled ? LkcSyncPrefs.enabled.listenable() : const _Off(),
);

/// LK Cloud is not in this build: nothing syncs there.
final class _Off implements ValueListenable<bool> {
  const _Off();

  @override
  bool get value => false;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
