import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds the sync root that stores RDP and VNC connection profiles.
class RemoteDesktopProfilesMigration implements SchemaMigration {
  const RemoteDesktopProfilesMigration();

  @override
  int get from => 24;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    db.execute('''
CREATE TABLE IF NOT EXISTS remote_desktop_profile (
  updated_at INTEGER NOT NULL DEFAULT 0,
  rev INTEGER NOT NULL DEFAULT 0,
  id TEXT NOT NULL PRIMARY KEY,
  server_id TEXT NOT NULL REFERENCES server (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  protocol TEXT NOT NULL CHECK (protocol IN ('rdp', 'vnc')),
  host TEXT NOT NULL DEFAULT '127.0.0.1',
  port INTEGER NOT NULL CHECK (port BETWEEN 1 AND 65535),
  username TEXT,
  password TEXT,
  domain TEXT,
  view_only INTEGER NOT NULL DEFAULT 0 CHECK (view_only IN (0, 1)),
  shared INTEGER NOT NULL DEFAULT 1 CHECK (shared IN (0, 1)),
  trusted_cert_sha256 TEXT,
  UNIQUE (server_id, name)
) WITHOUT ROWID;
''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_remote_desktop_profile_server '
      'ON remote_desktop_profile(server_id);',
    );
  }
}
