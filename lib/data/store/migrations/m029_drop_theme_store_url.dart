import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Deletes the theme catalog address an install could repoint.
///
/// The catalog is `Urls.themeCatalog`, compiled in: it is published with the
/// app's own repository, and a client pointed at another one was a client for
/// one publisher. The setting that held the address is gone along with the row
/// that edited it, so this value is now read by nothing — and left in place it
/// is a URL a user typed, kept for no reason, in a database a backup carries.
///
/// A `DELETE` and nothing else. The catalog itself is unaffected: what is on
/// screen comes from `themeStoreCache`, which the store page writes back on
/// every refresh, and a refresh that fails leaves that cache alone.
///
/// Idempotent by construction: a second run deletes nothing.
class DropThemeStoreUrlMigration implements SchemaMigration {
  const DropThemeStoreUrlMigration();

  @override
  int get from => 29;

  @override
  Future<void> apply() async {
    SqliteDb.instance.execute(
      "DELETE FROM kv WHERE store = 'setting' AND key = 'themeStoreUrl';",
    );
  }
}
