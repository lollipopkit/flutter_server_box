import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m005_monitor_insecure_http.dart';

void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(SqliteDb.close);

  test('adds the monitor plaintext opt-in without changing existing rows',
      () async {
    SqliteDb.instance.execute(
      'CREATE TABLE server (id TEXT PRIMARY KEY, monitor_addr TEXT);',
    );
    SqliteDb.instance.execute(
      "INSERT INTO server VALUES ('monitor', 'http://100.64.0.1:3770');",
    );

    await const MonitorInsecureHttpMigration().apply();

    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['monitor_addr'], 'http://100.64.0.1:3770');
    expect(row['monitor_allow_insecure'], isNull);

    await const MonitorInsecureHttpMigration().apply();
    expect(
      SqliteDb.instance
          .select('PRAGMA table_info(server);')
          .where((column) => column['name'] == 'monitor_allow_insecure'),
      hasLength(1),
    );
  });
}
