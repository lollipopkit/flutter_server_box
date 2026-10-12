import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    Stores.setting.diagnosticsConsentVer.put(kDiagnosticsConsentVer);
  });

  tearDown(() async {
    Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.none.name);
    await DiagnosticsUpload.sync();
    await getIt.reset();
    await SqliteDb.close();
  });

  test('turned off while starting, it ends off', () async {
    Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.basic.name);
    // Not awaited: the start is still inside `Sentry.init` when Settings
    // asks for it to stop.
    final starting = DiagnosticsUpload.sync();
    Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.none.name);
    final stopping = DiagnosticsUpload.sync();
    await Future.wait([starting, stopping]);

    expect(DiagnosticsUpload.uploading, isFalse);
  });
}
