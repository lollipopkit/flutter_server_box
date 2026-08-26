/// The step that retires the hand-typed `/status` URLs.
///
/// Its only visible effect is a dialog, which makes it the easiest kind of
/// migration to get silently wrong: set nothing and a user's watch and widgets
/// stop working with no explanation anywhere, and there is no second chance —
/// the old configuration is gone by the time anyone notices.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m016_legacy_status_urls.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    // The Android widget's old configuration lived in the Flutter shared
    // preferences, so this step reads them — and they need a backing store in
    // a test the same way they need one on a device.
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    SettingStore.instance.watchLegacyUrls.put([]);
    SettingStore.instance.legacyStatusNoticePending.put(false);
    for (final key in PrefStore.shared.keys().toList()) {
      if (key.startsWith(LegacyStatusUrlsMigration.androidWidgetPrefix)) {
        await PrefStore.shared.remove(key);
      }
    }
  });
  tearDown(SqliteDb.close);

  bool notice() => SettingStore.instance.legacyStatusNoticePending.fetch();

  test('a watch configured with status URLs is told', () async {
    SettingStore.instance.watchLegacyUrls.put([
      'http://10.0.0.2:3770/status',
    ]);

    await const LegacyStatusUrlsMigration().apply();

    expect(notice(), isTrue);
  });

  test('and the URLs are cleared, since nothing can act on them', () async {
    // A bare address cannot reach the authenticated API — the login it would
    // need is exactly what these existed to avoid needing. Keeping them would
    // leave the app syncing and backing up a setting with no reader.
    SettingStore.instance.watchLegacyUrls.put([
      'http://10.0.0.2:3770/status',
    ]);

    await const LegacyStatusUrlsMigration().apply();

    expect(SettingStore.instance.watchLegacyUrls.fetch(), isEmpty);
  });

  test('an Android widget configured with a status URL is told', () async {
    await PrefStore.shared.set(
      '${LegacyStatusUrlsMigration.androidWidgetPrefix}42',
      'http://10.0.0.3:3770/status',
    );

    await const LegacyStatusUrlsMigration().apply();

    expect(notice(), isTrue);
  });

  test('and that preference is removed', () async {
    // The widget keeps its own configuration natively now; this key is dead
    // weight in the Flutter store.
    const key = '${LegacyStatusUrlsMigration.androidWidgetPrefix}42';
    await PrefStore.shared.set(key, 'http://10.0.0.3:3770/status');

    await const LegacyStatusUrlsMigration().apply();

    expect(PrefStore.shared.get<String>(key), isNull);
  });

  test('an install that never used one is not told anything', () async {
    // The notice is about a feature that has gone. Someone who never had it
    // is being interrupted for no reason.
    await const LegacyStatusUrlsMigration().apply();

    expect(notice(), isFalse);
  });

  test('an unrelated preference is left alone', () async {
    await PrefStore.shared.set('widgets_are_not_this', 'keep me');

    await const LegacyStatusUrlsMigration().apply();

    expect(PrefStore.shared.get<String>('widgets_are_not_this'), 'keep me');
    expect(notice(), isFalse);
  });

  test('runs again without losing the message', () async {
    // The version is recorded only once the step has run, so a process stopped
    // partway means the whole thing runs again — this time with the URLs
    // already cleared. The flag it set the first time must survive that, or
    // the interruption is what decides whether the user is ever told.
    SettingStore.instance.watchLegacyUrls.put([
      'http://10.0.0.2:3770/status',
    ]);

    await const LegacyStatusUrlsMigration().apply();
    await const LegacyStatusUrlsMigration().apply();

    expect(notice(), isTrue);
  });
}
