abstract final class Miscs {
  static final blankReg = RegExp(r'\s+');

  /// RegExp for password request
  static final pwdRequestWithUserReg = RegExp(r'\[sudo\] password for (.+):');

  /// Private Key max allowed size is 20kb
  static const privateKeyMaxSize = 20 * 1024;

  /// Editor max allowed size is 1mb
  static const editorMaxSize = 1024 * 1024;

  static const pkgName = 'tech.lolli.toolbox';

  /// Name of the backup file, local and remote.
  ///
  /// Carries the format version so that a build which predates it never sees
  /// a file it would misread — see the note at `Paths.init` in `main.dart`.
  static const bakFileName = 'srvbox_bak_v3.json';

  /// The unversioned name written by every build before v3. Read once to
  /// inherit existing sync history, never written.
  ///
  /// TODO: remove with the rest of the v2 compatibility shims.
  static const legacyBakFileName = 'srvbox_bak.json';
}
