import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/sudo_error.dart';
import 'package:server_box/data/store/stores.dart';

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
  /// saved with the server; null when there is neither.
  static String? known(String serverId) => _typed[serverId] ?? saved(serverId);

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
    final pwd = await context.showPwdSheet(
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
    if (known(serverId) case final pwd?) {
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

  /// [retry] for an [attempt] that throws [SudoRejected] rather than
  /// answering a result that says so. Only [SudoRejected] moves on to the next
  /// password; the last one is rethrown, and every other exception propagates
  /// at once. Null when the user declined to type one.
  static Future<T?> retryOnRejected<T extends Object>(
    BuildContext context,
    String serverId, {
    required Future<T> Function(String? password) attempt,
    String? label,
  }) async {
    final outcome = await retry<_Tried<T>>(
      context,
      serverId,
      label: label,
      attempt: (password) async {
        try {
          return _Tried.value(await attempt(password));
        } on SudoRejected catch (e, s) {
          return _Tried.rejected(e, s);
        }
      },
      rejected: (tried) => tried.rejection != null,
    );
    return outcome?.unwrap();
  }

  /// The one saved with [serverId] (the server editor's), if any.
  static String? saved(String serverId) {
    final value = Stores.sudoPassword.get<String>(serverId);
    return value == null || value.isEmpty ? null : value;
  }

  /// Saves [value] with [serverId]; empty removes it.
  static void save(String serverId, String value) {
    if (value.isEmpty) {
      unsave(serverId);
    } else {
      Stores.sudoPassword.set(serverId, value);
    }
  }

  static void unsave(String serverId) => Stores.sudoPassword.remove(serverId);

  /// Moves the ones builds before kept in the keychain into the store, and
  /// removes them there; once, or again at the next launch when the keychain
  /// fails.
  /// TODO: remove with [_adopted] once no install can still hold them.
  static Future<void> adoptKeychain() => _adopting ??= _adopt();

  static Future<void>? _adopting;

  /// The servers whose one in the keychain could not be read: unknown, so
  /// nothing stands in for it ([resolveForTerminal]).
  static final _unread = <String>{};

  static Future<void> _adopt() async {
    if (_adopted.get()) return;
    for (final id in Stores.server.fetch().map((e) => e.id)) {
      final key = 'sudo_pwd_$id';
      try {
        final value = await SecureStore.storage.read(key: key);
        if (value == null) continue;
        if (saved(id) == null && value.isNotEmpty) {
          SyncRecorder.adopt(Stores.sudoPassword, id, value);
        }
        await SecureStore.storage.delete(key: key);
      } catch (e, s) {
        _unread.add(id);
        Loggers.app.warning('Move the sudo password of $id out of the keychain', e, s);
      }
    }
    if (_unread.isEmpty) await _adopted.set(true);
  }

  static const _adopted = PrefPropDefault('sudo_pwd_adopted', false, updateLastUpdateTsOnSetProp: false);

  /// The typed one, else the saved one, else the SSH login's. Throws when
  /// the saved one cannot be read: falling through would type the login's
  /// password where the saved one was meant.
  static Future<String?> resolveForTerminal(Spi spi) async {
    if (_typed[spi.id] case final typed?) return typed;
    await _adopting;
    if (saved(spi.id) case final saved?) return saved;
    if (_unread.contains(spi.id)) throw StateError('The saved sudo password of ${spi.id} is unreadable');

    final pwd = spi.ssh?.pwd;
    if (pwd == null || pwd.isEmpty) return null;
    return pwd;
  }

  /// Whether [line] is sudo asking for the password: its own prompt,
  /// `[sudo] …:` naming a password in one of sudo's translations, or the bare
  /// `Password:` it prints on macOS and the BSDs. Nothing else — `ssh`'s `user@host's password:`,
  /// `mysql -p` or git would be handed this server's password.
  static bool isPromptText(String line) {
    final t = line.trim();
    if (!t.endsWith(':') && !t.endsWith('：')) return false;
    return _sudoPrompt.hasMatch(t) || _barePrompt.hasMatch(t);
  }

  static final _sudoPrompt = RegExp(
    r'^\[sudo\].*(password|passwort|mot de passe|contraseña|senha|parola|'
    r'wachtwoord|hasło|heslo|jelszó|salasana|lösenord|adgangskode|passord|'
    r'пароль|パスワード|密码|密碼|비밀번호)',
    caseSensitive: false,
  );
  static final _barePrompt = RegExp(r'^(password|密码)\s*[:：]$', caseSensitive: false);

  /// Strips ANSI escape sequences and normalizes line endings.
  static String normalizeOutput(String value) {
    return value
        .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }
}

final class _Tried<T extends Object> {
  const _Tried.value(T this.value) : rejection = null, stackTrace = null;
  const _Tried.rejected(SudoRejected this.rejection, StackTrace this.stackTrace)
    : value = null;

  final T? value;
  final SudoRejected? rejection;
  final StackTrace? stackTrace;

  T unwrap() {
    if (rejection case final rejection?) {
      Error.throwWithStackTrace(rejection, stackTrace!);
    }
    return value!;
  }
}
