import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// BMC accounts, as rows in `bmc_credential`.
///
/// The same shape as [PrivateKeyStore], for the same reason: several servers
/// point at one record, so the thing they point at has to be an id rather than
/// a name the user can change.
class BmcCredentialStore extends EntityStore<BmcCredential> {
  BmcCredentialStore();

  static final instance = BmcCredentialStore();

  @override
  String get table => 'bmc_credential';

  @override
  String idOf(BmcCredential item) => item.id;

  @override
  String? nameOf(BmcCredential item) => item.name;

  @override
  List<BmcCredential> readAll() => db
      .select('SELECT id, name, user, pwd FROM bmc_credential ORDER BY name;')
      .map(_fromRow)
      .toList();

  static BmcCredential _fromRow(Row row) => BmcCredential(
    id: row['id'] as String,
    name: row['name'] as String,
    user: row['user'] as String? ?? '',
    pwd: row['pwd'] as String?,
  );

  @override
  void write(BmcCredential item) => upsert(
    const ['id', 'name', 'user', 'pwd'],
    [item.id, item.name, item.user, item.pwd],
  );

  @override
  Map<String, dynamic> toJson(BmcCredential item) => item.toJson();

  @override
  BmcCredential? fromJson(Map<String, dynamic> json) {
    try {
      return BmcCredential.fromJson(json);
    } catch (e) {
      dprint('Parsing BmcCredential from JSON', e);
      return null;
    }
  }

  /// Keeps the local id when a restored record turns out to be one already
  /// here under the same name.
  ///
  /// Without this, restoring the same backup twice creates a second copy of
  /// every account under a name the schema says is unique — so the second
  /// restore fails rather than being the no-op it should be. Same as
  /// [PrivateKeyStore.reconcile].
  @override
  BmcCredential reconcile(BmcCredential incoming) {
    if (fetchOneRaw(incoming.id) != null) return incoming;
    final existing = fetchByName(incoming.name);
    return existing == null ? incoming : incoming.copyWith(id: existing.id);
  }

  BmcCredential? fetchOne(String? id) => id == null ? null : fetchOneRaw(id);

  /// How many servers point at [id], for a delete that would orphan them.
  ///
  /// The foreign key is `ON DELETE SET NULL`, so deleting an account in use
  /// does not fail — it quietly leaves those servers with an address and
  /// nothing to log in with. Asking first is what lets the UI say so.
  int serversUsing(String id) =>
      db.select('SELECT COUNT(*) AS n FROM server WHERE bmc_cred_id = ?;', [
            id,
          ]).single['n']
          as int;
}
