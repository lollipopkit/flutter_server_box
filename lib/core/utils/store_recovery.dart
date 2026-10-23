import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';

/// A database a launch could not open, and where it was moved (#1780).
typedef StoreSetAside = ({
  StoreUnreadableReason reason,
  String detail,
  String aside,
});

/// Starting empty in place of a database the vault's key does not open.
///
/// Stopping instead helps nobody: the file stays unreadable on every launch,
/// and an app that does not open cannot restore a backup or say what
/// happened. The file is kept, renamed — see [SqliteDb.setAside].
abstract final class StoreRecovery {
  static const _pendingKey = 'store_set_aside';

  static StoreSetAside? _result;

  /// Set aside by this launch, or by an earlier one whose notice was never
  /// acknowledged: the next launch opens the empty file without an error, so
  /// only this record still says where the old one went.
  static StoreSetAside? get result => _result ??= _readPersisted();

  /// Moves [e]'s file aside, so the next `Stores.init` opens an empty one.
  ///
  /// The database must be closed: on Windows an open file cannot be renamed.
  static Future<void> setAside(StoreUnreadableException e, StackTrace s) async {
    final aside = SqliteDb.setAside(e.path);
    Diag.error(e, s, 'Store unreadable, moved to $aside');
    final result = (reason: e.reason, detail: '$e', aside: aside);
    _result = result;
    await PrefStore.shared.set(
      _pendingKey,
      jsonEncode({
        'reason': result.reason.name,
        'detail': result.detail,
        'aside': result.aside,
      }),
    );
  }

  /// Call once the notice has been dismissed.
  static Future<void> acknowledge() async {
    _result = null;
    await PrefStore.shared.remove(_pendingKey);
  }

  static StoreSetAside? _readPersisted() {
    final raw = PrefStore.shared.get<String>(_pendingKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        reason: StoreUnreadableReason.values.byName(map['reason'] as String),
        detail: map['detail'] as String,
        aside: map['aside'] as String,
      );
    } catch (e, s) {
      Loggers.app.warning('Unreadable $_pendingKey', e, s);
      return null;
    }
  }
}
