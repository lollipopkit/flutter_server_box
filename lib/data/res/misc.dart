abstract final class Miscs {
  static final blankReg = RegExp(r'\s+');

  /// Private Key max allowed size is 20kb
  static const privateKeyMaxSize = 20 * 1024;

  /// Editor max allowed size is 1mb
  static const editorMaxSize = 1024 * 1024;

  static const pkgName = 'tech.lolli.toolbox';

  /// Name of the synced backup, local and remote: sealed to the remote's
  /// sync key (`SyncKeyring`), which the backup password opens.
  ///
  /// Carries the format version so that a build which predates it never sees
  /// a file it would misread — see the note at `Paths.init` in `main.dart`.
  static const bakFileName = 'srvbox_bak_v5.age';

  /// What an export with a password is named: age with the password, which
  /// `age -d` opens.
  static const exportBakFileName = 'srvbox_bak_v4.age';

  /// What an export without a password is named: plain JSON.
  static const plainBakFileName = 'srvbox_bak_v4.json';

  /// The names every build before this one synced to, newest first: age with
  /// the backup password under v4, the `LKFL_ENC` envelope under v3, and
  /// unversioned before that. Read once to inherit existing sync history,
  /// never written.
  ///
  /// TODO: remove with the rest of the v2/v3/v4 compatibility shims.
  static const legacyBakFileNames = ['srvbox_bak_v4.age', 'srvbox_bak_v3.json', 'srvbox_bak.json'];
}
