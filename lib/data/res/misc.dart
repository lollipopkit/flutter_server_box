abstract final class Miscs {
  static final blankReg = RegExp(r'\s+');

  /// Private Key max allowed size is 20kb
  static const privateKeyMaxSize = 20 * 1024;

  /// Editor max allowed size is 1mb
  static const editorMaxSize = 1024 * 1024;

  static const pkgName = 'tech.lolli.toolbox';

  /// Name of the backup file, local and remote: age-encrypted
  /// (`AgeCryptor`), as every remote write is.
  ///
  /// Carries the format version so that a build which predates it never sees
  /// a file it would misread — see the note at `Paths.init` in `main.dart`.
  static const bakFileName = 'srvbox_bak_v4.age';

  /// What an export without a password is named: plain JSON.
  static const plainBakFileName = 'srvbox_bak_v4.json';

  /// The names every build before this one synced to, newest first: the
  /// `LKFL_ENC` envelope under v3, and unversioned before that. Read once to
  /// inherit existing sync history, never written.
  ///
  /// TODO: remove with the rest of the v2/v3 compatibility shims.
  static const legacyBakFileNames = ['srvbox_bak_v3.json', 'srvbox_bak.json'];
}
