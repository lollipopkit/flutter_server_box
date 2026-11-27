import 'package:fl_lib/fl_lib.dart';

/// Device-local flags coordinating client-side secret key onboarding and
/// migration between [IntroPage] and [BackupPage].
abstract final class SyncSecretKeyPrefs {
  /// Set when this device auto-generates a new secret key in the background so
  /// the user is prompted to save it until explicitly confirmed.
  static const backupPending = PrefPropDefault<bool>(
    'sync_secret_key_backup_pending',
    false,
  );

  /// Set when an upgrading user with an existing 2FA remote chooses "Set up
  /// later (pause sync)" so subsequent launches do not block local SSH access.
  static const introDeferred = PrefPropDefault<bool>(
    'sync_secret_key_intro_deferred',
    false,
  );
}
