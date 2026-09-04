import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m018_server_geo.dart';

const _added = ['geo_lat', 'geo_lon'];

void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(SqliteDb.close);

  /// The v18 shape, as far as this step is concerned: a `server` table with
  /// nothing on it about where the machine is.
  void createV18Server() {
    SqliteDb.instance.execute(
      'CREATE TABLE server ('
      'id TEXT PRIMARY KEY, name TEXT, ssh_ip TEXT, preferred_transport TEXT'
      ');',
    );
  }

  List<String> serverColumns() => SqliteDb.instance
      .select('PRAGMA table_info(server);')
      .map((column) => column['name'] as String)
      .toList();

  test('adds the two columns and invents nothing to put in them', () async {
    createV18Server();
    SqliteDb.instance.execute(
      "INSERT INTO server VALUES ('srv-1', 'prod', '10.0.0.1', NULL);",
    );

    await const ServerGeoMigration().apply();

    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['name'], 'prod');
    expect(row['ssh_ip'], '10.0.0.1');
    // A server nobody has placed stays unplaced. The alternative — guessing
    // from the address at migration time — would write a lookup's answer into
    // the column that means "the user said so".
    for (final column in _added) {
      expect(row[column], isNull, reason: column);
    }
  });

  test('the columns hold a fraction of a degree', () async {
    createV18Server();
    await const ServerGeoMigration().apply();

    // REAL, not INTEGER. City-level accuracy is the fourth decimal place, so a
    // column that rounded to whole degrees would put every server in the
    // country somewhere near the same point.
    final types = {
      for (final column in SqliteDb.instance.select(
        'PRAGMA table_info(server);',
      ))
        column['name'] as String: column['type'] as String,
    };
    expect(types['geo_lat'], 'REAL');
    expect(types['geo_lon'], 'REAL');

    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, geo_lat, geo_lon) '
      "VALUES ('srv-1', 'prod', 39.9042, 116.4074);",
    );
    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['geo_lat'], closeTo(39.9042, 1e-9));
    expect(row['geo_lon'], closeTo(116.4074, 1e-9));
  });

  test('runs again after being interrupted partway', () async {
    createV18Server();
    // What a process stopping between the two statements leaves: the first
    // column committed, the version not yet recorded, so the whole step runs
    // again. Without the guard the retry fails on `duplicate column name` and
    // the step can never finish.
    SqliteDb.instance.execute('ALTER TABLE server ADD COLUMN geo_lat REAL;');

    await const ServerGeoMigration().apply();

    final columns = serverColumns();
    for (final column in _added) {
      expect(
        columns.where((c) => c == column),
        hasLength(1),
        reason: '$column should exist exactly once',
      );
    }
  });

  test('is idempotent', () async {
    createV18Server();
    await const ServerGeoMigration().apply();
    await const ServerGeoMigration().apply();

    expect(serverColumns().where((c) => c.startsWith('geo_')), hasLength(2));
  });
}
