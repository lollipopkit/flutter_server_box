import 'dart:io';

import 'package:fl_lib/fl_lib.dart';

/// [Paths.file] — this device's files, as the browser and the transfers see
/// it.
///
/// Everything goes through [ensure] rather than through `Paths.file` alone,
/// because on the desktop builds that directory is under the user's own
/// documents directory and is not created at startup: touching `~/Documents`
/// raises a macOS permission prompt, and one raised while the app is still
/// starting has nothing to explain it. Asked for when the user opens a file
/// browser or starts a download, the prompt has a reason.
abstract final class LocalFiles {
  /// Where [Paths.file] used to be, on every desktop platform: under the
  /// app's own data directory.
  ///
  /// Two things land here. The released Linux and Windows builds wrote their
  /// downloads to it, and `Paths.adoptLegacyDoc` carries them along when it
  /// moves that directory. And on macOS `SandboxImport` copies the App Store
  /// build's container in, downloads included.
  ///
  /// TODO: drop together with those two, once no install can still be writing
  /// the old locations.
  static String get _imported => Paths.doc.joinPath('file');

  /// Creates [Paths.file], moves in anything an earlier location left, and
  /// answers with it.
  ///
  /// Idempotent, and cheap enough to call on every entry into a browser or a
  /// transfer. Throws what [Directory.create] throws, so a refused permission
  /// reaches the caller instead of turning into an empty directory listing.
  static Future<String> ensure() async {
    final dir = await Paths.ensureFile();
    await _drainImported();
    return dir.path;
  }

  /// Moves the imported downloads to where the browser now looks.
  ///
  /// Best-effort: the files are still readable where they are, and the next
  /// [ensure] tries again — failing here must not stop a browser from opening.
  static Future<void> _drainImported() async {
    final src = Directory(_imported);
    if (src.path == Paths.file) return;
    if (!await src.exists()) return;

    try {
      await for (final entity in src.list(followLinks: false)) {
        final name = entity.path.getFileName();
        if (name == null) continue;
        final dest = Paths.file.joinPath(name);
        // Whatever is already there was put there by this build, which makes
        // it the newer of the two.
        final existing = await FileSystemEntity.type(dest);
        if (existing != FileSystemEntityType.notFound) continue;
        await entity.rename(dest);
      }
      // Only once it is empty: a name that was skipped above still has the
      // one copy of itself in here.
      if (await src.list().isEmpty) await src.delete();
    } catch (e, s) {
      Loggers.app.warning('Move imported files into ${Paths.file}', e, s);
    }
  }
}
