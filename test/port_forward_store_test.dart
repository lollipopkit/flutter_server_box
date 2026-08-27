import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/store/port_forward.dart';

import 'helpers/test_db.dart';

/// A port forward has to survive being written.
///
/// It did not, between the move to SQLite and this test: `SqliteStore` encodes
/// with `(value as dynamic).toJson()`, [PortForwardConfig] is the one freezed
/// model in the app with no `.g.dart` to generate one, and `set` answers
/// `false` rather than throwing — so every save failed quietly. Under Hive the
/// record went through its generated adapter and never needed `toJson`.
void main() {
  late PortForwardStore store;

  setUp(() async {
    await openTestDb();
    // Both forwards below name a server, and `server_id` is a foreign key now.
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip) VALUES '
      "('srv-1', 'one', '10.0.0.1'), ('srv-2', 'two', '10.0.0.2'), "
      "('srv-other', 'other', '10.0.0.3');",
    );
    store = PortForwardStore();
  });

  tearDown(() async => SqliteDb.close());

  const config = PortForwardConfig(
    id: 'pf-1',
    serverId: 'srv-1',
    name: 'postgres',
    type: PortForwardType.local,
    localHost: '127.0.0.1',
    localPort: 15432,
    remoteHost: '10.0.0.50',
    remotePort: 5432,
  );

  test('a saved config is readable again', () {
    store.put(config);

    final read = store.fetchForServer('srv-1');
    expect(read.length, 1, reason: 'the write must not fail quietly');
    expect(read.single, config);
  });

  test('every type round-trips by name', () {
    for (final type in PortForwardType.values) {
      store.put(config.copyWith(id: type.name, type: type));
    }

    final byType = {for (final c in store.fetchForServer('srv-1')) c.type: c};
    expect(byType.keys.toSet(), PortForwardType.values.toSet());
  });

  test('the optional fields survive being absent', () {
    const minimal = PortForwardConfig(
      id: 'pf-min',
      serverId: 'srv-2',
      name: 'socks',
      type: PortForwardType.dynamic,
    );
    store.put(minimal);

    final read = store.fetchForServer('srv-2').single;
    expect(read.localHost, isNull);
    expect(read.localPort, 0);
    expect(read.remoteHost, isNull);
    expect(read.remotePort, isNull);
  });

  test('fetch only answers for the server asked about', () {
    store.put(config);
    store.put(config.copyWith(id: 'pf-2', serverId: 'srv-other'));

    expect(store.fetchForServer('srv-1').single.id, 'pf-1');
    expect(store.fetchForServer('srv-other').single.id, 'pf-2');
    expect(store.fetchForServer('srv-none'), isEmpty);
  });

  test('delete removes it', () {
    store.put(config);
    store.delete(config);
    expect(store.fetchForServer('srv-1'), isEmpty);
  });

  test('clearServer removes only that server configurations', () {
    store.put(config);
    store.put(config.copyWith(id: 'pf-2', serverId: 'srv-other'));

    store.clearServer('srv-1');

    expect(store.fetchForServer('srv-1'), isEmpty);
    expect(store.fetchForServer('srv-other').single.id, 'pf-2');
  });
}
