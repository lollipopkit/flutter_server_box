// TODO: remove with `DiagnosticsUpload.retireFullLevel`.

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_db.dart';

/// An install that chose the removed `full` level: it moves to `basic`, and
/// the profile id `full` created for its analytics leaves the device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test('full becomes basic and its profile id is deleted', () async {
    Stores.setting.diagnosticsLevel.put('full');
    await PrefStore.shared.set('openpanel_profile_id', 'deadbeef');

    await DiagnosticsUpload.retireFullLevel();

    expect(Stores.setting.diagnosticsLevel.fetch(), DiagnosticsLevel.basic.name);
    expect(PrefStore.shared.get<String>('openpanel_profile_id'), isNull);
  });

  test('any other choice is left as it was', () async {
    Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.none.name);

    await DiagnosticsUpload.retireFullLevel();

    expect(Stores.setting.diagnosticsLevel.fetch(), DiagnosticsLevel.none.name);
  });
}
