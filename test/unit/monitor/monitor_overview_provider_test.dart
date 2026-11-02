/// The Monitor tab's per-agent provider over an agent that offers only what
/// is read when asked (`audit`, `live`): nothing to poll, so nothing is set
/// before the provider has a state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_access.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_overview.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/test_db.dart';

class _Server extends ServerNotifier {
  @override
  ServerState build(String id) => ServerState(
    spi: Stores.server.fetch().firstWhere((s) => s.id == id),
    status: InitStatus.status,
    conn: ServerConn.finished,
    agentCapabilities: const MonitorCapabilities(
      access: MonitorAccess.granted,
      features: {'audit', 'live'},
      version: '0.4.0',
    ),
  );
}

void main() {
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  test('an agent with nothing to poll is built without a read', () async {
    Stores.server.put(
      Spi(
        id: 'a',
        name: 'box',
        // Nothing listens: a read would fail, and none is made.
        monitorHttp: const MonitorHttpCredential(addr: 'http://127.0.0.1:9', pwd: 'pw'),
      ),
    );
    final container = ProviderContainer(overrides: [serverProvider.overrideWith2((_) => _Server())]);
    addTearDown(container.dispose);

    final state = container.read(monitorOverviewProvider('a'));
    expect(state.features, {'audit', 'live'});
    await container.read(monitorOverviewProvider('a').notifier).refresh();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(monitorOverviewProvider('a')).error, isNull);
  });
}
