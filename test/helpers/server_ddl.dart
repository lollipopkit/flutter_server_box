import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';

/// `server` as today's Drift creates it.
String freshServerDdl() =>
    SqliteDb.instance
            .select("SELECT sql FROM sqlite_master WHERE name = 'server';")
            .single['sql']
        as String;

/// The three PVE columns m030 moved out, as Drift declared them from v4 to v30.
const pveServerColumns =
    '"pve_addr" TEXT NULL, '
    '"pve_ignore_cert" INTEGER NOT NULL DEFAULT 0 '
    'CHECK ("pve_ignore_cert" IN (0, 1)), '
    '"pve_pwd" TEXT NULL, ';

/// `server` as a fresh install created it at v29 and v30: today's table with
/// the PVE columns m030 dropped put back where they stood, before
/// `prefer_temp_dev`.
///
/// Derived rather than copied so the rest of the table follows today's, with
/// the anchor asserted to have been found — a change that moves it fails here
/// rather than producing a shape that never existed.
String serverDdlBeforePveTable(String fresh) {
  const anchor = '"prefer_temp_dev" TEXT NULL, ';
  expect(fresh, contains(anchor));
  expect(fresh, isNot(contains('"pve_addr"')));
  return fresh.replaceFirst(anchor, '$pveServerColumns$anchor');
}

/// Replaces `server` with [ddl], keeping every child table: the same pragmas
/// the rebuild steps use, so neither a cascade nor a rewritten foreign key
/// touches what is already there.
void replaceServerTable(String ddl) {
  final db = SqliteDb.instance;
  db.execute('PRAGMA foreign_keys = OFF;');
  db.execute('PRAGMA legacy_alter_table = ON;');
  db.execute('DROP TABLE server;');
  db.execute(ddl);
  db.execute('PRAGMA legacy_alter_table = OFF;');
  db.execute('PRAGMA foreign_keys = ON;');
}
