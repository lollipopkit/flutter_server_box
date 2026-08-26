import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// Retires the hand-typed `/status` URLs, and arranges for the user to be told.
///
/// Those URLs named the agent's Go-compat endpoint: unauthenticated, current
/// values only, preformatted as strings. Nothing reads them any more — the
/// watch and both home-screen widgets speak `/api/v1` with a scoped
/// credential, which is what lets them draw a trend at all — and the agent
/// itself now answers 410 there.
///
/// Anyone whose watch or widget was configured that way loses it, and there is
/// no way to convert it: a bare address is not enough to reach the
/// authenticated API, and the login it would need is exactly what those URLs
/// existed to avoid needing. The only honest migration is to say so, which is
/// what [SettingStore.legacyStatusNoticePending] is for.
///
/// Detection is deliberately wide. An install that had *either* a watch URL or
/// an Android widget preference gets the notice; a false positive costs one
/// dialog, and a false negative is a widget that stopped working with no
/// explanation anywhere.
class LegacyStatusUrlsMigration implements SchemaMigration {
  const LegacyStatusUrlsMigration();

  /// The prefix the Android widget's configuration used, before it kept its
  /// own per-widget record.
  static const androidWidgetPrefix = 'widget_';

  @override
  int get from => 16;

  @override
  Future<void> apply() async {
    final setting = SettingStore.instance;

    final hadWatchUrls = setting.watchLegacyUrls.fetch().isNotEmpty;
    final hadWidgetUrls = PrefStore.shared
        .keys()
        .any((key) => key.startsWith(androidWidgetPrefix));

    if (hadWatchUrls || hadWidgetUrls) {
      setting.legacyStatusNoticePending.put(true);
    }

    // Cleared here rather than left for the reader to ignore. The value is a
    // list of addresses the user typed, and keeping it would leave the app
    // syncing and backing up a setting nothing can act on.
    if (hadWatchUrls) setting.watchLegacyUrls.put([]);

    // The Android widget's own preferences are native-side now
    // (`WidgetStore`), so these are dead weight in the Flutter store.
    for (final key in PrefStore.shared
        .keys()
        .where((key) => key.startsWith(androidWidgetPrefix))
        .toList()) {
      await PrefStore.shared.remove(key);
    }
  }
}
