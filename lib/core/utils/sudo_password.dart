import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

/// A server's sudo password, wherever something asks for it.
///
/// Two places it can come from: the one saved with the server
/// ([readOverride], the server editor's "sudo password"), and the one typed
/// this session ([remember]). The session's is memory only — never written
/// anywhere, gone with the process — and shared by every feature, so a
/// password typed for the containers is not asked for again by the
/// Virtualization tab, a service, a process or a user account.
abstract final class SudoPassword {
  /// Typed this session, by server id.
  static final _typed = <String, String>{};

  /// The one typed this session, alone: for what runs unasked, which must
  /// not keep sending a saved password sudo refuses — the typed one is
  /// [forget]ten on the first refusal, the saved one is not.
  static String? typed(String serverId) => _typed[serverId];

  /// What to try before asking: the one typed this session, else the one
  /// saved with the server; null when there is neither, or the saved one
  /// could not be read (the secure store is rate-limited).
  static Future<String?> known(String serverId) async {
    if (_typed[serverId] case final typed?) return typed;
    try {
      return await readOverride(serverId);
    } catch (e, s) {
      Loggers.app.warning('Reading the saved sudo password', e, s);
      return null;
    }
  }

  /// Keeps [password] for [serverId] for this session.
  static void remember(String serverId, String password) {
    if (password.isEmpty) {
      _typed.remove(serverId);
    } else {
      _typed[serverId] = password;
    }
  }

  /// Drops what was typed for [serverId] this session: sudo refused it, or
  /// the server changed or is gone. The saved one is the editor's to change.
  static void forget(String serverId) => _typed.remove(serverId);

  /// Asks for [serverId]'s sudo password, as [label]'s (the account sudo
  /// runs as), and keeps the answer for this session. Null when declined.
  static Future<String?> ask(
    BuildContext context,
    String serverId, {
    String? label,
  }) async {
    if (!context.mounted) return null;
    final pwd = await context.showPwdDialog(
      title: libL10n.sudoPassword,
      label: label,
      // Not fl_lib's own memory, which only fills the field in: this one
      // answers without asking.
      remember: false,
    );
    if (pwd == null || pwd.isEmpty) return null;
    remember(serverId, pwd);
    return pwd;
  }

  /// Runs [attempt] with no password, then with the [known] one, then with
  /// one [ask]ed for — each only while [rejected] says sudo refused the last.
  /// A password sudo refused is [forget]ten; one it took stays. Null when
  /// the user declined to type one; the last result otherwise.
  static Future<T?> retry<T>(
    BuildContext context,
    String serverId, {
    required Future<T?> Function(String? password) attempt,
    required bool Function(T result) rejected,
    String? label,
  }) async {
    var result = await attempt(null);
    if (result == null || !rejected(result)) return result;
    if (await known(serverId) case final pwd?) {
      if (!context.mounted) return null;
      result = await attempt(pwd);
      if (result == null || !rejected(result)) return result;
      forget(serverId);
    }
    if (!context.mounted) return null;
    final pwd = await ask(context, serverId, label: label);
    if (pwd == null || !context.mounted) return null;
    result = await attempt(pwd);
    if (result != null && rejected(result)) forget(serverId);
    return result;
  }

  static SecureProp secureProp(String serverId) {
    return SecureProp('sudo_pwd_$serverId');
  }

  static Future<String?> readOverride(String serverId) async {
    final value = await secureProp(serverId).read();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> writeOverride(String serverId, String value) async {
    if (value.isEmpty) {
      await clearOverride(serverId);
      return;
    }
    await secureProp(serverId).write(value);
  }

  static Future<void> clearOverride(String serverId) {
    return secureProp(serverId).write(null);
  }

  static Future<String?> resolveForTerminal(Spi spi) async {
    final known_ = await known(spi.id);
    if (known_ != null) return known_;

    final pwd = spi.ssh?.pwd;
    if (pwd == null || pwd.isEmpty) return null;
    return pwd;
  }

  static Future<bool> authenticateIfNeeded() async {
    if (!Stores.setting.useBioAuth.fetch()) return true;
    return await LocalAuth.goWithResult() == AuthResult.success;
  }

  /// Returns true if [trimmed] looks like an active sudo password prompt.
  /// [trimmed] should already be trimmed.
  static bool isPromptText(String trimmed) {
    final lower = trimmed.toLowerCase();
    if (Miscs.pwdRequestWithUserReg.hasMatch(trimmed)) return true;
    if (lower.contains('[sudo] password')) return true;
    if ((lower.endsWith(':') || lower.endsWith('：')) &&
        (lower.contains('password') || lower.contains('密码'))) {
      return true;
    }
    return false;
  }

  /// Strips ANSI escape sequences and normalizes line endings.
  static String normalizeOutput(String value) {
    return value
        .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }
}
