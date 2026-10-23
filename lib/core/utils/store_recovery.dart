import 'package:fl_lib/fl_lib.dart';

/// A database this launch could not open, and where it was moved (#1780).
typedef StoreSetAside = ({StoreUnreadableException err, String aside});

/// Starting empty in place of a database the vault's key does not open.
///
/// Stopping instead helps nobody: the file stays unreadable on every launch,
/// and an app that does not open cannot restore a backup or say what
/// happened. The file is kept, renamed — see [SqliteDb.setAside].
abstract final class StoreRecovery {
  static StoreSetAside? _result;

  /// Null unless this launch set the database aside and started empty.
  static StoreSetAside? get result => _result;

  /// Moves [e]'s file aside, so the next `Stores.init` opens an empty one.
  ///
  /// The database must be closed: on Windows an open file cannot be renamed.
  static void setAside(StoreUnreadableException e, StackTrace s) {
    final aside = SqliteDb.setAside(e.path);
    Diag.error(e, s, 'Store unreadable, moved to $aside');
    _result = (err: e, aside: aside);
  }
}
