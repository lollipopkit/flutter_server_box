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
  static Future<UserCatalog> list(CommandExec exec) async {
    final result = await exec.run(ffi.usersListScript(), entry: 'sh');
    if (!result.succeeded) {
      final detail = result.combined.trim();
      throw UserManagerException(
        detail.isEmpty ? 'Unable to list system users' : detail,
      );
    }
    return parse(result.stdout);
  }

  static Future<UserCatalog> parse(String output) async {
    try {
      return await ffi.usersParseList(raw: output);
    } on UserError catch (e) {
      throw UserManagerException(message(e));
    }
  }

  /// Handed to `sh`, like [list]: the script has an `if`, and the account's
  /// login shell — which is what runs a command given without an entry — may
  /// be fish, which does not read one.
  static Future<UserDetail> detail(
    CommandExec exec,
    SystemUser user,
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

  static String detailScript(SystemUser user) =>
      _command(() => ffi.usersDetailScript(user: user));

  /// Only the rows naming [name], the account the script was run about, are
  /// read.
  static Future<UserDetail> parseDetail(String output, String name) =>
      ffi.usersParseDetail(raw: output, name: name);

  static bool validName(String name) => ffi.usersValidName(name: name);

  /// Why [draft] cannot be sent, or null when it can.
  static String? validateDraft(UserDraft draft) =>
      switch (ffi.usersValidateDraft(draft: draft)) {
        null => null,
        final e => message(e),
      };

  static String createScript(UserDraft draft) => _command(
    () => ffi.usersCreateCommand(draft: draft),
  );

  static String editScript(SystemUser original, UserDraft draft) =>
      _command(
        () => ffi.usersEditCommand(original: original, draft: draft),
      );

  static String deleteScript(SystemUser user, {required bool removeHome}) =>
      _command(
        () => ffi.usersDeleteCommand(user: user, removeHome: removeHome),
      );

  /// Why [draft] cannot be sent, or null when it can. [original] is the
  /// group being changed, null for a new one.
  static String? validateGroupDraft(
    GroupDraft draft,
    UserCatalog catalog, {
    SystemGroup? original,
  }) {
    return switch (ffi.groupsValidateDraft(draft: draft, original: original, accounts: catalog.accountNames)) {
      null => null,
      UserError.invalidName => 'Invalid group name',
      final e => message(e),
    };
  }

  static String createGroupScript(
    GroupDraft draft,
    UserCatalog catalog,
  ) => _command(
    () => ffi.groupsCreateCommand(
      draft: draft,
      accounts: catalog.accountNames,
    ),
  );

  static String editGroupScript(
    SystemGroup original,
    GroupDraft draft,
    UserCatalog catalog,
  ) => _command(
    () => ffi.groupsEditCommand(
      original: original,
      draft: draft,
      accounts: catalog.accountNames,
    ),
  );

  /// Whether [user] may be deleted by [current], the account the catalog was
  /// read as: never root, never the account doing the deleting.
  static bool userDeletable(SystemUser user, {String? current}) =>
      ffi.usersDeleteRefusal(user: user, current: current) == null;

  /// Whether [deleteGroupScript] would build a command for [group].
  static bool groupDeletable(SystemGroup group) =>
      ffi.groupsDeleteRefusal(group: group) == null;

  static String deleteGroupScript(SystemGroup group) => _command(
    () => ffi.groupsDeleteCommand(group: group),
  );

  /// A refused draft or account is a caller's mistake — the form validates
  /// with [validateDraft] first — so it surfaces as an [ArgumentError], as it
  /// did before the rules moved to Rust.
  static String _command(String Function() build) {
    try {
      return build();
    } on UserError catch (e) {
      throw ArgumentError(message(e));
    }
  }

  /// `sbm_parser::users::UserError` in the words this app has always shown.
  static String message(UserError e) => switch (e) {
    UserError.invalidName => 'Invalid user name',
    UserError.lineBreak => 'User fields cannot contain line breaks',
    UserError.invalidPrimaryGroup => 'Invalid primary group',
    UserError.invalidSupplementaryGroup => 'Invalid supplementary group',
    UserError.passwordLineBreak => 'Password cannot contain line breaks',
    UserError.renaming => 'Renaming is not supported',
    UserError.rootNotDeletable => 'The root user cannot be deleted',
    UserError.currentUserNotDeletable => 'The current user cannot be deleted',
    UserError.currentUserUnknown => 'Unable to determine the current user',
    UserError.unknownMember => 'A member is not an account on this server',
    UserError.rootGroupNotDeletable => 'The root group cannot be deleted',
    UserError.groupInUse => "This group is an account's primary group",
    UserError.groupNotLocal => 'Only groups in /etc/group can be changed',
  };
}
