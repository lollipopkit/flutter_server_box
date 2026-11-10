import 'package:server_box/src/rust/api/users.dart';

export 'package:server_box/src/rust/api/users.dart'
    show GroupDraft, PasswordState, SystemGroup, SystemUser, UserCatalog, UserDetail, UserDraft, UserError;

extension SystemUserX on SystemUser {
  bool get isRoot => uid == 0;

  bool isSystem(int uidMin) => uid < uidMin;

  bool get loginDisabled {
    final executable = shell.split('/').last.toLowerCase();
    return executable == 'false' || executable == 'nologin';
  }
}

extension SystemGroupX on SystemGroup {
  /// `SystemGroup::is_root`.
  bool get isRoot => gid == 0 || name == 'root';

  bool isSystem(int gidMin) => gid < gidMin;
}

extension UserCatalogX on UserCatalog {
  SystemGroup? findGroup(String name) {
    for (final group in groups) {
      if (group.name == name) return group;
    }
    return null;
  }

  List<String> get accountNames => [for (final user in users) user.name];
}

/// Every field is nullable and null means "not readable from here", never
/// "absent": shadow, `authorized_keys` and sudoers are root-only on a normal
/// system, and an unprivileged session would otherwise report every account
/// as having no password and no keys.
extension UserDetailX on UserDetail {
  /// Shadow's day counts are UTC midnights.
  DateTime? get passwordChanged => _instant(passwordChangedMillis);

  /// Null when shadow was unreadable; absent-from-the-record is [neverExpires].
  DateTime? get expires => _instant(expiresMillis);

  bool get isEmpty =>
      passwordState == null &&
      passwordChangedMillis == null &&
      expiresMillis == null &&
      !neverExpires &&
      sshKeyTypes == null &&
      sudoRule == null;

  static DateTime? _instant(int? millis) =>
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
