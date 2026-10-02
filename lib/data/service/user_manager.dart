import 'dart:convert';

import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/src/rust/api/users.dart' as ffi;

final class UserManagerException implements Exception {
  const UserManagerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A machine's accounts: what to run and how to read it, from
/// `sbm_parser::users` — the rules the monitor agent's panel uses too. This
/// file only runs the scripts and carries their results; what an account is
/// and how one is changed is decided on the Rust side.
abstract final class UserManager {
  /// Handed to `sh` rather than run as the command. Without an entry the
  /// script is parsed by the account's login shell, and fish stops at the
  /// first `if ...; then` — so the page showed fish's diagnostic where the
  /// user list should have been. The create, edit and delete scripts already
  /// reach `sh` through `PrivilegedExec`.
  static Future<ServerUserCatalog> list(ServerExec exec) async {
    final result = await exec.run(ffi.usersListScript(), entry: 'sh');
    if (!result.succeeded) {
      final detail = result.combined.trim();
      throw UserManagerException(
        detail.isEmpty ? 'Unable to list system users' : detail,
      );
    }
    return parse(result.stdout);
  }

  static Future<ServerUserCatalog> parse(String output) async {
    try {
      final json = await ffi.parseUsersListJson(raw: output);
      return ServerUserCatalog.fromJson(
        jsonDecode(json) as Map<String, Object?>,
      );
    } on ffi.UserFfiError catch (e) {
      throw UserManagerException(_message(e.code));
    }
  }

  /// Handed to `sh`, like [list]: the script has an `if`, and the account's
  /// login shell — which is what runs a command given without an entry — may
  /// be fish, which does not read one.
  static Future<ServerUserDetail> detail(
    ServerExec exec,
    ServerUser user,
  ) async {
    final result = await exec.run(detailScript(user), entry: 'sh');
    // Every read in the script is allowed to fail and the last one is
    // `|| true`, so a non-zero exit is the run itself failing — a dropped
    // connection, say — and not an account whose records are unreadable.
    if (!result.succeeded) {
      final detail = result.combined.trim();
      throw UserManagerException(
        detail.isEmpty ? 'Unable to read the account' : detail,
      );
    }
    return parseDetail(result.stdout, user.name);
  }

  static String detailScript(ServerUser user) =>
      _command(() => ffi.usersDetailScript(userJson: _json(user.toJson())));

  /// Only the rows naming [name], the account the script was run about, are
  /// read.
  static Future<ServerUserDetail> parseDetail(String output, String name) async {
    final json = await ffi.parseUserDetailJson(raw: output, name: name);
    return ServerUserDetail.fromJson(jsonDecode(json) as Map<String, Object?>);
  }

  static bool validName(String name) => ffi.usersValidName(name: name);

  /// Why [draft] cannot be sent, or null when it can.
  static String? validateDraft(ServerUserDraft draft) {
    final code = ffi.usersValidateDraft(draftJson: _json(draft.toJson()));
    return code == null ? null : _message(code);
  }

  static String createScript(ServerUserDraft draft) => _command(
    () => ffi.usersCreateCommand(draftJson: _json(draft.toJson())),
  );

  static String editScript(ServerUser original, ServerUserDraft draft) =>
      _command(
        () => ffi.usersEditCommand(
          originalJson: _json(original.toJson()),
          draftJson: _json(draft.toJson()),
        ),
      );

  static String deleteScript(ServerUser user, {required bool removeHome}) =>
      _command(
        () => ffi.usersDeleteCommand(
          userJson: _json(user.toJson()),
          removeHome: removeHome,
        ),
      );

  /// A refused draft or account is a caller's mistake — the form validates
  /// with [validateDraft] first — so it surfaces as an [ArgumentError], as it
  /// did before the rules moved to Rust.
  static String _command(String Function() build) {
    try {
      return build();
    } on ffi.UserFfiError catch (e) {
      throw ArgumentError(_message(e.code));
    }
  }

  static String _json(Map<String, Object?> value) => jsonEncode(value);

  /// `sbm_parser::users::UserError` in the words this app has always shown.
  static String _message(String code) => switch (code) {
    'invalidName' => 'Invalid user name',
    'lineBreak' => 'User fields cannot contain line breaks',
    'invalidPrimaryGroup' => 'Invalid primary group',
    'invalidSupplementaryGroup' => 'Invalid supplementary group',
    'passwordLineBreak' => 'Password cannot contain line breaks',
    'renaming' => 'Renaming is not supported',
    'rootNotDeletable' => 'The root user cannot be deleted',
    'currentUserUnknown' => 'Unable to determine the current user',
    _ => code,
  };
}
