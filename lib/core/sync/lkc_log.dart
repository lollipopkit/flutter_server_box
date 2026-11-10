import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';

/// fl_lib's operation-log sync on LK Cloud, while the backup syncs there.
final lkcLog = LkcLogSync(
  client: Lkc.client,
  app: Lkc.app,
  // LK Cloud not in this build: nothing syncs there.
  enabled: Lkc.enabled ? LkcSyncPrefs.enabled.listenable() : ValueNotifier(false),
);

