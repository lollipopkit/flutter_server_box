import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/m014_ssh_file_transport.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';

/// The step that gives `server` somewhere to record which protocol carries its
/// files.
///
/// It gets one pass over a user's records and is not repeatable, so what is
/// worth asserting is that the servers already there come out of it unchanged
/// and reading as SFTP — which is not a default chosen here but a fact about
/// the builds that wrote those rows, none of which could do anything else.
void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(SqliteDb.close);

  /// The v14 shape: the current one, less the column this step adds.
  ///
  /// Derived rather than hand-written, because here that is exactly what v14
  /// *was* — one `ALTER TABLE ADD COLUMN` separates the two versions, so
  /// subtracting the column reproduces it column for column, sync metadata and
  /// child tables included, and goes on doing so as the rest of the schema
  /// changes. A hand-written shape would only be as right as the day it was
  /// typed, and `ServerStore` reads six tables.
  Future<void> createV14Schema() async {
    await createTables(SqliteDb.instance);
    SqliteDb.instance.execute(
      'ALTER TABLE server DROP COLUMN ssh_file_transport;',
    );
  }

  List<String> columns() => SqliteDb.instance
      .select('PRAGMA table_info(server);')
      .map((column) => column['name'] as String)
      .toList();

  test('adds the column and leaves the servers alone', () async {
    await createV14Schema();
    SqliteDb.instance.execute(
      'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
      'ssh_user) '
      "VALUES (1700000000, 3, 's-1', 'router', '10.0.0.1', 22, 'root');",
    );

    await const SshFileTransportMigration().apply();

    expect(columns(), contains('ssh_file_transport'));
    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['id'], 's-1');
    expect(row['ssh_ip'], '10.0.0.1');
    // The columns sync reads. An ALTER TABLE leaves them alone, and a step that
    // reset either would make every server look freshly edited to a peer.
    expect(row['updated_at'], 1700000000);
    expect(row['rev'], 3);
    // Null, not 'sftp': nothing is backfilled, and null is what the reader
    // below turns into SFTP.
    expect(row['ssh_file_transport'], isNull);
  });

  test('a row from before the column reads as SFTP', () async {
    await createV14Schema();
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user) '
      "VALUES ('s-1', 'router', '10.0.0.1', 22, 'root');",
    );

    await const SshFileTransportMigration().apply();

    final spi = ServerStore.forTest().fetch().single;
    expect(spi.ssh?.fileTransport, SshFileTransport.sftp);
  });

  test('a value nothing recognises reads as SFTP rather than throwing',
      () async {
    await createV14Schema();
    await const SshFileTransportMigration().apply();
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, '
      'ssh_file_transport) '
      "VALUES ('s-1', 'router', '10.0.0.1', 22, 'root', 'rsync');",
    );

    // Stored by name, so a build that grows a third protocol writes a word this
    // one has never seen. Falling back beats refusing to list the server.
    final spi = ServerStore.forTest().fetch().single;
    expect(spi.ssh?.fileTransport, SshFileTransport.sftp);
  });

  test('runs again without complaining', () async {
    // The version is recorded only once every statement has run, so a process
    // stopped partway means the whole step runs again.
    await createV14Schema();
    await const SshFileTransportMigration().apply();
    await const SshFileTransportMigration().apply();
    expect(columns().where((c) => c == 'ssh_file_transport'), hasLength(1));
  });
}
