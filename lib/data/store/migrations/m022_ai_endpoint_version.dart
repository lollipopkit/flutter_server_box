import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// Writes the API version into an AI endpoint that was relying on it being
/// guessed.
///
/// The path completion used to insert `v1` for any address that did not
/// already end in it. That is only OpenAI's number — Zhipu's is `v4` — so the
/// guess made their documented root unusable (#1465) while quietly working for
/// everyone else.
///
/// The guess is gone; a stored address is now sent as the user wrote it. Which
/// means an address that was working *because* of the guess would stop, with a
/// 404 and nothing to say why. This puts the guess into the stored value once,
/// so the request that goes out tomorrow is the one that went out yesterday.
///
/// Only an address that has no version and is not already a complete endpoint.
/// `…/api/paas/v4` and `…/v1/chat/completions` are left exactly as they are.
class AiEndpointVersionMigration implements SchemaMigration {
  const AiEndpointVersionMigration();


  static const appliedAt = 22;
  static const key = 'askAi';

  @override
  int get from => appliedAt;

  @override
  Future<void> apply() async => applySync();

  void applySync() {
    final store = SettingStore.instance;
    final raw = store.get<Object>(key);
    if (raw is! Map) return;

    // The map as it is, not through a model: this row is read by nothing but
    // `LegacyAskAiMigration` now, which takes the plain map.
    final baseUrl = raw['baseUrl'];
    if (baseUrl is! String) return;
    final migrated = versioned(baseUrl);
    if (migrated == baseUrl) return;

    final ok = store.set(
      key,
      {...raw.cast<String, Object?>(), 'baseUrl': migrated},
      // Not a user edit: the address means what it always meant, and syncing
      // this as a change would carry a rewrite nobody made to every device.
      updateLastUpdateTsOnSet: false,
    );
    if (!ok) throw StateError('m022: writing "$key" failed');
  }

  /// [baseUrl] with `v1` appended where the old completion would have put it.
  ///
  /// Static and named so the test can state the rule directly; the store is
  /// not involved in deciding it.
  static String versioned(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return baseUrl;
    final uri = Uri.tryParse(trimmed.replaceAll(RegExp(r'/+$'), ''));
    if (uri == null || uri.host.isEmpty) return baseUrl;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // Already an endpoint. The completion never touched these, so neither does
    // this.
    if (segments.isNotEmpty &&
        (segments.last == 'responses' || segments.last == 'completions')) {
      return baseUrl;
    }
    // Already names its version, whichever it is.
    if (segments.isNotEmpty && RegExp(r'^v\d+$').hasMatch(segments.last)) {
      return baseUrl;
    }
    return uri.replace(pathSegments: [...segments, 'v1']).toString();
  }
}
